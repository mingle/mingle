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

class LanesController < ProjectApplicationController

  include CardSupport
  include CardListSupport
  include CardListViewState

  helper :cards, :card_list_view_tab_name

  def destroy
    cards_result_setup
    respond_to do |format|
      format.js do

        property_definition = PropertyDefinition.find_by_id params[dimension][:property_definition_id].to_i
        value_identifier = identifier_from_params
        unless value_identifier
          flash.now[:error] = "Cannot hide non-existent lane"
          render :update, :status => :unprocessable_entity do |page|
            page.refresh_flash
          end
          return
        end

        @view = @view.hide_dimension(dimension, value_identifier)
        @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])
        add_monitoring_event(monitoring_action, 'action' => 'hide', 'name' => value_identifier)

        refresh_list_page
      end
    end
  end

  def create
    property_definition = PropertyDefinition.find_by_id params[dimension][:property_definition_id].to_i
    if EnumeratedPropertyDefinition === property_definition
      new_value = EnumerationValue.find_existing(params[dimension]).nil?

      # for good measure, but should never get here via UI
      if (new_value && User.current.privilege_level(@project) < UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER)
        flash.now[:error] = "You must be a project admin in order to add new values."
        render(:update, :status => :unprocessable_entity) do |page|
          page.refresh_flash
          page.replace 'add_dimension_widget', :partial => "lanes/add_group_lane", :locals => { :view => @view}
        end
        return
      end

      enumeration_value = EnumerationValue.find_or_construct(params[dimension].merge(:nature_reorder_disabled => true))
    end

    cards_result_setup

    respond_to do |format|
      format.js do

        if enumeration_value && enumeration_value.errors.any?
          set_rollback_only
          flash.now[:error] = enumeration_value.errors.full_messages.join("; ")
          render(:update, :status => :unprocessable_entity) do |page|
            page.refresh_flash
            page.replace 'add_dimension_widget', :partial => "lanes/add_group_lane", :locals => { :view => @view}
          end
          return
        end

        value_identifier = identifier_from_params
        @view = @view.show_dimension(dimension, value_identifier)
        @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

        highlight_element = "#{@view.groups.send(dimension, value_identifier).html_id}_header"
        refresh_list_page(:after => lambda { |page| page << element_highlight_js(highlight_element) }) do |page|
          page.replace 'color-legend-container', :partial => 'shared/color_legend'
          page.replace 'filters-panel', :partial => @view.style.filter_tabs(@view), :locals => { :view => @view }
          page.replace 'lane_action_container', :partial => "lanes/lane_actions", :locals => { :view => @view }
        end

        action = new_value ? "add_new" : "add_existing"
        add_monitoring_event(monitoring_action, "action" => action, "name" => value_identifier)
      end
    end
  end

  def update
    cards_result_setup
    property_def = @view.group_lanes.lane_property_definition
    old_name = params[:lane_to_rename].try(:strip)
    new_name = params[:new_lane_name].try(:strip)

    new_property_value = property_def.rename_value(old_name, new_name)

    add_monitoring_event('column_action', 'action' => 'rename')
    respond_to do |format|
      format.js do
        unless new_property_value.errors.empty?
          set_rollback_only
          flash.now[:error] = new_property_value.errors.full_messages.join("; ")
          render(:update, :status => 422) do |page|
            page.refresh_flash
          end
          return
        end
        @view.rename_property_value(property_def.name, old_name, new_name)
        @view = CardListView.reload(@view)

        @project.clear_cached_results_for(:user_defined_tab_favorites)
        @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

        refresh_list_page(:except => [:results]) do |page|
          page.replace 'add_dimension_widget', :partial => "lanes/add_group_lane", :locals => { :view => @view }
          page.replace 'lane_action_container', :partial => "lanes/lane_actions", :locals => { :view => @view }
          page.replace 'color-legend-container', :partial => 'shared/color_legend'
          page.replace 'filters-panel', :partial => @view.style.filter_tabs(@view), :locals => { :view => @view }
          page.replace 'magic_card_request', :partial => 'cards/magic_card_request'
          page.replace 'set_wip_limit_form', :partial => 'cards/wip_limit_form', :locals => { :view => @view }
        end
      end
    end

  end

  def reorder
    reordered_lanes = params["new_order"].sort_by { |col, index| index.to_i }.map(&:first)

    cards_result_setup
    property_definition = @view.group_lanes.lane_property_definition
    property_definition.reorder(reordered_lanes) {|enum| enum.value}
    @project.card_types.reload if property_definition.is_a?(CardTypeDefinition)
    @view.reload_lane_order

    add_monitoring_event('column_action', 'action' => 'reorder')
    respond_to do |format|
      format.js do
        if property_definition && property_definition.errors.any?
          render :update do |page|
            flash.now[:error] = property_definition.errors.full_messages
            page.refresh_flash
          end
          return
        end
        @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

        refresh_list_page(:except => [:flash, :results]) do |page|
          page.replace 'color-legend-container', :partial => 'shared/color_legend'
          page.replace 'filters-panel', :partial => @view.style.filter_tabs(@view), :locals => { :view => @view }
          page.replace 'add_dimension_widget', :partial => "lanes/add_group_lane", :locals => { :view => @view}
          page["cta_frame_wrapper"].replace :partial => 'cards/cta_frame', :locals => {:view => @view}
        end
      end
    end
  end

  TAB_UPDATE_ACTIONS = %w(create destroy update reorder)
  def tab_update_action?
    TAB_UPDATE_ACTIONS.include?(action_name)
  end

  def identifier_from_params
    @view.groups.property_for(dimension).lane_identifier( params[dimension][:value] )
  end

  def dimension
    @dimension ||= [:lane, :row].detect do |dim|
      params[dim]
    end
  end

  def monitoring_action
    dimension == :lane ? "column_action" : "row_action"
  end
end
