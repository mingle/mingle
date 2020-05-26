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

module HistoryTabAction
  def click_type_for_history_filtering(type)
    @browser.with_ajax_wait do
      @browser.click filter_types_id(type)
    end
  end

  def filter_history_using_first_condition_by(project, properties = {})
    filter_list_by(project, properties, '', "involved_filter_tags")
  end

  alias_method :filter_history_by, :filter_history_using_first_condition_by

  def filter_history_using_second_condition_by(project, properties = {})
    filter_list_by(project, properties, 'acquired', "acquired_filter_tags" )
  end

  def filter_history_by_team_member(team_member)
    @browser.with_ajax_wait do
      @browser.select(HistoryTabPageId::FILTER_USER_ID, team_member.name)
    end
  end

  def filter_history_by_no_team_member
    @browser.with_ajax_wait do
      @browser.select(HistoryTabPageId::FILTER_USER_ID, HistoryTabPageId::
      SELECT_TEAM_MEMBER_OPTION_ID)
    end
  end

  def select_card_type_in_filter_involved(type)
    @browser.click HistoryTabPageId::CARD_TYPE_NAME_DROP_LINK
    @browser.with_ajax_wait do
      @browser.click(card_type_option_id(type, nil))
    end
  end

  def select_card_type_in_filter_acquired(type)
    @browser.click HistoryTabPageId::ACQUIRED_CARD_TYPE_NAME_DROP_LINK
    @browser.with_ajax_wait do
      @browser.click acquired_card_type_option_id(type)
    end
  end

  def filter_list_by(project, properties, property_widget_name, tag_editor_widget_name)
    properties.each do |key, value|
      key == :tags ? filter_list_by_tags(value, tag_editor_widget_name) : filter_list_by_property(project, key, value, property_widget_name)
    end
  end

  def filter_list_by_property(project, property, value, widget_name = '')
    project = Project.find_by_name(project) unless project.respond_to?(:name)
    property = project.find_property_definition_or_nil(property) unless property.respond_to?(:name)
    property_type = property.attributes['type'] unless property.is_a?(CardTypeDefinition)

    @browser.click droplist_link_id(property.name, widget_name)
    if need_popup_card_selector?(property_type, value)
      @browser.with_ajax_wait do
        @browser.click droplist_select_card_action(droplist_dropdown_id(property, widget_name))
      end
      @browser.with_ajax_wait do
        @browser.click("link=#{value}")
      end
    else
      @browser.with_ajax_wait do
        @browser.click droplist_option_id(property.name, value, widget_name)
      end
    end
  end

  def filter_list_by_tags(tags, widget_name)
    raise 'No tags provided to filter by' if tags.empty?
    editor = tags_editor("#{widget_name}")
    @browser.click editor.open_edit_link_locator
    @browser.type editor.input_box_locator, tags.join(",")
    @browser.with_ajax_wait do
      @browser.click editor.add_tag_button_locator
    end
  end


  def set_history_filter_as(where_they_have_been, where_they_changed_to)
     @browser.run_once_history_generation
     navigate_to_history_for(@project)
     filter_history_using_first_condition_by(@project, where_they_have_been)
     filter_history_using_second_condition_by(@project, where_they_changed_to)
   end


   def user_filter_to_track_any_change_on(property_name, previous_value)
     navigate_to_history_for(@project)
     filter_history_using_first_condition_by(@project, property_name => previous_value)
     filter_history_using_second_condition_by(@project, property_name => '(any change)')
   end

   def user_set_filter_with_card_type_and_any_change_on_property(card_type,property_name, previous_value)
     navigate_to_history_for(@project)
     filter_history_using_first_condition_by(@project, 'Type' => card_type)
     filter_history_using_first_condition_by(@project, property_name => previous_value)
     filter_history_using_second_condition_by(@project, 'Type' => card_type)
     filter_history_using_second_condition_by(@project, property_name => '(any change)')
   end

  def existing_filter_count
    @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('.condition-container').size();
    }).to_i
  end

  def reset_existing_filters
    @browser.wait_for_all_ajax_finished
    filter_condition_containers = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('.condition-container').pluck('id');
    }).split(',')

    if filter_condition_containers.any?
      current_filter_value = @browser.get_text  HistoryTabPageId::CARD_FILTER_FIRST_VALUE_DROPLINK
      if current_filter_value != '(any)'
        @browser.with_ajax_wait do
          @browser.click HistoryTabPageId::CARD_FILTER_FIRST_OPTION_ANY
        end
      end
      filter_condition_containers.each_with_index do |filter_condition_container, index|
        next if index == 0
        @browser.with_ajax_wait do
          @browser.click card_filter_delete_id(index)
        end
      end
    end
  end

end
