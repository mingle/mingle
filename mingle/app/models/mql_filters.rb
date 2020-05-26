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

class MqlFilters
  include FiltersSupport, HelpDocHelper, Enumerable

  MQL_SYNTAX_ERROR_MSG = "MQL in filter has incorrect syntax."

  attr_reader :project, :errors

  def initialize(project, mql_conditions)
    @project = project
    @mql_conditions = MqlConditions.parse_mql_conditions(mql_conditions)
    @errors = []
  end

  def sorted_filter_string
    "mql #{@mql_conditions.mql}"
  end

  def no_card_type_filters?
    card_type_names.empty?
  end

  def card_type_names
    @mql_conditions.card_type_names
  end

  def explicit_card_type_names
    @mql_conditions.explicit_card_type_names
  end

  def property_definitions_with_values
    @mql_conditions.property_definitions_with_values
  end

  def valid?
    @errors = validation_errors
    @errors.blank?
  end

  def invalid?
    !valid?
  end

  def as_card_query
    @mql_conditions.as_conditions_query
  end

  def each(&block)
    properties_to_values = @mql_conditions.property_definitions_with_values
    properties_to_values.each do |property, values|
      values.each do |value|
        filter = OpenStruct.new
        filter.property_definition = property
        filter.value = value.field_value
        yield filter
      end
    end
  end

  def validation_errors
    query = as_card_query
    mql_validations = CardQuery::MQLFilterValidations.new(query).execute
    return mql_validations if mql_validations.any?
    query.card_count
    query.to_sql
    []
  rescue CardQuery::DomainException
    [with_help_link($!.message)]
  rescue Exception
    [with_help_link(MQL_SYNTAX_ERROR_MSG)]
  end

  def rename_property(old_name, new_name)
    @mql_conditions = @mql_conditions.rename_property_mql_conditions(old_name, new_name)
  end

  def rename_property_value(property_name, old_value, new_value)
    @mql_conditions = @mql_conditions.rename_property_value_mql_conditions(property_name, old_value, new_value)
  end

  def rename_project_variable(old_value, new_value)
    @mql_conditions = @mql_conditions.rename_project_variable_mql_conditions(old_value, new_value)
  end

  def rename_card_type(old_name, new_name)
    @mql_conditions = @mql_conditions.rename_card_type_mql_conditions(old_name, new_name)
  end

  def rename_tree(old_name, new_name)
    @mql_conditions = @mql_conditions.rename_tree(old_name, new_name)
  end

  def uses_property_definition?(definition)
    @mql_conditions.uses_property_definition?(definition)
  end

  def uses_card_type?(card_type_name)
    @mql_conditions.uses_card_type?(card_type_name)
  end

  def uses_property_value?(prop_name, value)
    @mql_conditions.uses_property_value?(prop_name, value)
  end

  def uses_plv?(plv)
    @mql_conditions.uses_plv?(plv)
  end

  def uses_card?(card)
    @mql_conditions.uses_card?(card)
  end

  def uses_from_tree_as_condition?(tree_name)
    @mql_conditions.uses_from_tree_as_condition?(tree_name)
  end

  def using_card_as_value?
    @mql_conditions.using_card_as_value?
  end

  def cards_used_sql_condition
    @mql_conditions.cards_used_sql_condition
  end

  def project_variables_used
    @mql_conditions.project_variables_used
  end

  def as_card_query_conditions
    @mql_conditions.as_card_query_conditions
  end

  def update_date_format(*args)
    #do nothing
  end

  def filter_parameters
    [:filters]
  end

  def to_params
    {:mql => @mql_conditions.mql}
  end

  def empty?
    @mql_conditions.empty?
  end

  def description_header
    "MQL".italic
  end

  def to_s
    @mql_conditions.to_s
  end

  def description_without_header
    self.to_s
  end

  private

  def with_help_link(message)
    Thread.current['mingle_cache_help_link'] = 'Filter list by MQL'
    message
  end

  class MqlConditions
    attr_reader :mql

    def self.parse_mql_conditions(mql_conditions)
      query = CardQuery.parse_as_condition_query(mql_conditions)
      ParsedMqlConditions.new(mql_conditions, query)
    rescue
      UnparsedMqlConditions.new(mql_conditions)
    end

    def initialize(mql)
      @mql = mql
    end

    def empty?
      @mql.blank?
    end

    def to_s
      @mql
    end

    class ParsedMqlConditions < MqlConditions
      attr_reader :query

      def initialize(mql, query)
        super mql
        @query = query
      end

      def card_type_names
        query.implied_card_types.collect(&:name) rescue []
      end

      def explicit_card_type_names
        query.explicit_card_type_names
      end

      def as_conditions_query
        query
      end

      def rename_property_mql_conditions(old_name, new_name)
        rename_mql CardQuery::RenamedPropertyMqlGeneration, old_name, new_name
      end

      def rename_property_value_mql_conditions(property_name, old_value, new_value)
        rename_mql CardQuery::RenamedEnumerationValueMqlGeneration, property_name, old_value, new_value
      end

      def rename_project_variable_mql_conditions(old_value, new_value)
        rename_mql CardQuery::RenamedProjectVariableMqlGeneration, old_value, new_value
      end

      def rename_card_type_mql_conditions(old_name, new_name)
        rename_mql CardQuery::RenamedCardTypeMqlGeneration, old_name, new_name
      end

      def rename_tree(old_name, new_name)
        rename_mql CardQuery::RenamedTreeMqlGeneration, old_name, new_name
      end

      def uses_property_definition?(definition)
        CardQuery::PropertyDefinitionDetector.new(query).uses?(definition)
      end

      def uses_card_type?(card_type_name)
        CardQuery::CardTypeDetector.new(query).uses?(card_type_name)
      end

      def property_definitions_with_values
        CardQuery::PropertyValueDetector.new(query).property_definitions_with_values
      end

      def uses_property_value?(prop_name, value)
        CardQuery::PropertyValueDetector.new(query).uses?(prop_name, value)
      end

      def used_properties
        CardQuery::PropertyDefinitionDetector.new(query).execute
      end

      def uses_plv?(plv)
        query.uses_plv?(plv)
      end

      def uses_card?(card)
        card_usage_detector.uses?(card)
      end

      def uses_from_tree_as_condition?(tree_name)
        query.uses_from_tree_as_condition?(tree_name)
      end

      def using_card_as_value?
        card_usage_detector.uses_any_card?
      end

      def cards_used_sql_condition
        card_usage_detector.sql_condition
      end

      def project_variables_used
        CardQuery::ProjectVariableDetector.new(query).execute
      end

      def as_card_query_conditions
        [query.conditions]
      end

      private

      def card_usage_detector
        CardQuery::CardUsageDetector.new(query)
      end

      def rename_mql(rename_class, *args)
        args << query
        MqlConditions.parse_mql_conditions(rename_class.new(*args).execute)
      end
    end

    class UnparsedMqlConditions < MqlConditions
      def initialize(mql)
        super mql
      end

      def card_type_names; []; end
      def explicit_card_type_names; []; end
      def rename_property_mql_conditions(old_name, new_name); self; end
      def rename_property_value_mql_conditions(property_name, old_value, new_value); self; end
      def rename_project_variable_mql_conditions(old_value, new_value); self; end
      def rename_card_type_mql_conditions(old_name, new_name); self; end
      def rename_tree(old_name, new_name); self; end
      def uses_property_definition?(definition); false; end
      def uses_card_type?(card_type_name); false; end
      def property_definitions_with_values; {}; end
      def uses_property_value?(prop_name, value); false; end
      def uses_plv?(plv); false; end
      def uses_card?(card); false; end
      def using_card_as_value?; false; end
      def cards_used_sql_condition; ""; end
      def project_variables_used; []; end
      def as_card_query_conditions; []; end
      def uses_from_tree_as_condition?(tree_name); false; end
      def used_properties; []; end
      def as_conditions_query
        CardQuery.parse_as_condition_query(mql)
      end
    end
  end
end
