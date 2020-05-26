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

#Filters understands the various ways in which a selection of cards can be restricted by a project's property definitions
class Filters
  include Enumerable, FiltersSupport

  attr_accessor :project, :tree_configuration
  attr_reader :errors

  ENCODED_FORM = /^\[([^\]]*?)\]\[([^\]]*?)\]\[(.*?)\]$/

  class FiltersGroup < Hash
    def add_filter(filter)
      (self[filter_key(filter)] ||= FilterGroup.new(filter.property_definition.name)) << filter
    end

    def sorted_values
      values.sort_by(&:property_definition_name)
    end

    private
    def filter_key(filter)
      filter.property_definition_name.downcase
    end
  end

  def self.filter_parameters
    [:filters]
  end

  def initialize(project, filter_strings, tree_configuration = nil)
    @errors = []
    self.project, self.tree_configuration = project, tree_configuration
    Array(filter_strings).compact.collect { |filter_string| read_filter_string(filter_string) }
    filters.reject!(&:ignored?)
  end

  def each(&block)
    filters.each(&block)
  end

  def value_for(property)
    detect {|filter| filter.filtered_by?(property) }.value
  end

  def [](index)
    filters[index.to_i]
  end

  def empty?
    filters.reject(&:ignored?).empty?
  end

  def size
    filters.size
  end

  def filter_parameters
    Filters.filter_parameters
  end

  def to_params
    collect(&:to_params).compact
  end

  def to_hash
    self.inject([]) do |result, filter|
      next result unless filter.property_definition
      result << filter.to_hash
    end.to_json
  end

  def property_values
    collect(&:property_value)
  end

  def ==(other)
    self.to_params.collect(&:downcase).sort == other.to_params.collect(&:downcase).sort
  end

  def rename_property(old_name, new_name)
    each { |filter| filter.rename_property(new_name) if filter.filtered_by?(old_name) }
  end

  def rename_card_type(old_name, new_name)
    # Nothing. Need to match the interface of TreeFilters. (Card type values are handled by rename_property_value).
  end

  def rename_property_value(property_name, old_value, new_value)
    property_filters = select { |filter| filter.filtered_by?(property_name) && filter.value.downcase == old_value.downcase }
    property_filters.each { |property_filter| property_filter.rename_property_value(new_value) } if property_filters
  end

  def rename_project_variable(old_name, new_name)
    each { |filter| filter.rename_project_variable(old_name, new_name) }
  end

  def update_date_format(old_format, new_format)
    each { |filter| filter.update_date_format(old_format, new_format) }
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
    grouped_filters.sorted_values.collect(&:as_card_query_conditions)
  end

  def as_card_query
    conditions = as_card_query_conditions
    conditions = conditions.empty? ? nil : CardQuery::And.new(*conditions)
    CardQuery.new(:conditions => conditions)
  end

  def as_number_query
    grouped_filters.sorted_values.collect(&:as_number_query)
  end

  def valid_properties
    return project.property_definitions_for_columns.select(&:global?).collect {|prop_def| prop_def.name} if no_card_type_filters?
    collect_valid_properties_from_card_type_names.collect(&:name)
  end
  memoize :valid_properties

  def no_card_type_filters?
    card_type_names.empty? && !card_type_filters.any? { |filter| filter.value != '' }
  end

  def filter_value(property_definition)
    filter = detect { |filter| filter.filtered_by?(property_definition) }
    filter.value if filter
  end

  def has_same_or_fewer_property_definitions_as?(other_filters)
    property_names = (grouped_filters.keys - other_filters.send(:grouped_filters).keys).empty?
  end

  def uses_card_type?(value)
    !card_type_filters.empty? && card_type_filters.collect {|filter| filter.value.downcase }.include?(value.downcase)
  end

  def uses_property_value?(prop_name, value)
    any? { |filter| filter.filtered_by?(prop_name) && filter.value.downcase == value.downcase }
  end

  def uses_plv?(plv)
    any? { |filter| filter.uses_plv?(plv) }
  end

  def uses_property_definition?(property_definition)
    any? {|filter| filter.filtered_by?(property_definition)}
  end

  def using_numeric_property_definition
    select { |filter| filter.property_definition.numeric? }
  end

  def using_card_as_value?
    card_usage_detector.uses_any_card?
  end

  def inspect
    collect(&:to_s).join("\n")
  end

  def validation_errors(options={})
    options[:check_card_type] = true unless options.has_key?(:check_card_type)
    warnings = [undefined_properties_warning, not_valid_for_this_card_type_warning]
    warnings << type_specific_filter_without_explicit_type_filter_warning if options[:check_card_type]
    warnings += [invalid_operator_and_value_combination_warning,
                 invalid_dates_warning,
                 unknown_enumeration_or_type_value_warning,
                 undefined_project_variable_warning,
                 undefined_values_warning,
                 plv_not_associated_with_property_warning]

    warnings.flatten.select{|msg| !msg.blank?}
  end

  def valid?(options={})
    @errors = validation_errors(options)
    @errors.blank?
  end

  def invalid?(options={})
    !valid?(options)
  end

  def description_header
    "Properties".italic
  end

  def description_without_header
    return if valid_filters.reject(&:ignored?).empty?
    grouped_filters.keys.sort.collect do |key|
      grouped_filters[key].description_without_header
    end.join(' and ')
  end

  def sorted_filter_string
    (to_params || []).smart_sort.join(',')
  end

  def card_type_names
    individual_type_filters, collective_type_filters = card_type_filters.partition(&:individual?)
    individual_type_names = individual_type_filters.collect(&:value).uniq

    collective_type_names_allowed = if (collective_type_filters.empty?)
      []
    else
      all_names = @project.card_types.collect { |card_type| card_type.name.downcase }
      collective_type_names = collective_type_filters.collect { |card_type_filter| card_type_filter.value.downcase }.uniq
      individual_type_names = individual_type_names - collective_type_names

      collective_type_groups = collective_type_names.inject([]) { |collector, name| collector << all_names.without(name) }
      collective_type_groups.inject { |first_value, second_value| first_value.intersect(second_value) }
    end

    allowed_names = individual_type_names + collective_type_names_allowed
    allowed_names.uniq
  end

  def value_count(filter)
    grouped_filters[filter.property_definition_name.downcase].size
  end

  def find_first_available_card_type
    type_filters = card_type_filters
    if !type_filters.empty?
      first_available = @project.card_types.detect do |card_type|
        type_filters.all? { |filter| filter.valid_value?(card_type.name) }
      end
      return first_available if !first_available.nil?
    end
    return @project.card_types.first
  end
  alias :card_type :find_first_available_card_type

  def contains_filter_for_property_definition_name(property_definition_name)
    filters.any? {|filter| filter.property_definition_name.downcase == property_definition_name.downcase}
  end

  def unignored_filters
    reject(&:ignored?).collect(&:to_params)
  end

  def dirty_compared_to?(another)
    my_filter_params = unignored_filters.collect(&:downcase)
    other_filter_params = another.unignored_filters.collect(&:downcase)
    clean = my_filter_params.contains_all?(other_filter_params) && other_filter_params.contains_all?(my_filter_params)
    !clean
  end

  def card_query_for_relationship_filter(card_type, property_definition)
    if property_definition
      card_type = property_definition.valid_card_type # be sure card_type is not pretender.
      tree_configuration = property_definition.tree_configuration
      card_types = tree_configuration.card_types_before(card_type) << card_type
      relationship_filters = select(&:relationship_filter?)
      tree_params = card_types.inject({}) do |accumulator, card_type|
        key = TreeFilters.create_key(card_type.name)
        card_type_filters = relationship_filters.select { |filter| filter.property_definition.valid_card_type == card_type }
        accumulator[key] = card_type_filters.collect(&:to_params)
        accumulator
      end

      TreeFilters.new(project, tree_params, tree_configuration).card_query_for_relationship_filter(card_type, property_definition)
    else
      CardQuery.new(:conditions => Filters.new(self.project, collect { |filter| filter.flip_relationship_filters_for_card_type(card_type) }.compact.collect(&:to_params)).as_card_query_conditions)
    end
  end

  def flip_relationship_filters_for_card_type(card_type, property_definition)
    Filters.new(self.project, collect { |filter| filter.flip_relationship_filters_for_card_type(card_type) }.compact.collect(&:to_params))
  end

  def title
    'Filter'
  end

  def to_s
    collect(&:to_s).join("\\n")
  end

  def grouped_filters
    valid_filters.reject(&:ignored?).inject(FiltersGroup.new) do |groups, filter|
      groups.add_filter(filter)
      groups
    end
  end

  private
  def card_query
    CardQuery::And.new(*as_card_query_conditions)
  end

  def card_usage_detector
    CardQuery::CardUsageDetector.new(card_query)
  end

  def filter_property_names
    collect(&:property_definition_name)
  end
  memoize :filter_property_names

  def valid_filters
    filters.select(&:property_definition)
  end

  def properties_with_multiple_values
    property_names_with_multiple_values = grouped_filters.values.reject(&:multiple_values).collect(&:property_definition_name)
    property_names_with_multiple_values.collect{|name| project.find_property_definition_or_nil(name) }.collect(&:name)
  end

  def filters
    @filters ||= []
  end

  def read_filter_string(filter_string)
    filter_string =~ ENCODED_FORM
    unless $&
       @errors << "Invalid filter parameter: #{filter_string.bold}"
    else
      filter = Filter.new(project, filter_string)
      filters << filter
      undefined_filters << filter if !filter.property_definition_name.blank? && filter.property_definition.nil?
    end
  end

  def undefined_filters
    @undefined_filters ||= []
  end

  def card_type_filters
    select(&:card_type_filter?)
  end

  def undefined_properties_warning
    not_defined_property_names = undefined_filters.collect(&:property_definition_name).reject(&:blank?)
    return if not_defined_property_names.empty?
    not_defined_property_names.uniq!
    join("Property".plural(not_defined_property_names.size), not_defined_property_names.bold.join(', '), 'does'.plural(not_defined_property_names.size), 'not exist.')
  end

  def not_valid_for_this_card_type_warning
    valid_props = valid_properties.collect(&:downcase)
    return if filter_property_names.all?{|filter_prop_name| valid_props.include?(filter_prop_name.downcase)}
    return if filter_property_names.any?{|filter_prop_name| !@project.find_property_definition_or_nil(filter_prop_name)}
    return if card_type_names.empty?
    # badri and dave promise to clean up these next 2 lines of code tomorrow!!
    invalid_properties = filter_property_names.reject{|filter_prop_name| filter_prop_name.downcase == 'type' || valid_props.include?(filter_prop_name.downcase)}
    invalid_properties = invalid_properties.collect{|invalid_property| @project.find_property_definition(invalid_property)}.collect(&:name)
    invalid_properties.uniq!
    join("Property".plural(invalid_properties.size), invalid_properties.bold.join(', '),  'is'.plural(invalid_properties.size), 'not valid for', 'card type'.plural(card_type_names.size), card_type_names.bold.join(', ') << ".")
  end

  def type_specific_filter_without_explicit_type_filter_warning
    type_specific_properties = type_specific_filters.reject{|filter| filter.property_definition_name.blank? }.collect { |filter| filter.property_definition_name }
    return unless card_type_names.empty? && type_specific_properties.any?
    type_specific_properties.uniq!
    join('Please filter by appropriate card type in order to filter by', 'property'.plural(type_specific_properties.size), type_specific_properties.bold.join(', ') << ".")
  end

  def invalid_operator_and_value_combination_warning
    range_operators_with_empty_values = select(&:range_filter?).select{ |filter| filter.value.blank? }.collect(&:operator_name).uniq
    return if range_operators_with_empty_values.empty?
    join('(not set)'.bold, 'is not a valid filter for', 'operator'.plural(range_operators_with_empty_values.size), range_operators_with_empty_values.bold.join(', '))
  end

  def invalid_dates_warning
    collect { |filter| filter.invalid_date_warning }.compact
  end

  def unknown_enumeration_or_type_value_warning
    grouped_filters.collect { |(key, value)| value.unknown_enumeration_or_type_value_warning(project) }.compact
  end

  def undefined_project_variable_warning
    collect { |filter| filter.undefined_project_variable_warning }.compact
  end

  def undefined_values_warning
    collect { |filter| filter.undefined_value_warning }.compact
  end

  def plv_not_associated_with_property_warning
    collect { |filter| filter.plv_not_associated_with_property_warning if filter.undefined_project_variable_warning.blank? }.compact
  end

  def type_specific_filters
    reject(&:global_property_filter?) - undefined_filters
  end

  def global_properties
    global_property_names = filter_property_names.reject(&:blank?).collect(&:downcase) - valid_properties - undefined_filters - [@project.card_type_definition.name.downcase]
    global_property_names.collect {|property_name| project.find_property_definition(property_name).name }
  end

  def join(*args)
    args.join(' ')
  end

  #FilterGroup understands a set of filters grouped by the same property
  class FilterGroup
    include Enumerable
    attr_reader :property_definition_name, :filters

    def initialize(property_definition_name, filters=nil)
      @property_definition_name = property_definition_name
      @filters = filters || []
    end

    def each(&block)
      filters.each(&block)
    end

    def size
      filters.size
    end

    def multiple_values?
      !(size == 1 && @filters.first.individual?)
    end

    def description_without_header
      individual_filters, collective_filters = partition(&:individual?)

      individual_description = individual_filters.empty? ? nil : "#{property_definition_name} is " + individual_filters.collect(&:display_value).sort.join(' or ')
      collective_description = collective_filters.empty? ? nil : collective_filters.collect(&:description_without_header).join(' and ')

      [individual_description, collective_description].compact.join(' and ')
    end

    def as_card_query_conditions
      as_query(:as_card_query_conditions)
    end

    def as_card_query
      CardQuery.new(:conditions => as_card_query_conditions)
    end

    def as_number_query
      as_query(:as_number_query)
    end

    def <<(filter)
      self.filters << filter
    end

    def property_values_by_operator
      hash = Hash.new { |h, key| h[key] = []}
      filters.inject(hash) do |h, filter|
        h[filter.operator.operator_symbol] << filter.property_value
        h
      end
    end

    def unknown_enumeration_or_type_value_warning(project)
      property_definition = project.find_property_definition_including_card_type_def(property_definition_name)
      return nil unless property_definition.respond_to? :contains_value?
      invalid_values = filters.inject([]) do |aggregator, filter|
        unless filter.not_set_value? || filter.plv?
          aggregator << filter.value unless property_definition.contains_value?(filter.value)
        end
        aggregator
      end.uniq
      type = property_definition.is_a?(CardTypeDefinition)? 'Card Type' : 'Property'
      invalid_values.size == 0 ? '' : "#{type} #{property_definition_name.bold} contains invalid #{'values'.plural(invalid_values.size)} #{invalid_values.bold.to_sentence}"
    end

    private
    def as_query(query_type)
      individual_filters, collective_filters = partition(&:individual?)
      individual_conditions = filters_to_conditions(individual_filters, query_type, CardQuery::Or)
      collective_conditions = filters_to_conditions(collective_filters, query_type, CardQuery::And)
      (individual_conditions && collective_conditions) ? CardQuery::Or.new(individual_conditions, collective_conditions) : individual_conditions || collective_conditions
    end

    def filters_to_conditions(filters, query_type, conjunction_condition_class)
      if filters.size > 1
        conjunction_condition_class.new(*(filters.collect(&query_type)))
      elsif filters.size == 1
        filters.first.send(query_type)
      end
    end
  end

  #Filter understands a particular property, value and operator combination that restricts a selection of cards
  class Filter

    class << self
      def encode(property_definition_name, value, operator=Operator.parse('is'))
        value = value.login if value.respond_to?(:login)
        "[#{property_definition_name}][#{operator}][#{value}]"
      end

      def empty(project)
        self.new(project, "[][][#{PropertyValue::IGNORED_IDENTIFIER}]")
      end

      def type_filter(project)
        self.new(project, "[#{project.card_type_definition.name}][][#{PropertyValue::IGNORED_IDENTIFIER}]")
      end
    end

    attr_reader :operator, :value, :project, :property_definition_name, :property_definition
    attr_writer :value

    def initialize(project, filter_parameter)
      @project = project
      filter_parameter =~ ENCODED_FORM
      @property_definition_name, @operator, @value = $1, Operator.parse($2), $3
      @property_definition = project.find_property_definition_or_nil(@property_definition_name)
      @property_definition_name = @property_definition.name if @property_definition
    end

    def value
      @value unless (card_type_filter? && ignored?)
    end

    def operator_name
      if property_definition
        (property_definition.class == DatePropertyDefinition && operator.class.respond_to?(:date_name))? operator.class.date_name : operator.to_s
      end
    end

    def description_without_header
      "#{property_definition_name} #{operator_description} #{display_value}"
    end

    def ignored?
      @value == PropertyValue::IGNORED_IDENTIFIER
    end

    def card_type_filter?
      property_definition_name.downcase == project.card_type_definition.name.downcase
    end

    def relationship_filter?
      property_definition.kind_of? TreeRelationshipPropertyDefinition
    end

    def range_filter?
      !operator.supports_filtering_by_null?
    end

    def filtered_by?(another_property_definition)
      if(another_property_definition.respond_to?(:name))
        property_definition == another_property_definition
      else
        # another_property_definition is a name
        another_property_definition && (property_definition_name.downcase == another_property_definition.downcase)
      end
    end

    def rename_property(new_name)
      @property_definition_name = new_name
    end

    def rename_property_value(new_value)
      @value = new_value
    end

    def rename_project_variable(old_name, new_name)
      if plv?
        plv_name = ProjectVariable.extract_plv_name(value)
        @value = ProjectVariable.display_name(new_name) if plv_name.ignore_case_equal?(old_name)
      end
    end

    def update_date_format(old_format, new_format)
      return if property_definition.class != DatePropertyDefinition
      return if @value.blank?
      return if ProjectVariable.is_a_plv_name?(@value)
      return if @value.downcase == PropertyType::DateType::TODAY.downcase
      old_date = Date.parse_with_hint(@value, old_format)
      @value = old_date.strftime(new_format) if old_date
    end

    def global_property_filter?
      property_definition.global? if property_definition
    end

    def uses_today?
      value && value.downcase == PropertyType::DateType::TODAY.downcase
    end


    def plv?
      ProjectVariable.is_a_plv_name?(value)
    end

    def uses_plv?(plv)
      plv.display_name.ignore_case_equal?(value)
    end

    def undefined_project_variable_warning
      if plv?
        plv_name = ProjectVariable.extract_plv_name(value)
        "Project variable #{value.bold} is undefined." unless ProjectVariable.is_defined?(project, plv_name)
      end
    end

    def undefined_value_warning
      return nil unless @property_definition
      return nil if !(@property_definition.property_type.respond_to?(:valid_url?)) || ignored? || plv?

      begin
        @property_definition.property_type.valid_url?(@value)
        nil
      rescue  PropertyDefinition::InvalidValueException => exception
        "#{value.bold} is an unknown #{@property_definition.property_type.to_sym}."
      end
    end

    def plv_not_associated_with_property_warning
      value_as_plv.unassociated_property_warning(property_definition) if plv?
    end

    def as_card_query_conditions
      if plv?
        plv_name = ProjectVariable.extract_plv_name(value)
        begin
          CardQuery::Condition.comparison_between_column_and_plv(CardQuery::Column.new(property_definition.name), @operator, CardQuery::PLV.new(plv_name))
        rescue CardQuery::PLV::InvalidNameError
          property_definition.to_card_query(value, @operator) if property_definition
        end
      elsif uses_today?
        CardQuery::Condition.comparison_between_column_and_today(CardQuery::Column.new(property_definition.name), @operator)
      else
        property_definition.to_card_query(value, @operator) if property_definition
      end
    end

    def as_number_query
      if property_definition && (PropertyType::CardType === property_definition.property_type)
        if plv?
          plv_name = ProjectVariable.extract_plv_name(value)
          CardQuery::Condition.comparison_between_column_and_plv(CardQuery::CardIdColumn.new, @operator, CardQuery::PLV.new(plv_name))
        else
          CardQuery::Condition.comparison_between_column_and_value(CardQuery::Column.new('number'), operator, value)
        end
      end
    end

    def individual?
      @operator.result_is_individual_value?
    end

    def flip_relationship_filters_for_card_type(card_type)
      if relationship_filter? && (property_definition.valid_card_type == card_type)
        plv? ? nil : Filter.new(self.project, Filter.encode(self.property_definition_name, self.value, Operator.parse('is not')))
      else
        self
      end
    end

    def property_value
      property_definition && property_definition.property_value_from_url(value)
    end

    def display_value
      if property_definition.property_type.reserved_identifiers.ignore_case_include?(value)
        value.bold
      else
        property_value.display_value.bold
      end
    end

    def value_value
      return property_definition.class.current if (property_definition.class.respond_to?(:current) && property_definition.class.current.last == value)
      return [value, value] if plv?
      # TODO Why we rescue here??
      display_value = value_display_value rescue nil
      url_identifier = property_value.url_identifier rescue nil
      [display_value, url_identifier || '']
    end

    def to_params
      "[#{property_definition_name}][#{operator}][#{value}]" if value
    end

    def to_hash
      filter_value = (!property_definition.nullable? && value.blank?) ? PropertyValue::IGNORED_IDENTIFIER : value
      {:property => property_definition_name, :operator => operator_name, :value => filter_value }
    end

    def ==(other)
      return false unless other
      return false unless other.filtered_by?(self.property_definition)
      return true if self.value == other.value
      if self.value && other.value
        self.value.downcase == other.value.downcase #also consider operator
      end
    end

    def valid_value?(other_value)
      return true if any_value?
      @operator.compare(@property_definition.comparison_value(@value), @property_definition.comparison_value(other_value))
    end

    def invalid_date_warning
      return nil if !@property_definition.respond_to?(:date_by_value_identifier) || ignored? || plv?

      begin
        @property_definition.date_by_value_identifier @value
        ''
      rescue  PropertyDefinition::InvalidValueException => exception
        "Property #{property_definition_name.bold} #{exception.message}"
      end
    end

    alias_method :to_s, :to_params
    alias_method :inspect, :to_params

    def is_equality_operator?
      @operator.is_equality?
    end

    def not_set_value?
      @value.empty?
    end

    def any_value?
      @value == PropertyValue::ANY
    end

    def value_display_value
      if property_value
        property_value.display_value
      else
        value
      end
    end

    private

    def value_as_plv
      raise 'Filter does not represent a project variable' unless plv?
      project.project_variables.detect { |plv| uses_plv?(plv) }
    end

    def operator_description
      @operator.description(property_definition)
    end
  end
end
