#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

#TreeFilters mediates between the various filters that restrict cards according to a particular tree configuration
class TreeFilters
  include Enumerable, FiltersSupport
  
  class << self
    def create_key(card_type_name)
      "tf_#{card_type_name}"
    end
    
    def default_params(tree_configuration)
      tree_configuration.all_card_types.inject({}) { |result, card_type| result[create_key(card_type.name)] = []; result; }
    end
    
    def valid_parameter?(name, value)
      (name.to_s =~ /^tf_(.*)$/ || name.to_s == 'excluded') && value.kind_of?(Array)
    end  
    
    def filter_parameters_for(tree_configuration)
      tree_configuration.all_card_types.collect { |ct| TreeFilters.create_key(ct.name).downcase.to_sym } + [:excluded]
    end
  end  
  
  def initialize(project, filter_params, tree_configuration)
    self.project, self.tree_configuration = project, tree_configuration
    
    filter_params = downcase_keys_and_combine_values(filter_params)
    
    filter_params.symbolize_keys!.each do |filter_key, filter_strings|
      if filter_key.to_s.starts_with?('tf_')
        card_type_name = filter_key.to_s[3..-1]
        next unless project.card_types.detect { |ct| ct.name.downcase == card_type_name.downcase }
        filter_strings = filter_strings.reject { |filter_string| filter_string.downcase.starts_with?('[type][is]') }
        included_filters[card_type_name] = Filters.new(project, filter_strings + ["[Type][is][#{card_type_name}]"])
      end  
    end
    self.exclusions = filter_params[:excluded]
  end
  
  # duck typing for UserFilterUsageObserver
  def each(&block)
    included_filters.values.each do |tree_filters|
      tree_filters.each do |filter|
        yield filter
      end
    end
  end

  def uses_card?(card)
    card_usage_detector.uses?(card)
  end
  
  def cards_used_sql_condition
    card_usage_detector.sql_condition
  end
  
  def project_variables_used
    CardQuery::ProjectVariableDetector.new(card_query).execute
  end
  
  def as_card_query_conditions
    cascades = CascadedFilters.new(tree_configuration, included_filters)
    inclusion_query = CardQuery::Or.new(*tree_configuration.all_card_types.collect { |card_type| cascades.query_for(card_type) })
    exclusion_query = exclusions? ? Filters.new(tree_configuration.project, exclusions.collect { |ct| "[Type][is not][#{ct}]" }).as_card_query_conditions : nil
    cards_potentially_within_tree = CardQuery::And.new(*[inclusion_query, exclusion_query].compact)
    [cards_potentially_within_tree, CardQuery::InTree.new(tree_configuration)]
  end  
  
  def filters_for_type(card_type)
    if (value = included_filters.find_ignore_case(card_type.name))
      value
    else
      Filters.new(project, ["[Type][is][#{card_type.name}]"])
    end  
  end  

  def included_filters
    @included_filters ||= {}
  end  

  def exclusions
    @exclusions
  end 
  
  def using_card_as_value?
    card_usage_detector.uses_any_card?
  end
  
  def excluded?(card_type)
    exclusions && exclusions.any? { |card_type_name| card_type_name.downcase == card_type.name.downcase }
  end  

  def to_params(filters_to_parameterize = included_filters)
    param_filters = {}
    filters_to_parameterize.each do |card_type_name, filters|
      filter = filters.reject(&:card_type_filter?).collect(&:to_params).compact
      param_filters[self.class.create_key(card_type_name).to_sym] = filter if filter.any?
    end
    exclusions ? param_filters.merge(:excluded => exclusions) : param_filters
  end  
  
  def card_query_for_relationship_filter(card_type, property_definition)
    negated_filter_params = included_filters.inject({}) do |negated_filters, (card_type_name, filters)|
      negated_filters[card_type_name] = filters.flip_relationship_filters_for_card_type(card_type, property_definition)
      negated_filters
    end
    CardQuery.new(:conditions => CardQuery::And.new(TreeFilters.new(project, to_params(negated_filter_params).merge(:excluded => []), tree_configuration).as_card_query_conditions))
  end
    
  def update_date_format(old_format, new_format)
    included_filters.values.each { |filter| filter.update_date_format(old_format, new_format) }
  end
  
  def properties_for_group_by
    properties = PropertyDefinition.tree_sort(collect_valid_properties_from_card_type_names)
    properties.select(&:groupable?)
  end
  
  def no_card_type_filters?
    card_type_names.empty?
  end
  
  def sorted_filter_string
    to_params.inject([]) do |result, (key, values)|
      values.inject(result) { |accumulator, value| accumulator << "#{key}[]=#{value}" }
    end.smart_sort.join(',')
  end  

  def uses_card_type?(value)
    tree_configuration.all_card_types.collect { |ct| ct.name.downcase }.include?(value.downcase)
  end  
  
  def uses_property_value?(prop_name, value)
    included_filters.values.any? { |filters| filters.uses_property_value?(prop_name, value) }
  end
  
  def uses_property_definition?(property_definition)
    included_filters.values.any? { |filters| filters.uses_property_definition?(property_definition) }
  end
  
  def uses_plv?(plv)
    included_filters.values.any? { |filters| filters.uses_plv?(plv) }
  end

  def invalid?
    !validation_errors.blank? rescue true
  end  
  
  def validation_errors
    cascaded_filters.validation_errors + excluded_card_types_errors
  end  
  
  def empty?
    false
  end  
  
  def description_header
    "Properties".italic
  end
  
  def to_s
    excluded_types = exclusions ? tree_configuration.all_card_types.collect do |card_type|
      next unless exclusions.any? { |excluded_type| excluded_type.downcase == card_type.name.downcase }
      card_type.name
    end.compact : []
    exclusions_description = description = exclusions? ? "Do not show #{excluded_types.bold.to_sentence} #{'card'.plural(excluded_types.size)}." : nil
    
    filters_description = tree_configuration.all_card_types.collect do |card_type|
      next unless (card_type_filters = included_filters.find_ignore_case(card_type.name))
      filter_description = Filters.new(@project, card_type_filters.reject(&:card_type_filter?).collect(&:to_params).compact).description_without_header
      "#{card_type.name} filter: #{filter_description}." if filter_description
    end.compact
    ([exclusions_description] + filters_description).compact.join(" ")
  end
  
  alias_method :description_without_header, :to_s
      
  def filter_parameters
    TreeFilters.filter_parameters_for(tree_configuration)
  end
  
  def rename_card_type(old_name, new_name)
    @included_filters = included_filters.inject({}) do |accumulator, (card_type_name, filters)|
      card_type_name = new_name.downcase if card_type_name.downcase == old_name.downcase
      accumulator[card_type_name] = filters
      accumulator
    end
    if exclusions?
      @exclusions = exclusions.collect { |exclusion| exclusion.downcase == old_name.downcase ? new_name : exclusion }
    end
  end
  
  def rename_property(old_name, new_name)
    modify_included_filters { |filters| filters.rename_property(old_name, new_name) }
  end
  
  def rename_property_value(property_name, old_value, new_value)
    modify_included_filters { |filters| filters.rename_property_value(property_name, old_value, new_value) }
  end
  
  def rename_project_variable(old_name, new_name)
    modify_included_filters { |filters| filters.rename_project_variable(old_name, new_name) }
  end
  
  attr_accessor :project, :tree_configuration, :exclusions
  
  #CascadedFilters understands how to construct the card-query that defines any one level of a tree filter, including the effects of any filters set on parent levels of the filter.
  class CascadedFilters

    def initialize(tree_configuration, filters)
      @cascaded_conditions, @direct_conditions, @child_in_conditions, @child_not_set_conditions = {}, {}, {}, {}
      @config = tree_configuration
      @config.all_card_types.each do |card_type|
        card_type_filters = filters.find_ignore_case(card_type.name) || Filters.new(tree_configuration.project, ["[Type][is][#{card_type.name}]"])
        next_level_filters, same_level_filters = card_type_filters.partition(&:relationship_filter?)
        @direct_conditions[card_type] = same_level_filters
        unless direct_filters_invalid?
          setup_cascaded_conditions(card_type, next_level_filters, same_level_filters)
        else
          @child_not_set_conditions[card_type], @child_in_conditions[card_type] = [], []
        end
      end
    end

    def query_for(card_type)
      CardQuery::And.new(*(parent_constrained_queries_for(card_type) + child_query_for(card_type)))
    end
    
    def invalid?
      !validation_errors.empty?
    end
    
    def validation_errors
      (direct_filters.collect(&:validation_errors) + child_filters.collect { |filter| filter.validation_errors(:check_card_type => false) }).flatten
    end
    
    private
    
    def direct_filters_invalid?
      direct_filters.any?(&:invalid?)
    end
    
    def direct_filters
      @direct_conditions.values.collect { |filters| array_to_filter(filters) }
    end
    
    def child_filters
      @child_in_conditions.values.collect { |filters| array_to_filter(filters) }
    end
    
    def setup_cascaded_conditions(card_type, next_level_filters, same_level_filters)
      @child_not_set_conditions[card_type], @child_in_conditions[card_type] = next_level_filters.partition(&:not_set_value?)
      if @config.can_contain_children?(card_type) && (same_level_filters + next_level_filters).size > 1
        column = CardQuery::Column.new(@config.tree_relationship_name(card_type))
        restricting_query = CardQuery::And.new(array_to_filter(same_level_filters).as_card_query_conditions + child_query_for(card_type))
        
        number_query = CardQuery.new(:columns => [CardQuery::Column.new('Number')]).restrict_with(CardQuery.new(:conditions => CardQuery::And.new(*restricting_query), :order_by => nil))
        in_query = CardQuery::ImplicitIn.new(column, number_query)
        @cascaded_conditions[card_type] = if (@child_not_set_conditions.empty?)
          in_query
        else
          CardQuery::Or.new(in_query, *(array_to_filter(@child_not_set_conditions[card_type]).as_card_query_conditions))
        end
      end 
    end
    
    def parent_constrained_queries_for(card_type)
      [all_cascades_for(card_type), *Filters.new(card_type.project, @direct_conditions[card_type].collect(&:to_params)).as_card_query_conditions].compact
    end  

    def child_query_for(card_type)
      next_level_in_query = array_to_filter(@child_in_conditions[card_type]).as_number_query
      next_level_not_set_query = array_to_filter(@child_not_set_conditions[card_type]).as_number_query
      next_level_query = if (@child_in_conditions[card_type].size > 0 && @child_not_set_conditions[card_type].size > 0)
        [CardQuery::Or.new(*(next_level_not_set_query + next_level_in_query))]
      elsif (@child_not_set_conditions[card_type].size > 0)
        next_level_not_set_query
      else
        next_level_in_query
      end
    end
    
    def all_cascades_for(card_type)
      cascading_queries = @config.card_types_before(card_type).collect { |parent_type| @cascaded_conditions[parent_type] }.flatten.compact
      CardQuery::And.new(*cascading_queries) if cascading_queries.any?
    end
    
    def array_to_filter(array_of_filter)
      Filters.new(@config.project, array_of_filter.collect(&:to_params))
    end
  end

  private
  
  def excluded_card_types_errors
    return [] unless exclusions
    valid_card_types = tree_configuration.all_card_types.map(&:name).map(&:downcase)
    invalid_card_types = exclusions.select { |excluded_card_type| valid_card_types.none? { |valid_card_type| excluded_card_type.downcase == valid_card_type } }
    invalid_card_types.any? ? ["Tree #{tree_configuration.name.bold} does not contain excluded card #{'types'.plural(invalid_card_types.size)} #{invalid_card_types.map(&:bold).to_sentence(:last_word_connector => ' and ')}."] : []
  end
  
  def cascaded_filters
    CascadedFilters.new(tree_configuration, included_filters)
  end
  memoize :cascaded_filters
  
  def card_query
    CardQuery::And.new(*as_card_query_conditions)
  end
  
  def card_usage_detector
    CardQuery::CardUsageDetector.new(card_query)
  end
  
  def modify_included_filters(&block)
    included_filters.each { |card_type_name, filters| yield filters }
  end

  def excluded_filters
    excluded_types = tree_configuration.all_card_types.select { |ct| !included_filters.keys.include?(ct) }
    Filters.new(project, excluded_types.collect { |excluded_type| "[Type][is not][#{excluded_type.name}]" })
  end  
  
  def exclusions?
    exclusions && !exclusions.empty?
  end
  
  def card_type_names
    card_types = tree_configuration.all_card_types.collect(&:name)
    exclusions? ? card_types.collect(&:downcase) - exclusions.collect(&:downcase) : card_types
  end
  memoize :card_type_names
  
  def downcase_keys_and_combine_values(filter_params)
    filter_params.inject({}) do |new_hash, (key, value)|
      new_key = key.to_s.downcase.to_sym
      new_hash[new_key] = new_hash[new_key] ? new_hash[new_key] + value : value
      new_hash
    end
  end
end
