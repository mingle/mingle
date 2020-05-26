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

module CardView
  class Workspace

    attr_reader :validation_errors

    def initialize(view)
      @view = view
      @project = view.project
      if @invalid = tree_workspace? && tree_configuration.nil?
        @validation_errors = ["There is no tree named #{name.bold}."]
      else
        @validation_errors = []
      end
    end

    def card_types
      tree_workspace? ? tree_configuration.all_card_types : project.card_types
    end

    def invalid?
      @invalid
    end

    def name
      @view.tree_name
    end

    def all_cards_query
      @view.filter_column_query
    end

    def all_cards_in_tree_params
      TreeFilters::default_params(tree_configuration)
    end

    def parse_filter_params(params)
      project = @view.project
      return MqlFilters.new(project, params[:filters][:mql]) if params[:filters].kind_of?(Hash) && params[:filters].has_key?(:mql)
      return Filters.new(project, params[:filters] || []) unless tree_configuration

      tree_filter_param_keys = params.keys.select { |k| ::TreeFilters.valid_parameter?(k, params[k]) }
      tree_filter_params = if tree_filter_param_keys.empty?
        all_cards_in_tree_params
      else
        tree_filter_param_keys.inject({}) { |tree_filters, tree_filter_param| tree_filters[tree_filter_param] = params[tree_filter_param]; tree_filters }
      end
      TreeFilters.new(project, tree_filter_params, tree_configuration)
    end

    def create_filter_params(filter_params)
      tree_configuration ? filter_params : {:filters => filter_params}
    end

    def column_properties
      @view.filters.column_properties
    end

    def display(view_helper, &block)
      unless @view.style == 'tree'
        yield
      end
    end

    def all_cards_tree
      @all_cards_tree ||= tree_configuration.create_tree(:base_query => @view.filter_column_query, :order_by => @view.order_by, :fetch_descriptions => @view.fetch_descriptions)
    end

    def expanded_cards_tree
      @expanded_cards_tree ||= tree_configuration.create_expanded_tree(@view.expands, :base_query => @view.filter_column_query, :order_by => @view.order_by, :fetch_descriptions => @view.fetch_descriptions)
    end

    def subtree(root_card)
      @subtree ||= tree_configuration.create_expanded_tree(@view.expands, :root => root_card, :level_offset => expanded_cards_tree.card_level(root_card), :base_query => @view.filter_column_query, :order_by => @view.order_by, :fetch_descriptions => @view.fetch_descriptions)
    end

    def empty_tree
      CardTree.empty_tree(tree_configuration)
    end

    def tree_workspace?
      !name.blank?
    end

    def viewable_styles
      tree_workspace? ? CardView::Style::TREE_STYLES : CardView::Style::CLASSIC_STYLES
    end

    def tree_configuration
      return unless tree_workspace?
      @tree_configuration ||= @view.project.find_tree_configuration(name)
    end

    def color_values
      return tree_configuration.all_card_types if tree_workspace? && @view.color_by_property_definition.name == 'Type'
      @view.color_by_property_definition.values
    end
  end
end
