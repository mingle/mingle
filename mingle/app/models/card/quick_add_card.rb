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

class QuickAddCard

  attr_reader :card, :project

  delegate :use_filters?, :tree_selected?, :tree_config_id, :to => :@builder

  def initialize(view, params)
    @builder = if params[:use_filters]
      view.filter_by_mql? ? ByMqlFilter.new(view, params) : ByFilters.new(view, params)
    else
      ByCardDefault.new(view, params)
    end
    @card = @builder.build_card
  end

  def displayed_inherited_property_definitions
    @builder.displaying_properties
  end

  def update_card_properties(properties)
    return if properties.blank?
    names = @card.card_type.property_definitions_with_hidden_without_order.map(&:name).map(&:downcase)
    applicable_properties = Hash[properties.select { |k,v| names.include?(k.downcase)}]

    @card.update_properties(applicable_properties, :method => 'get', :honor_trees => true)
  end

  def using_mql?
    # TODO: Used?
    @view.filter_by_mql?
  end


  class ByCardDefault
    def initialize(view, params = {})
      @view, @params = view, params
      @tree_config = view.workspace.tree_configuration
    end

    def use_filters?
      false
    end

    def tree_selected?
      @tree_config.present?
    end

    def tree_config_id
      @tree_config.id
    end

    def filter_properties
      []
    end

    def displaying_properties
      explicit_properties = @card.property_definitions_with_hidden.select { |prop_def| @card.property_value(prop_def).set? || filter_properties.include?(prop_def)}
      tree_properties = find_implicit_tree_properties(explicit_properties)
      explicit_properties - tree_properties + tree_properties
    end

    def build_card
      card_type_name = user_card_type_choice || drag_and_drop_card_type_choice || select_card_type(inferred_card_types) || fallback_card_type
      card_type_name = properly_case_card_type_name(card_type_name)
      @card = @view.project.cards.build_with_defaults(:card_type_name => card_type_name)
    end

    protected
    def find_implicit_tree_properties(explicit_properties)
      property_defs_by_tree_config = explicit_properties.select { |pd| pd.is_a?(TreeRelationshipPropertyDefinition) }.group_by { |pd| pd.tree_configuration }
      property_defs_by_tree_config.collect do |tree_config, property_defs|
        tree_config.relationships[0..(property_defs.max_by(&:position).position - 1)]
      end.flatten
    end

    def select_card_type(card_type_names)
      if card_type_names.ignore_case_include?(@params[:card_type_from_session])
        @params[:card_type_from_session]
      else
        card_type_names.first
      end
    end
    def user_card_type_choice
      @params[:card] && @params[:card][:card_type_name]
    end

    def drag_and_drop_card_type_choice
      # TODO: Merge error? Should make sense only in sub classes.
      @params[:card_properties] && @params[:card_properties][:Type]
    end

    def inferred_card_types
      []
    end

    def fallback_card_type
      @params[:card_type_from_session] || @view.project.card_types.first.name
    end

    private

    def properly_case_card_type_name(provided_card_type_name)
      existing_card_type_names = @view.project.card_types.collect(&:name)
      existing_card_type_names.detect { |existing_card_type_name| existing_card_type_name.downcase == provided_card_type_name.downcase }
    end
  end

  class ByFilters < ByCardDefault
    include AmbiguousValueSupport

    def use_filters?
      true
    end

    def build_card
      super.tap { apply_filter_properties }
    end

    def filter_properties
      properties = selected_filters.map(&:property_definition)
      properties.concat(@tree_config.relationships) if tree_selected?
      properties.uniq
    end

    protected

    def inferred_card_types
      return @view.filters.card_type_names if tree_selected?

      type_filters = @view.filters.grouped_filters['type']
      return @view.project.card_types.collect(&:name) if type_filters.blank?

      applicable_card_types(type_filters.property_values_by_operator)
    end

    def applicable_card_types(property_values_by_operator)
      minimum, maximum, accepts, rejects = filter_conditions(property_values_by_operator)
      applicable = if rejects.any?
        @view.project.card_type_definition.property_values.reject{|v| rejects.include?(v)}
      else
        []
      end
      [accepts.to_a + applicable.to_a].flatten.collect(&:value).uniq
    end


    def selected_filters
      return @view.filters unless tree_selected?
      selected_filters = []
      @view.filters.included_filters.each do |card_type_name, filters_for_type|
        if @card.card_type.name.ignore_case_equal?(card_type_name)
          selected_filters += (filters_for_type.to_params - ["[Type][is][#{card_type_name}]"])
        else
          filters_for_type.each do |f|
            next unless f.relationship_filter?
            selected_filters << f.to_params
          end
        end
      end
      Filters.new(@view.project, selected_filters, @tree_config)
    end

    def apply_filter_properties
      card_properties = Hash[selected_filters.grouped_filters.select(&applicable_filter?).collect(&filter_property_value)]
      @card.update_properties(card_properties, :method => 'get', :honor_trees => true)
      apply_tags
    end

    def apply_tags
      @card.tag_with(@view.tagged_with)
    end

    def applicable_filter?
      Proc.new { |prop_name, filter_group| @card.card_type.property_definition_names.ignore_case_include?(prop_name) }
    end

    def filter_property_value
      lambda do |prop_name, filter_group|
        property_definition = filter_group.first.property_definition
        default_value   = @card.card_type.card_defaults.property_value_for(prop_name)
        property_values = filter_group.property_values_by_operator
        value           = choose(property_values, property_definition, default_value)
        [property_definition.name, value]
      end
    end

  end

  class ByMqlFilter < ByFilters

    def filter_properties
      query = @view.filters.as_card_query
      properties = query.property_definitions.reject(&:calculated?)
      properties.concat(query.tree_config.relationships) if query.tree_config
      properties
    end

    protected
    def apply_filter_properties
      @card.property_definitions_with_hidden.each do |property_definition|
        @card.update_properties({property_definition.name => nil}, :method => 'get', :honor_trees => true) if @view.filters.as_card_query.property_definitions.include?(property_definition)
      end
      @card.tag_with(@view.tagged_with_from_filters)
    end

    def inferred_card_types
      if tree_config = @view.filters.as_card_query.tree_config
        return tree_config.all_card_types.collect(&:name).reverse
      end

      explicit_in = @view.filters.as_card_query.explicit_card_type_names[:included]

      first_property_in_mql = @view.filters.as_card_query.property_definitions.find { |pd| !pd.is_predefined }
      first_property_card_types = first_property_in_mql ? first_property_in_mql.card_types.compact.map(&:name) : []

      explicit_not_in = @view.as_card_query.explicit_card_type_names[:excluded]
      card_types = if explicit_not_in.any?
        (explicit_in + first_property_card_types + @view.project.card_types.map(&:name)).map(&:downcase) - explicit_not_in.map(&:downcase)
      else
        explicit_in + first_property_card_types
      end
      card_types[0..0]
    end
  end

end
