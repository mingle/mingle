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

class CardQuery

  module Quoting
    def quote(value)
      value =~ /\s/ ? "'#{value}'" : value
    end
  end

  class DomainException < StandardError
    attr_reader :project

    def initialize(message, project=nil)
      @project = project
      super(message)
    end
  end

  class ThisCardProperty
    delegate :compare_with, :url_identifier, :in_comparison_value, :to => :@value
    delegate :property_definition, :name, :to => :@property_column

    def initialize(property_name, options)
      @content_provider = options[:content_provider]
      raise DomainException.new("THIS CARD is not supported for cross project macros.") if @content_provider && Project.current.id != @content_provider.project_id

      @property_column = Column.new property_name

      if availability = @content_provider.try(:this_card_condition_availability)
        availability.validate "THIS CARD.#{@property_column.name.as_mql}", options[:alert_receiver]
      end

      @value = ThisCardConditionAvailability::Now === availability ? AvailableValue.new(@content_provider, @property_column) : UnavailableValue.new

      validate_card_types
    end

    alias :as_mql :url_identifier

    private

    def validate_card_types
      if @content_provider && @content_provider.card_type && !property_definition.can_use_with_card_type?(@content_provider.card_type)
        raise DomainException.new("Card property '#{@property_column.name.bold}' is not valid for '#{@content_provider.card_type.name.bold}' card types.")
      end
    end

    class AvailableValue
      def initialize(content_provider, property_column)
        @content_provider = content_provider
        @property_column = property_column
      end

      def compare_with(column, operator)
        if column.property_definition.property_type.is_a?(PropertyType::CardType)
          value = ['number', 'name'].include?(@property_column.column_name.downcase) ? url_identifier : CardPropertyMqlSupport.card_id(db_identifier)
          Condition.comparison_between_column_and_value(column, operator, value)
        else
          Condition.comparison_between_column_and_value(column, operator, url_identifier)
        end
      end

      def url_identifier
        PropertyValue.new(property_definition, db_identifier).url_identifier.to_s
      end

      def in_comparison_value(column)
        identifier = url_identifier
        raise DomainException.new("The value of THIS CARD.#{@property_column.name.as_mql} is NULL and cannot be used in an IN or NUMBERS IN clause.") if identifier.blank?
        # this seems something wrong, but it is also not good to push this into Column#validate_comparison_value
        # because card prop value can be name
        if column.property_definition.property_type.is_a?(PropertyType::CardType) && !identifier.numeric?
          column.invalid_comparison_value(column.property_definition, identifier)
        end
        column.validate_comparison_value(identifier)
        identifier
      end

      private
      def db_identifier
        @content_provider.send(@property_column.column_name)
      end

      def property_definition
        @property_column.property_definition
      end
    end

    class UnavailableValue
      def compare_with(column, operator); IsNull.new(column); end
      def url_identifier; ''; end
      def in_comparison_value(column); end
    end
  end

  class PLV
    class InvalidNameError < DomainException; end

    attr_reader :plv

    def initialize(plv_name)
      @plv = project.project_variables.detect { |plv| plv.name.ignore_case_equal?(plv_name) }
      raise InvalidNameError.new("The project variable (#{plv_name.bold}) does not exist", project) unless @plv
    end

    def project
      Project.current
    end

    def to_s
      @plv.card_query_value
    end

    def card_plv?
      @plv.data_type == ProjectVariable::CARD_DATA_TYPE
    end

    def compare_with(column, operator)
      verify_comparison_types(column)
      if card_plv?
        if column.is_a?(CardIdColumn)
          Condition.comparison_between_column_and_value(column, operator, @plv.value ? @plv.value.to_i : nil)
        else
          Condition.comparison_between_column_and_value(column, operator, CardPropertyMqlSupport.card_id(@plv.value))
        end
      else
        Condition.comparison_between_column_and_value(column, operator, @plv.card_query_value)
      end
    end

    def verify_comparison_types(column)
      property = column.property_definition
      property_type = property.property_type

      unless @plv.associated_with?(property) || CardIdColumn::CardIdPropertyDefinition === property
        raise DomainException.new("Comparing between property '#{column.name.bold}' and project variable #{@plv.display_name.bold} is invalid as they are not associated with each other.", project)
      end
    end

    def display_name
      @plv.display_name
    end

    def accept(operation)
      operation.visit_plv(@plv)
    end

    def rename(old_name, new_name)
      if @plv.name.downcase == old_name.downcase
        @new_plv_name = ProjectVariable::display_name(new_name)
      end
    end

    def uses?(plv)
      @plv == plv
    end

    private
    def humanize(clazz)
      clazz.name.split('::').last.underscore.gsub(/_/, ' ')
    end
  end

  #todo: raise error when can't find the tree by the tree name
  class Tree

    class TreeNotExistError < DomainException; end

    class MultipleTreesNotSupportedError < DomainException; end
    attr_reader :tree_names
    def initialize(tree_names)
      @tree_names = tree_names
      raise MultipleTreesNotSupportedError.new("FROM TREE condition does not support multiple trees", project) if @tree_names.size > 1
      @trees = tree_names.collect do |name|
        tree = project.tree_configurations.detect{|tree_config| tree_config.name.ignore_case_equal?(name)}
        raise TreeNotExistError.new("Tree with name '#{name.bold}' does not exist", project) unless tree
        tree
      end
    end

    def mql_token
      "FROM TREE #{@tree_names.join(', ')}"
    end

    def join_conditions_with(conditions)
      # It does not support mutiple trees now
      in_tree = InTree.new(@trees.first)
      if conditions
        FromTree.new(in_tree, conditions)
      else
        FromTree.new(in_tree, [])
      end
    end

    def project
      Project.current
    end
  end

  class NonConditionalPartsExists < DomainException
    attr_reader :none_conditional_parts
    def initialize(query)
      @none_conditional_parts = query.none_conditional_parts
      super "#{@none_conditional_parts.map(&:bold).to_sentence(:last_word_connector => ' and ')} #{"is".plural(@none_conditional_parts.size)} not required to filter by MQL. Enter MQL conditions only."
    end
  end

  def self.parse(expression, options = {})
    self.do_parse expression, options
  end

  def self.parse_as_condition_query(expression, options={})
    unless expression.blank?
      expression.strip!
      expression = "WHERE #{expression}" unless expression =~ /^(where|select|from) /i
    end
    self.do_parse(expression, options).tap do |query|
      raise NonConditionalPartsExists.new(query) if query.none_conditional_parts.any?
    end
  end

  def self.empty_query
    @empty_query ||= new()
  end

  def self.card_version_table_alias
    # Make Card table name as the alias of version table name when we do historical query, so that we don't change
    # any code in CardQuery::Column, CardQuery::Condition and PropertyDefinitionSQL.
    # This is a hack, but works perfectly -- quote from @xli
    Card.quoted_table_name
  end


  attr_reader :columns, :conditions, :group_by, :order_by, :from, :content_provider, :alert_receiver, :as_of, :as_of_string
  attr_accessor :cast_numeric_columns, :fetch_descriptions

  def initialize(options = {})
    @from = options[:from]
    @columns = options[:columns] || []
    @user_columns = options[:columns] || []
    @distinct = options[:distinct] || nil
    @conditions = options[:conditions]
    @group_by = options[:group_by] || []
    @order_by = options[:order_by] ? options[:order_by].dup : []
    @content_provider = options[:content_provider]
    @alert_receiver = options[:alert_receiver]
    @fetch_descriptions = options[:fetch_descriptions]

    validate_as_of_format(options[:as_of]) if options[:as_of]
    validate_duplicate_columns(@columns, "SELECT")
    validate_duplicate_columns(@order_by, "ORDER BY")
    validate_duplicate_columns(@group_by, "GROUP BY")
    validate_that_invalid_options_are_not_sepcified_for_a_sub_query if options[:sub_query]

    if has_aggregated_columns?
      @group_by = non_aggregated_columns.collect { |column| CardQuery::GroupByColumn.new(column) } if @group_by.empty?
      @order_by = [CardQuery::OrderByColumn.new(@columns.first)] if @order_by.empty? && @columns.size > 1
      @order_by = [] if @group_by.empty?
    end

    if @order_by.empty? && single_numeric_column?
      @order_by = [CardQuery::OrderByColumn.new(columns[0])]
    end

    add_default_order_if_needed
    if @from
      @conditions = @from.join_conditions_with(@conditions)
    end

    raise DomainException.new("Cannot use #{'AS OF'.bold} in conjunction with #{'FROM TREE'.bold}.") if (@as_of && @from)
    raise DomainException.new("Cannot use #{'AS OF'.bold} in conjunction with #{'TAGGED WITH'.bold}.") if (@as_of && uses_tagged_with?)
    raise DomainException.new("Cannot use #{'AS OF'.bold} in conjunction with #{'IN PLAN'.bold}.") if (@as_of && uses_in_plan?)
    check_validity_of_group_by
  end

  def uses_plv?(plv)
    @conditions.uses_plv?(plv) if @conditions
  end

  def uses_from_tree_as_condition?(tree_name)
    @from && @from.tree_names.any?{|name| name.ignore_case_equal?(tree_name)}
  end

  def distinct?
    @distinct
  end

  def has_aggregated_columns?
    return false if @columns.nil? || @columns.empty?
    @columns.any? { |c| AggregateFunction === c }
  end

  def non_aggregated_columns
    @columns.select { |c| !(AggregateFunction === c) }
  end

  def validate_as_sub_query_for_comparison_against(column)
    raise DomainException.new("Nested MQL statments can only SELECT one property.") if @columns.size > 1
    raise DomainException.new("Nested MQL statments can only SELECT name or number properties.") if column.property_definition.refers_to_cards? &&
    !@columns.first.extracts_value_comparable_to_a_relationship_property?
  end

  def to_sql(options={})
    options[:cast_numeric_columns] = cast_numeric_columns
    sql = "#{select_clause_sql(options)} FROM #{sql_from_clause(options)}"
    if options[:limit]
      project.connection.add_limit_offset!(sql, :limit => options[:limit])
    end
    sql
  end

  def to_card_version_sql(options={})
    raise DomainException.new("Cannot use #{'FROM TREE'.bold} in query against historical data") if @from
    raise DomainException.new("Cannot use #{'TAGGED WITH'.bold} in query against historical data") if uses_tagged_with?

    if (aggregates = aggregate_properties).any?
      aggregate_names = aggregates.collect(&:name).collect(&:bold).to_sentence(:last_word_connector => ' and ')
      raise DomainException.new("Cannot use Aggregate Property #{aggregate_names} in query against historical data")
    end

    raise DomainException.new("use of #{'GROUP BY'.bold} is invalid, input MQL conditions only") unless @group_by.empty?

    version_table_alias = self.class.card_version_table_alias
    options[:cast_numeric_columns] = cast_numeric_columns
    %{
      #{select_clause_sql(options)}
      FROM #{Card::Version.quoted_table_name} #{version_table_alias}
      #{ joins_clause_sql(options) }
      #{ where_clause_sql(options) }
    }
  end

  def from_table_name
    @as_of ? "#{Card::Version.quoted_table_name} #{self.class.card_version_table_alias}" : Card.quoted_table_name
  end

  def sql_from_clause(options = {})
    as_of_join_sql = if @as_of
      beginning_of_tomorrow = (@as_of + 24.hours).to_s(:db)
      <<-AS_OF_JOIN_SQL
        INNER JOIN (
          SELECT v.card_id, MAX(v.version) as version FROM #{Card::Version.quoted_table_name} v
          INNER JOIN #{Card.quoted_table_name} c
          ON v.card_id = c.id
          WHERE v.updated_at < #{Project.connection.datetime_insert_sql(beginning_of_tomorrow)}
          GROUP BY v.card_id) as_of ON as_of.version = #{Card.quoted_table_name}.version AND as_of.card_id = #{Card.quoted_table_name}.card_id
      AS_OF_JOIN_SQL
    else
      nil
    end
    [from_table_name, as_of_join_sql, joins_clause_sql(options), where_clause_sql(options), group_by_clause_sql(options), order_by_clause_sql(options)].compact.join(" ")
  end

  def where_clause_sql(options = {})
    @conditions ? "WHERE #{@conditions.to_sql(options)}" : ''
  end

  def select_clause_sql(options = {})
    return '' if Array(options[:exclude]).include?(:select)
    columns = @columns && !@columns.empty? ? @columns.collect { |c| c.to_select_sql(options) } : ["#{Card.quoted_table_name}.*"]
    order_by_columns = if distinct?
      distinct = "DISTINCT "
      order_by_column_names
    else
      []
    end
    # select distinct must have order by columns inside select clause (postgresql)
    #
    # should put order_by_columns before user selected columns
    # so that user selected columns can overwrite order_by_columns that have same alias name
    # also see extract_requested_values_from for details how we extract data
    select = "SELECT #{distinct}#{(order_by_columns + columns).join(', ')} "
  end

  def order_by_clause_sql(options = {})
    return '' if Array(options[:exclude]).include?(:order_by)
    order_by_columns = @order_by.collect(&:order_by_columns).flatten
    return '' if order_by_columns.blank?
    "ORDER BY #{order_by_columns.uniq.join(', ')} "
  end

  def group_by_clause_sql(options = {})
    return '' if Array(options[:exclude]).include?(:group_by)
    return '' if @group_by.empty?
    # if we are grouping also need to group by the columns we joined in to sort
    group_by_column_names = @group_by.collect { |c| c.group_by_columns(options) } + order_by_column_names
    return '' if group_by_column_names.empty?
    "GROUP BY #{group_by_column_names.uniq.join(', ')} "
  end

  def to_card_id_sql(options = {})
    "SELECT #{Card.quoted_table_name}.id #{to_sql(:exclude => [:select, :order_by, :group_by])}"
  end

  def to_s
    return @conditions.to_s if @columns.blank? && @group_by.empty? && @order_by == [default_order_by_column]
    distinct = "DISTINCT " if distinct?
    select = "SELECT #{distinct}#{@columns.join(', ')} " if @columns.any?
    where = "WHERE #{@conditions} " if @conditions
    group_by = "GROUP BY #{@group_by.join(', ')} " if @group_by.any?
    order_by = "ORDER BY #{@order_by.join(', ')} " if @order_by.any?
    as_of = "AS OF #{Project.current.utc_to_local(@as_of).strftime('%Y-%m-%d').inspect} " if @as_of
    "#{select}#{as_of}#{where}#{group_by}#{order_by}"
  end

  #do not modify this perf enhancement without doing a profiling of a grid view grouped by
  #a relationship property with a large number of values
  def inspect
    "CardQuery:#{object_id}"
  end

  def joins_clause_sql(options = {})
    joins = Joins.new
    @order_by.each { |col| col.collect_order_by_join_sql(joins, options) }
    need_join_columns.each { |col| col.collect_value_join_sql(joins, options) }
    @conditions.collect_value_join_sql(joins, options) if @conditions
    joins.to_sql(options)
  end

  def need_join_columns
    conditions = @conditions ? @conditions.flatten_condition.select{|c| c.respond_to?(:column)} : []
    condition_columns = conditions.collect(&:column).collect(&:column_name)
    @columns.reject{|c|condition_columns.include?(c.column_name)}
  end

  def order_by_column_names
    @order_by.collect(&:order_by_column_names).flatten.uniq
  end

  def single_numeric_column?
    @columns.size == 1 && !has_aggregated_columns? && @columns[0].property_definition && @columns[0].property_definition.numeric?
  end

  def values(limit=nil, benchmark=false)
    if benchmark
      retrieved_values = nil
      values = nil
      benchmark = Benchmark.measure do
        retrieved_values = project.connection.select_all(to_sql(:limit => limit)).map(&:stringify_number_values)
      end
      Rails.logger.info("CardQuery: Time taken to fetch data: #{benchmark}")

      benchmark = Benchmark.measure do
        values = extract_requested_values_from retrieved_values
      end
      Rails.logger.info("CardQuery: Time taken to extract requested data: #{benchmark}")
      values
    else
      retrieved_values = project.connection.select_all(to_sql(:limit => limit)).map(&:stringify_number_values)
      extract_requested_values_from retrieved_values
    end
  end

  def values_for_macro(options)
    macro_values(options).to_values
  end

  def values_as_xml(options = {:api_version => 'v1'})
    macro_values(options).to_xml
  end

  def values_as_expanded_card_names
    @columns.unshift(CardQuery::CardIdColumn.new)
    @columns.push(CardQuery::Column.new('Name'))
    value_rows.inject({}) do |hash, row|
      k = row.shift
      last = row.pop
      names = row.compact.map{|n| n.gsub(/\A#\d+ /, '')}
      names << last
      hash[k] = names.join(' > ')
      hash
    end
  end


  def find_cards_ordered_by_property(options = {})
    raise DomainException.new('Should select at least one card property') unless @columns && @columns.size >= 1 && @columns.first.is_a?(CardQuery::Column)
    sort_column = @columns.first
    @columns.unshift(CardQuery::CardNameColumn.new, CardQuery::CardNumberColumn.new)
    @group_by.unshift(CardQuery::CardNameColumn.new, CardQuery::CardNumberColumn.new)
    @order_by.unshift(CardQuery::CardOrderColumn.new('updated_at'))
    card_results = values.inject({}) do |results, card|
      value = sort_column.value_from(card, cast_numeric_columns)
      results[value] ||= []
      results[value] << {:name => card['name'], :number => card['number']}
      results
    end
    @columns.shift(2)
    @group_by.shift(2)
    @order_by.shift
    if options[:limit].to_i > 0
      card_results.each {|key, c| card_results[key] = {:cards => c.take(options[:limit].to_i), :count => c.count}}
    end
    card_results
  end

  def values_as_abbreviated_card_names
    @columns.unshift(CardQuery::CardIdColumn.new)
    @columns.push(CardQuery::Column.new('Name'))
    value_rows.inject({}) { |hash, row| hash[row.shift] = row.last; hash }
  end

  def accept(operation)
    operation.tap do |o|
      o.visit_card_query(self)
      (@columns || []).each { |c| c.accept(o) }
      @conditions.accept(o) if @conditions
      @group_by.each { |c| c.accept(o) }
      @order_by.each { |c| c.accept(o) }
    end
  end

  def as_card_list_view(options = { :defensively => true })
    params = {:filters => {:mql => CardQuery::MqlGeneration.new(@conditions).execute}}
    if @order_by.any?
      params[:sort] = @order_by.first.to_s
      params[:order] = 'ASC'
    end
    CardListView.construct_from_params(Project.current, params, options[:defensively])
  end

  def single_values
    values.collect { |record| @columns.first.value_from(record, cast_numeric_columns) }
  end

  def value_rows
    values.collect{ |record| @columns.collect{ |col| col.value_from(record, cast_numeric_columns)  }  }
  end

  def single_value
    single_values.first
  end

  def select_column_query(column_name)
    column = column_name.is_a?(String) ? CardQuery::Column.new(column_name) : column_name
    query = self.class.new(:columns => [column])
    query.restrict_with!(self)
    query
  end

  def restrict_with!(query_conditions)
    case query_conditions
    when nil
      return self
    when String
      return restrict_with!(CardQuery.parse(query_conditions, {:content_provider => self.content_provider, :alert_receiver => self.alert_receiver}))
    when CardQuery
      return restrict_with!(query_conditions.conditions)
    else
      if @conditions
        @conditions = join_conditions_with_from_tree(@conditions, query_conditions)
      else
        @conditions = query_conditions
      end
    end
  end

  def join_conditions_with_from_tree(conditions, another_conditions)
    if conditions.is_a?(FromTree)
      join_from_tree_condition_with_not_from_tree_condition(conditions, another_conditions)
    elsif another_conditions.is_a?(FromTree)
      join_from_tree_condition_with_not_from_tree_condition(another_conditions, conditions)
    else
      And.new(conditions, another_conditions)
    end
  end

  def join_from_tree_condition_with_not_from_tree_condition(from_tree, not_from_tree)
    other_conditions =  And.new(from_tree.other_conditions, not_from_tree)
    FromTree.new(from_tree.tree_condition, other_conditions)
  end

  def restrict_with(additional_conditions, options = {})
    new_query = self.dup
    new_query.restrict_with!(additional_conditions)
    new_query.cast_numeric_columns = options[:cast_numeric_columns]
    new_query
  end

  def order_and_group_by_first_column_if_necessary
    self.dup.tap do |result|
      result.order_by << CardQuery::Column.new(self.columns.first.property_definition.name) unless result.ordered_by?(self.columns.first.property_definition)
      result.group_by << CardQuery::Column.new(self.columns.first.property_definition.name) unless result.grouped_by?(self.columns.first.property_definition)
    end
  end

  def ordered_by?(property_definition)
    order_by.any? { |ordering_column| ordering_column.property_definition == property_definition }
  end

  def grouped_by?(property_definition)
    group_by.any? {|grouping_column| grouping_column.property_definition == property_definition }
  end

  def to_conditions(options = {})
    @conditions.to_sql(options)
  end

  def has_conditions
    !@conditions.nil?
  end

  def values_as_coords
    Hash[*values_as_pairs.flatten]
  end

  def values_as_pairs
    raise DomainException.new('Should provide at least 2 columns.') if @columns.size < 2
    x, y, *rest = @columns
    values.collect{ |record| [x.value_from(record, cast_numeric_columns), project.to_num(y.value_from(record, cast_numeric_columns))]}
  end

  def tags
    TaggedWithDetector.new(self).execute
  end

  def explicit_card_type_names
    CardTypeDetector.new(self).execute
  end

  def uses_tagged_with?
    TaggedWithConditionDetection.new(self).execute
  end

  def uses_in_plan?
    InPlanConditionDetection.new(self).execute
  end

  def can_be_cached?
    return true unless @conditions
    @conditions.can_be_cached?
  end

  def to_joins_where_and_group_by_clause_sql
    options = {:cast_numeric_columns => cast_numeric_columns}
    "#{joins_clause_sql(options)}#{where_clause_sql(options)} #{group_by_clause_sql(options)}"
  end

  def comparisons
    @conditions.collect {|condition| condition.is_a? Comparison ? condition : nil}.compact
  end

  def find_cards_sql(options={})
    card_or_versions_table = from_table_name.split(" ").last

    columns = if (@columns.empty?)
      Card.column_names
    else
      excludes = options[:excludes] || []
      (Card.column_names.reject { |cn| excludes.include?(cn.downcase) } + @columns.map(&:column_name)).uniq
    end

    quoted_card_column_names = columns.map{ |column_name| "#{card_or_versions_table}.#{project.connection.quote_column_name(column_name)}" }
    "SELECT #{quoted_card_column_names.join(", ")} FROM #{sql_from_clause}"
  end

  def find_cards(pagination_options={})
    excludes = (pagination_options.delete(:excludes) || []).map(&:downcase)
    excludes << "description" unless (fetch_descriptions || excludes.include?("description"))
    sql = find_cards_sql(:excludes => excludes)
    project.connection.add_limit_offset!(sql, pagination_options)
    start = Time.now
    results = project.cards.find_by_sql sql
    duration = Time.now - start
    if SimpleBench.slow_sql?(duration)
      Rails.logger.warn %Q{[SLOW_SQL] execution took #{duration} sec
SQL:
#{sql}

Caller:
#{caller.join("\n")}
}
    end
    results
  end

  def card_count
    CardQuery.new(:columns => [AggregateFunction.new('count', Star.new)]).restrict_with(self).single_value.to_i
  end

  alias :count :card_count

  def paginate(options)
    project.cards.paginate_by_sql(self.find_cards_sql, options)
  end

  def find_base_info_cards
    base_columns = ['id', 'number', 'name']
    base_columns = base_columns.collect{ |column| project.connection.quote_column_name(column) }
    sql = "SELECT #{base_columns.join(", ")} FROM (SELECT #{base_columns.collect{|column| "#{Card.quoted_table_name}.#{column}"}.join(", ")} FROM #{sql_from_clause}) base_info_cards"
    project.cards.find_by_sql sql
  end

  def find_card_numbers
    project.connection.select_values(find_card_numbers_sql).collect(&:to_i)
  end

  def find_card_numbers_sql
    find_column_value_sql(:number)
  end

  def find_column_value_sql(column)
    "SELECT #{project.connection.quote_column_name column} FROM (SELECT #{Card.quoted_table_name}.#{project.connection.quote_column_name column} FROM #{sql_from_clause}) cards"
  end

  def first_column_is_row_title?
    return false if !(@columns.first.is_a? Column)
    remaining_columns = @columns.slice(1, @columns.length)
    return remaining_columns.all? { |column| column.is_a? AggregateFunction }
  end

  def project
    Project.current
  end

  def default_order_by_column
    ::CardQuery::OrderByColumn.new(Column.new('Number', 'DESC'))
  end

  def none_conditional_parts
    given_order_by = @order_by.reject{|c| c.name.to_s.downcase == 'number'}
    [@columns, @group_by, given_order_by].flatten.compact.collect(&:mql_token).flatten.uniq
  end

  def implied_card_types
    ImpliedCardTypeDetector.new(self).execute
  end

  def explicit_card_type_names
    CardTypeDetector.new(self).execute
  end

  def property_definitions
    PropertyDefinitionDetector.new(self).execute
  end

  def tree_config
    @from && project.tree_configurations.find_by_name(@from.tree_names.first)
  end

  private

  def macro_values(options)
    CardQuery::Results.new(values, options)
  end

  def aggregate_properties
    property_definitions.select { |p| AggregatePropertyDefinition === p }
  end

  def extract_requested_values_from(retrieved_values)
    return retrieved_values unless @user_columns && @user_columns.any?
    # extract values with case sensitive column alias, so that we can ignore the columns
    # coming from order by ( because select distinct must have order by columns inside select clause )
    # please also checkout method select_clause_sql
    return [] if retrieved_values.nil? || retrieved_values.empty?

    meta_data = create_meta_data(@user_columns, retrieved_values.first.keys)

    retrieved_values.map do |row|
      ActiveSupport::OrderedHash.new.tap do |result|
        meta_data.each do |column, alias_column_name,  column_from_data|
          column_value = column.mql_select_column_value(row[column_from_data])
          result[alias_column_name] = column_value.is_a?(Proc) ? column_value.call :  column_value
        end
      end
    end
  end

  def create_meta_data(columns, data_columns_from_first_row)
    columns.map do |column|
      alias_column_name = column.unquoted_column_alias
      [column, alias_column_name, data_columns_from_first_row.detect{|key| alias_column_name.ignore_case_equal?(key)}]
    end
  end

  def self.do_parse(expression, options = {})
    CardQueryParser.new.parse(expression, options)
  rescue ParseError => e
    raise DomainException, "#{e.message}. You may have a project variable, property, or tag with a name shared by a MQL keyword.  If this is the case, you will need to surround the variable, property, or tags with quotes."
  end

  def add_default_order_if_needed
    return if has_aggregated_columns? || distinct?
    @order_by << default_order_by_column if @group_by.empty? || order_by_column_names.empty?
  end

  def check_validity_of_group_by
    if @group_by.any? && non_aggregated_columns != @group_by
      unless @conditions && @group_by.any?{|gb| @conditions.columns.include?(gb)}
        raise DomainException.new('Use of GROUP BY is invalid. To GROUP BY a property you must also include this property in the SELECT statement.')
      end
     end
  end

  def validate_as_of_format(as_of_value)
    @as_of_string = as_of_value
    tmp = Date.parse_with_hint(as_of_value, Project.current.date_format)
    @as_of = Project.current.time_zone_obj.parse("#{tmp.year}-#{tmp.month}-#{tmp.day}").utc
  rescue ArgumentError
    raise DomainException.new("#{'AS OF'.bold} value should be of format #{Project.current.humanize_date_format.bold}")
  end

  def validate_duplicate_columns(columns, column_type)
    raise DomainException.new("Duplicate columns in #{column_type} clause are illegal") unless columns.collect(&:column_name).uniq == columns.collect(&:column_name)
  end

  def validate_that_invalid_options_are_not_sepcified_for_a_sub_query
    raise DomainException.new("AS OF is not allowed in a nested IN clause.") if @as_of_string
    raise DomainException.new("GROUP BY is not allowed in a nested IN clause.") if @group_by && !@group_by.empty?
    raise DomainException.new("ORDER BY is not allowed in a nested IN clause.") if @order_by && !@order_by.empty?
  end
end
require 'card_query/condition'
require 'card_query/column'
require 'card_query/mql_validations'
require 'property_definition_sql'
::CardQuery::Condition
::CardQuery::Column
::CardQuery.send(:include, CardQuery::MqlValidations)
::PropertyDefinitionSQL.bind
