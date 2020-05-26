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

module TransitionManagementAction

  def select_card_type_in_transition_filter(card_type_to_select)
    @browser.select(TransitionManagementPageId::CARD_TYPES_FILTER_LABEL, card_type_to_select)
  end

  def select_property_in_transition_filter(property_to_select)
    @browser.select(TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL, property_to_select)
  end

  def create_transition_for(project, name, options={})
    project.reload
    navigate_to_transition_management_for(project)
    click_create_new_transition_link
    fill_in_transition_values(project, name, options)
    click_create_transition
    project.transitions.find_by_name(name)
  end

  def click_create_new_transition_link
    @browser.click_and_wait(TransitionManagementPageId::CREATE_NEW_CARD_TRANSITION_LINK)
  end

  def fill_in_transition_values(project, name, options={})
    type_transition_name(name)
    set_card_type_on_transitions_page(options[:type]) unless options[:type].nil?
    set_required_properties(project, options[:required_properties]) unless options[:required_properties].nil?

    set_sets_properties(project, options[:set_properties]) unless options[:set_properties].nil?

    unless options[:for_team_members].nil?
      assign_to_team_members(options[:for_team_members])
    end

    unless options[:for_groups].nil?
      assign_to_groups(options[:for_groups])
    end

    check_the_require_to_add_comment(options[:require_comment]) unless options[:require_comment].nil?
    set_tree_option_event_for(options[:tree_option]) unless options[:tree_option].nil?
  end

  def click_create_transition
    @browser.click_and_wait(TransitionManagementPageId::CREATE_TRANSITION_TOP_BUTTON)
  end

  def edit_transition_for(project, transition, options={})
    open_transition_for_edit(project, transition)
    new_name = options[:name] || transition.name
    fill_in_transition_values(project, new_name, options)
    click_save_transition
    project.transitions.find_by_name(new_name)
  end



  def set_tree_option_event_for(tree_option)
    tree_option.each do |tree, option|
      @browser.click(tree_belonging_property_drop_link(tree))
      @browser.wait_for_element_visible(tree_belonging_property_drop_down(tree))
      if(@browser.is_element_present(tree_belonging_property_drop_down(tree)))
        @browser.with_ajax_wait do
          @browser.click(tree_belonging_property_option(tree,option))
        end
      else
        raise "Tree option event: #{option} not available on drop down"
      end
    end
  end

  def type_transition_name(name)
    @browser.type(TransitionManagementPageId::TRANSITION_NAME_FIELD, name)
  end

  def open_transition_create_page(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open("/projects/#{project}/transitions/new")
  end

  def open_transition_for_edit(project, transition)
    project = Project.find_by_name(project) unless project.respond_to? :identifier
    transition = project.transitions.find_by_name(transition) unless transition.respond_to?(:name)
    @browser.open("/projects/#{project.identifier}/transitions/edit/#{transition.id}")
  end


  def click_save_transition
    @browser.click_and_wait(TransitionManagementPageId::SAVE_TRANSITION_TOP_BUTTON)
  end

  def click_delete(transition)
    @browser.click_and_wait(delete_transition(transition))
  end

  def click_cancel_transition
    @browser.click_and_wait(TransitionManagementPageId::CANCEL_LINK)
  end

  def click_create_a_new_transition_link_on_no_transition_warning_message
    @browser.click_and_wait(TransitionManagementPageId::CREATE_NEW_CARD_TRANSITION_LINK)
  end

  def click_edit_transition(transition)
    @browser.click_and_wait(css_locator(edit_transition(transition)))
  end

  def set_card_type_on_transitions_page(type)
    @browser.click(TransitionManagementPageId::EDIT_CARD_TYPE_NAME_DROP_LINK)
    @browser.wait_for_element_visible(TransitionManagementPageId::EDIT_CARD_TYPE_NAME_DROP_DOWN)
    @browser.click(edit_card_type_name_option(type))
    @browser.wait_for_element_not_visible(TransitionManagementPageId::EDIT_CARD_TYPE_NAME_DROP_DOWN)
  end

  def set_required_properties(project, properties)
    set_properties_for(TransitionManagementPageId::REQUIRES_PROPERTY_ID, values_by_property_definition(project, properties))
  end

  def set_sets_properties(project, properties)
    set_properties_for(TransitionManagementPageId::SETS_PROPERTY_ID, values_by_property_definition(project, properties))
  end

  def set_properties_for(widget_name, properties)
    properties.each do |property, value|
      value = TransitionManagementPageId::NULL_VALUE if value.nil?
      property_type = property.attributes[TransitionManagementPageId::TYPE_PROPERTY_ID]
      if (property_type == TransitionManagementPageId::TEXT_PROPERTY_DEFINITION_HTML_ID_PREFIX || property_type == 'Numeric')
        add_value_to_any_text_numeric_or_date_property_on_transtion(property, value, widget_name)
      elsif need_popup_card_selector?(property_type, value)
        @browser.click(property_drop_link(property,widget_name))
        @browser.with_ajax_wait do
          @browser.click droplist_select_card_action(property_drop_down(property,widget_name))
        end
        @browser.click(value_link(value))
      else
        @browser.click property_drop_link(property,widget_name)
        @browser.wait_for_element_present(property_value_option(property,widget_name,value))
        @browser.click property_value_option(property,widget_name,value)
      end
    end
  end

  def assign_to_team_members(team_members)
    select_only_selected_team_members_radio_button
    team_members.each do |team_member|
      @browser.click(checkbox_to_add_team_members_to_transition(team_member))
    end
  end

  def assign_to_groups(groups)
    select_only_selected_team_members_from_selected_group_radio_button
    groups.each do |group|
      @browser.click(checkbox_to_add_groups_to_transition(group))
    end
  end

  def check_the_require_to_add_comment(require_comment)
    if require_comment == true
      @browser.click(TransitionManagementPageId::TRANSITION_REQUIRE_COMMENT_CHECKBOX)
    end
  end

  def select_only_selected_team_members_radio_button
    @browser.get_eval "this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::ONLY_SELECTED_MEMBERS_RADIO_BUTTON}').click()"
    # @browser.click(TransitionManagementPageId::ONLY_SELECTED_MEMBERS_RADIO_BUTTON)
  end

  def select_only_selected_team_members_from_selected_group_radio_button
    @browser.get_eval "this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::ONLY_SELECTED_USER_GROUPS_RADIO_BUTTON}').click()"
    # @browser.click(TransitionManagementPageId::ONLY_SELECTED_USER_GROUPS_RADIO_BUTTON)
  end

  def add_value_to_property_on_transition_sets(project, property, value)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    project.reload.with_active_project do |active_project|
      property = active_project.reload.find_property_definition(property, :with_hidden => true)
      property_type = property.attributes[TransitionManagementPageId::TYPE_PROPERTY_ID]
      if(property_type == TransitionManagementPageId::STORY_POINTS_PROPERTY_DROP_DOWN)
        add_value_to_property_on_transtion(property, value, TransitionManagementPageId::SETS_PROPERTY_ID)
      elsif(property_type == TransitionManagementPageId::DATE_PROPERTY_DEFINITION_DROP_DOWN || property_type == TransitionManagementPageId::TEXT_PROPERTY_DEFINITION_DROP_DOWN)
        add_value_to_any_text_numeric_or_date_property_on_transtion(property, value, TransitionManagementPageId::SETS_PROPERTY_ID)
      else
        raise "Property type #{property_type} is not supported"
      end
    end
  end

  def add_value_to_property_on_transition_requires(project, property, value)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    project.reload.with_active_project do |active_project|
      property = active_project.reload.find_property_definition(property, :with_hidden => true)
      property_type = property.attributes[TransitionManagementPageId::TYPE_PROPERTY_ID]
      if(property_type == TransitionManagementPageId::STORY_POINTS_PROPERTY_DROP_DOWN)
        add_value_to_property_on_transtion(property, value, 'requires')
      elsif(property_type == TransitionManagementPageId::DATE_PROPERTY_DEFINITION_DROP_DOWN || property_type == TransitionManagementPageId::TEXT_PROPERTY_DEFINITION_DROP_DOWN)
        add_value_to_any_text_numeric_or_date_property_on_transtion(property, value, TransitionManagementPageId::REQUIRES_PROPERTY_ID)
      else
        raise "Property type #{property_type} is not supported"
      end
    end
  end

  def click_create_new_transtion_workflow_link
    click_link(TransitionManagementPageId::CREATE_NEW_TRANSITION_WORKFLOW_BUTTON)
  end

  def select_value_in_drop_down_for_property_on_transition_edit_page(widget_name,property,value)
    @browser.with_ajax_wait do
      value = TransitionManagementPageId::NULL_VALUE if value.nil?
      @browser.click droplist_option_id_on_transition_edit_page(widget_name,property,value)
    end
  end

  def click_property_on_transition_edit_page(widget_name,property)
    @browser.click droplist_link_id_on_transition_edit_page(widget_name, property, context=nil)
  end

  def type_keyword_to_search_value_for_property_on_transition_edit_page(widget_name, property, keyword)
    @browser.type_in_property_search_filter("css=##{droplist_dropdown_id_on_transition_edit_page(widget_name, property)} .dropdown-options-filter", keyword)
  end

  def navigate_to_transition_management_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/transitions/list"
  end

  def select_card_type_for_transtion_work_flow(card_type)
     @browser.select(TransitionManagementPageId::CARD_TYPE_ID, card_type)
     @browser.wait_for_all_ajax_finished
   end

   def select_property_for_transtion_work_flow(property_name)
     while !@browser.is_element_present('transition-0')  do
       @browser.select(TransitionManagementPageId::PROPERTY_DEFINITION_ID, "Select...")
       @browser.select(TransitionManagementPageId::PROPERTY_DEFINITION_ID, property_name)
       @browser.wait_for_all_ajax_finished
     end
     @browser.wait_for_element_present(class_locator('info-box'))
   end


   def select_property_for_transtion_work_flow_for_no_transition_scenario(property_name)
     @browser.select(TransitionManagementPageId::PROPERTY_DEFINITION_ID, property_name)
     @browser.wait_for_all_ajax_finished
   end

   def click_the_generate_transition_workflow_link
     @browser.click_and_wait(TransitionManagementPageId::GENERATE_TRANSITION_WORKFLOW_LINK)
   end


end
