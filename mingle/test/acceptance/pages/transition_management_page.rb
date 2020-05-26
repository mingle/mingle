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

module TransitionManagementPage

  def droplist_link_id_on_transition_edit_page(widget_name, property, context=nil)
    if widget_name == 'sets'
      lightbox_droplist_link_id(property)
    elsif widget_name == 'requires'
      lightbox_requires_droplist_link_id(property)
    else
      raise "Widget name #{widget_name} is not correct. It should be requires or sets."
    end
  end

  def droplist_dropdown_id_on_transition_edit_page(widget_name, property, context=nil)
    if widget_name == 'sets'
      droplist_lightbox_dropdown_id(property)
    elsif widget_name == 'requires'
      droplist_requires_lightbox_dropdown_id(property)
    else
      raise "Widget name #{widget_name} is not correct. It should be requires or sets."
    end
  end

  def droplist_option_id_on_transition_edit_page(widget_name, property, value, context= nil)
    if widget_name == 'sets'
      droplist_lightbox_option_id(property, value)
    elsif widget_name == 'requires'
      droplist_requires_lightbox_option_id(property, value)
    else
      raise "Widget name #{widget_name} is not correct. It should be requires or sets."
    end
  end

  def assert_property_set_on_transition_list_for_transtion(transition, properties)
    properties.each do |property, value|
      @browser.assert_text_present_in(transition_element_id(transition), "#{property}: #{value}")
    end
  end

  def assert_tree_property_set_on_transition_list_for_transtion(transition, properties)
    properties.each do |property, value|
      @browser.assert_text_present_in(transition_element_id(transition), "#{property} tree: #{value}")
    end
  end


  def assert_that_transitions_cannot_be_generated
    assert_element_has_css_class TransitionManagementPageId::GENERATE_WORKFLOW_TOP_ID, 'disabled'
    assert_element_has_css_class TransitionManagementPageId::GENERATE_WORKFLOW_BOTTOM_ID, 'disabled'
  end

  def assert_that_transitions_can_be_generated
    assert_element_doesnt_have_css_class TransitionManagementPageId::GENERATE_WORKFLOW_TOP_ID, 'disabled'
    assert_element_doesnt_have_css_class TransitionManagementPageId::GENERATE_WORKFLOW_BOTTOM_ID, 'disabled'
  end

  def assert_no_property_selected_on_transition_generator_page
    actual_selected = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::PROPERTY_DEFINITION_ID}').value;})
    assert_equal("", actual_selected)
  end

  def assert_no_card_type_selected_on_transition_generator_page
    actual_selected = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::CARD_TYPE_ID}').value;})
    assert_equal("", actual_selected)
  end

  def assert_order_in_card_type_drop_list_on_transtion_generator_page(expected_order, card_type)
    card_type_id = card_type.id
    card_type_order = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('#card_type_id option').indexOf(this.browserbot.getCurrentWindow().$$('#card_type_id option[value=#{card_type_id}]').first());
    })
    assert_equal(expected_order, card_type_order.to_i)
  end


  def assert_name_present_in_property_drop_list_on_transition_generator_page(property)
    property_id = property.id
    property_existing = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('##{TransitionManagementPageId::PROPERTY_DEFINITION_ID} option').indexOf(this.browserbot.getCurrentWindow().$$('##{TransitionManagementPageId::PROPERTY_DEFINITION_ID} option[value=#{property_id}]').first());
    })
    raise SeleniumCommandError.new("Property #{property.name} is NOT in current drop down list !") if property_existing.to_i == -1
  end

  def assert_name_not_present_in_property_drop_list_on_transition_generator_page(property)
    property_id = property.id
    property_existing = @browser.get_eval(%{this.browserbot.getCurrentWindow().$$('##{TransitionManagementPageId::PROPERTY_DEFINITION_ID} option').indexOf(this.browserbot.getCurrentWindow().$$('##{TransitionManagementPageId::PROPERTY_DEFINITION_ID} option[value=#{property_id}]').first());})
    raise SeleniumCommandError.new("Property #{property.name} is in current drop down list !") if property_existing.to_i == 1
  end

  def assert_property_position_in_transition_preview_page(transition_position, value_that_transition_from, value_that_transition_to)

    actual_property_value_that_transition_from = @browser.get_eval(%{this.browserbot.getCurrentWindow().$$('#transition-#{transition_position} .transition-from .property-value')[1].innerHTML;})
    actual_property_value_that_transition_to = @browser.get_eval(%{this.browserbot.getCurrentWindow().$$('#transition-#{transition_position} .transition-to .property-value')[0].innerHTML;})


    assert_equal(value_that_transition_from.to_s, actual_property_value_that_transition_from)
    assert_equal(value_that_transition_to.to_s, actual_property_value_that_transition_to)
  end

  def assert_no_transition_for_preview_message_present_on_transition_generator_page
    @browser.assert_element_present(no_transitions_presnet_id)
    @browser.assert_element_matches(no_transitions_presnet_id, /#{"There is no transition to preview because the selected property does not have any values."}/)
  end

  def assert_info_box_of_previewing_transition_workflow_present
    @browser.assert_element_present(class_locator(SharedFeatureHelperPageId::INFO_BOX))
    @browser.assert_element_matches(class_locator(SharedFeatureHelperPageId::INFO_BOX), /#{"You are previewing the transitions that are about to get generated. The transitions below will be created only if you complete the process by clicking on 'Generate transition workflow'. Also note that the listed hidden date properties will be created along with the transitions."}/)
  end

  def assert_warning_box_for_exsisting_transtions_present(exsiting_transtions_account, card_type_selected, property_selected)
    @browser.assert_element_present(class_locator(SharedFeatureHelperPageId::WARNING_BOX))
    @browser.assert_element_matches(class_locator(SharedFeatureHelperPageId::WARNING_BOX), /#{"There are already #{exsiting_transtions_account} transitions using #{card_type_selected} and #{property_selected}. Click here to view these existing transitions."}/)
  end

  def assert_transition_filter_present()
    @browser.assert_element_present(TransitionManagementPageId::CARD_TYPES_FILTER_LABEL)
    @browser.assert_element_present(TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL)
  end

  def assert_property_diabled_in_transition_filter
    assert_disabled(TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL)
  end

  def assert_property_enabled_in_transition_filter
    assert_enabled(TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL)
  end

  def assert_card_types_present_in_transition_filter_drop_list(*card_type_names)
    @browser.click(TransitionManagementPageId::CARD_TYPES_FILTER_LABEL)
    card_type_names.each do |card_type_name|
      @browser.assert_drop_down_contains_value(TransitionManagementPageId::CARD_TYPES_FILTER_LABEL, card_type_name)
    end
  end

  def assert_property_present_in_transition_filter_drop_list(property)
    flag = false
    options = @browser.get_all_drop_down_option_values(TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL)
    options.each { |option| flag = true if (option == property) }
    if !flag
      raise "Option #{property} is not present on drop down when its expected."
    end
  end

  def assert_properties_present_in_transition_filter_drop_list(*properties)
    properties.each { |property| assert_property_present_in_transition_filter_drop_list(property) }
  end

  def assert_card_type_filter_selected_with(value_selected)
    @browser.assert_value(TransitionManagementPageId::CARD_TYPES_FILTER_LABEL, value_selected)
  end


  def assert_transition_present_in_filter_result(transition)
    @browser.assert_visible(transition_element_id(transition))
  end

  def assert_transition_not_present_in_filter_result(transition)
    @browser.assert_not_visible(transition_element_id(transition))
  end

  def assert_transitions_present_in_filter_result(*transitions)
    transitions.each { |transition| assert_transition_present_in_filter_result(transition) }
  end

  def assert_order_of_transitions(*transitions)
    transitions[0...-2].each_with_index do |transition, index|
      @browser.assert_ordered(transition_element_id(transition), transition_element_id(transitions[index+1]))
    end
  end

  def assert_transition_present_for(project, transition)
    location = @browser.get_location
    project = project.identifier if project.respond_to? :identifier
    transition = Project.find_by_identifier(project).transitions.find_by_name(transition) unless transition.respond_to?(:name)
    navigate_to_transition_management_for(project) unless location =~ /projects\/#{project}\/transitions\/list/
    @browser.assert_element_present(transition_element_id(transition))
  end

  def assert_transition_not_present_for(project, transition)
    location = @browser.get_location
    navigate_to_transition_management_for(project) unless location =~ /projects\/#{project}\/transitions\/list/
    @browser.assert_element_not_present(transition_element_id(transition))
  end

  def assert_transition_not_present_on_managment_page_for(project, transition_name)
    navigate_to_transition_management_for(project)
    @browser.assert_element_does_not_match(TransitionManagementPageId::TRANSITION_PAGE_CONTENT_ID, /#{transition_name}/)
  end

  def assert_requires_property(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text property_def_with_hidden_requires_drop_link_id(property_name), property_value
    end
  end

  def assert_requires_properties_not(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text_not_present_in property_def_with_hidden_requires_drop_link_id(property_name), property_value
    end
  end

  def assert_requires_property_present(*properties)
    properties.each do |property_name|
      @browser.assert_visible(property_def_with_hidden_requires_drop_link_id(property_name))
    end
  end

  def assert_requires_property_not_present(*properties)
    properties.each do |property_name|
      begin
        @browser.assert_element_not_present(property_def_with_hidden_requires_drop_link_id(property_name))
      rescue
        @browser.assert_not_visible(property_def_with_hidden_requires_drop_link_id(property_name))
      end
    end
  end

  def assert_sets_property_present(*properties)
    properties.each do |property_name|
      @browser.assert_visible(property_def_with_hidden_sets_drop_link_id(property_name))
    end
  end

  def assert_sets_property_not_present(*properties)
    properties.each do |property_name|
      begin
        @browser.assert_element_not_present(property_def_with_hidden_sets_drop_link_id(property_name))
      rescue
        @browser.assert_not_visible(property_def_with_hidden_sets_drop_link_id(property_name))
      end
    end
  end

  def assert_sets_property(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text property_def_with_hidden_sets_drop_link_id(property_name), property_value
    end
  end

  def assert_sets_properties_not(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text_not_present_in(property_def_with_hidden_sets_drop_link_id(property_name), property_value)
    end
  end

  def assert_sets_card_type_set_to_no_change
    @browser.assert_text(TransitionManagementPageId::SETS_PROPERTIES_CARD_TYPE_ID, '(no change)')
  end

  def property_def_with_hidden(name)
    Project.current.find_property_definition_or_nil(name, :with_hidden => true)
  end

  def assert_transition_available_to_all_team_members(transition)
    @browser.assert_element_matches(transition_element_id(transition), /This transition can be used by all team members./)
  end

  def assert_order_of_properties_required_on_transition_edit(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if property != properties.last
        property = property_def_with_hidden(property)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("enumeratedpropertydefinition_#{property.id}_requires_span", "enumeratedpropertydefinition_#{next_property[index].id}_requires_span") unless property == properties.last
      end
    end
  end

  def assert_order_of_properties_sets_on_transition_edit(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if property != properties.last
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("enumeratedpropertydefinition_#{property.id}_sets_span", "enumeratedpropertydefinition_#{next_property[index].id}_sets_span") unless property == properties.last
      end
    end
  end

  def assert_order_of_required_properties_on_transition_management_show_page(properties = {})
    properties_actual = get_properties_as_one_string_with_values('from')
    properties_order = concatenate_properties_and_its_value_in_given_order(properties)
    assert_equal(properties_order, properties_actual)
  end

  def assert_order_of_sets_properties_on_transition_management_show_page(properties = {})
    properties_actual = get_properties_as_one_string_with_values('to')
    properties_order = concatenate_properties_and_its_value_in_given_order(properties)
    assert_equal(properties_order, properties_actual)
  end

  def assert_team_member_assigned_to_transition(user)
    @browser.assert_checked(css_locator("input[value='#{user.id}']"))
  end

  def assert_user_not_present_for_transition_assignment(user)
    select_only_selected_team_members_radio_button
    @browser.assert_element_not_present("input[value='#{user.id}']")
  end

  def assert_transition_assigned_to_all_team_members(transition)
    @browser.assert_element_matches(transition_element_id(transition), /This transition can be used by all team members./)
  end

  def assert_transition_assigned_to(user, transition)
    @browser.assert_element_matches(transition_element_id(transition), /#{user.name}/)
  end

  def assert_transition_not_assigned_to(user, transition)
    @browser.assert_element_does_not_match(transition_element_id(transition), /#{user.name}/)
  end

  private

  def get_properties_as_one_string_with_values(from_to)
    property_read =@browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$(\".transition-#{from_to}\").first().innerHTML.unescapeHTML()
    })
    property_read.strip_all
  end

  def concatenate_properties_and_its_value_in_given_order(properties)
    properties_order = ''
    properties.each do |property, value|
      properties_order = properties_order + property.to_s + ':' + value.to_s
    end
    properties_order.strip_all
  end

  def assert_inline_value_add_present_for_sets_during_transition_create_edit_for(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.assert_element_present(property_sets_action_adding_value(property))
  end

  def assert_inline_value_add_present_for_requires_during_transition_create_edit_for(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.assert_element_present(property_requires_action_adding_value(property))
  end

  def assert_inline_value_add_not_present_for_sets_during_transition_create_edit_for(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.assert_element_not_present(property_sets_action_adding_value(property))
  end

  def assert_inline_value_add_not_present_for_requires_during_transition_create_edit_for(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.assert_element_not_present(property_requires_action_adding_value(property))
  end

  def assert_sets_property_read_only(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.click("formulapropertydefinition_#{property.id}_sets_drop_link")
    @browser.assert_not_visible("formulapropertydefinition_#{property.id}_editor")
    assert_property_has_transition_only_css_style("formulapropertydefinition_#{property.id}_sets_edit_link")
  end

  def assert_sets_property_and_value_read_only(project, property, value)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property)
    property_type = property.attributes['type']
    if property_type == 'TreeRelationshipPropertyDefinition'
      @browser.assert_not_visible("treerelationshippropertydefinition_#{property.id}_sets_drop_link")
      @browser.assert_element_present("treerelationshippropertydefinition_#{property.id}_sets_disabled_link")
      @browser.assert_text("treerelationshippropertydefinition_#{property.id}_sets_disabled_link", value)
    else
      raise "Property type #{property_type} is not supported yet..."
    end
  end

  def assert_set_property_does_not_have_value(project, property, value)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property)
    property_type = property.attributes['type']
    if property_type == 'EnumeratedPropertyDefinition'
      @browser.click("enumeratedpropertydefinition_#{property.id}_sets_drop_link")
      @browser.assert_element_not_present("enumeratedpropertydefinition_#{property.id}_sets_option_#{value.to_s.downcase}")
    elsif property_type == 'UserPropertyDefinition'
      @browser.click("userpropertydefinition_#{property.id}_sets_drop_link")
      @browser.assert_element_not_present("userpropertydefinition_#{property.id}_sets_option_#{value.to_s.downcase}")
    else
      raise "Property type #{property_type} is not supported"
    end
  end

  def assert_set_property_does_have_value(project, property, value)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property)
    property_type = property.attributes['type']
    if property_type == 'EnumeratedPropertyDefinition'
      @browser.click("enumeratedpropertydefinition_#{property.id}_sets_drop_link")
      @browser.assert_element_present("enumeratedpropertydefinition_#{property.id}_sets_option_#{value.to_s.downcase}")
    elsif property_type == 'UserPropertyDefinition'
      @browser.click("userpropertydefinition_#{property.id}_sets_drop_link")
      @browser.assert_element_present("userpropertydefinition_#{property.id}_sets_option_#{value.to_s.downcase}")
    elsif property_type == 'TreeRelationshipPropertyDefinition'
      @browser.click("#{property.html_id}_sets_drop_link")
      if is_a_special?(value)
        @browser.assert_element_present("#{property.html_id}_sets_option_#{value.to_s.downcase}")
      else
        @browser.with_ajax_wait do
          @browser.click droplist_select_card_action("#{property.html_id}_sets_drop_down")
        end
        @browser.assert_element_matches(css_locator(".lightbox"), /#{value}/) # jem- need to make this work for both plvs and cards
      end
    else
      raise "Property type #{property_type} is not supported"
    end
  end

  def assert_requires_property_does_have_value(project, property, value)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property)
    property_type = property.attributes['type']
    if property_type == 'EnumeratedPropertyDefinition'
      @browser.click("enumeratedpropertydefinition_#{property.id}_requires_drop_link")
      @browser.assert_element_present("enumeratedpropertydefinition_#{property.id}_requires_option_#{value.to_s.downcase}")
    elsif property_type == 'UserPropertyDefinition'
      @browser.click("userpropertydefinition_#{property.id}_requires_drop_link")
      @browser.assert_element_present("userpropertydefinition_#{property.id}_requires_option_#{value.to_s.downcase}")
    elsif property_type == 'TreeRelationshipPropertyDefinition'
      @browser.click("#{property.html_id}_requires_drop_link")
      if is_a_special?(value)
        @browser.assert_element_present("#{property.html_id}_requires_option_#{value.to_s.downcase}")
      else
        @browser.with_ajax_wait do
          @browser.click droplist_select_card_action("#{property.html_id}_requires_drop_down")
        end
        @browser.assert_element_matches(css_locator(".lightbox"), /#{value}/) # jem- need to make this work for both plvs and cards
      end
    else
      raise "Property type #{property_type} is not supported"
    end
  end

  # tree option event related assertions
  def assert_select_option_label_for_transition(tree, label)
    if label != '(no change)'
      assert_equal(label, @browser.get_eval("this.browserbot.getCurrentWindow().$('tree_belonging_property_definition_#{tree.id}_sets_disabled_link').innerHTML"))
    else
      assert_equal(label, @browser.get_eval("this.browserbot.getCurrentWindow().$('tree_belonging_property_definition_#{tree.id}_sets_drop_link').innerHTML"))
    end
  end

  def assert_tree_option_widget_is_disabled_for(tree)
    @browser.assert_visible("tree_belonging_property_definition_#{tree.id}_sets_disabled_link")
    @browser.assert_not_visible("tree_belonging_property_definition_#{tree.id}_sets_drop_link")
  end

  def assert_tree_option_widget_is_enabled_for(tree)
    @browser.assert_not_visible("tree_belonging_property_definition_#{tree.id}_sets_disabled_link")
    @browser.assert_visible("tree_belonging_property_definition_#{tree.id}_sets_drop_link")
  end

  def assert_tree_options_present_on_events_for(tree, remove_options)
    @browser.click("tree_belonging_property_definition_#{tree.id}_sets_drop_link")
    @browser.wait_for_element_visible("tree_belonging_property_definition_#{tree.id}_sets_drop_down")
    remove_options.each do |remove_option|
      @browser.assert_element_present("tree_belonging_property_definition_#{tree.id}_sets_option_#{remove_option}")
    end
    @browser.click("tree_belonging_property_definition_#{tree.id}_sets_option_(no change)")
    @browser.wait_for_element_not_visible("tree_belonging_property_definition_#{tree.id}_sets_drop_down")
  end

  def assert_tree_options_not_present_on_events_for(tree, remove_option)
    @browser.assert_element_not_present("tree_belonging_property_definition_#{tree.id}_sets_option_#{remove_option}")
  end

  def assert_property_selected_on_transition_page(property)
    current_selected_property = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL}').value;})
    property_id = property.id
    raise SeleniumCommandError.new("#{property.name} is NOT selected in current filter") unless current_selected_property.to_i == property_id
  end

  def assert_no_property_seleced_on_transition_page
    current_selected_property_value = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::SHOW_WORKFLOW_FOR_LABEL}').value;})
    raise SeleniumCommandError.new("Default 'All properties' is not selected! ") unless current_selected_property_value == ""
  end

  def assert_create_transition_work_flow_link_is_not_present
    assert_link_not_present("/projects/#{@project.identifier}/transition_workflows/new")
  end

  def assert_card_type_selected_on_transition_page(card_type)
    current_selected_card_type = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::CARD_TYPES_FILTER_LABEL}').value;})
    raise SeleniumCommandError.new("#{card_type.name} is NOT selected in current filter") unless current_selected_card_type.to_i == card_type.id
  end

  def assert_no_card_type_seleced_on_transition_page
    current_selected_card_type = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('#{TransitionManagementPageId::CARD_TYPES_FILTER_LABEL}').value;})
    raise SeleniumCommandError.new("Default card type 'All' is not selected! ") unless current_selected_card_type == ""
  end

  def assert_no_transition_message_present_on_transition_page
    @browser.assert_element_present(class_locator(TransitionManagementPageId::NO_TRANSITION_MESSAGE))
    @browser.assert_element_matches(class_locator(TransitionManagementPageId::NO_TRANSITION_MESSAGE), /#{"There are currently no transitions to list. You can create a new transition or generate a new transition workflow."}/)
  end

  def assert_value_for_property_on_transition_edit_page(widget_name, property, value)
    @browser.assert_text(droplist_link_id_on_transition_edit_page(widget_name, property), value)
  end

  def assert_value_not_present_in_property_drop_down_on_transition_edit_page(widget_name, property, values)
    values.each do |value|
      locator = droplist_option_id_on_transition_edit_page(widget_name, property, value)
      @browser.is_element_present(locator) && @browser.assert_not_visible(locator)
    end
  end

  def assert_value_present_in_property_drop_down_on_transition_edit_page(widget_name, property, values)
    values.each do |value|
      locator = droplist_option_id_on_transition_edit_page(widget_name, property, value)
      @browser.assert_element_present(locator) && @browser.assert_visible(locator)
    end
  end

  def assert_property_tooltip_on_transition_edit_page(widget_name, property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property_name + ': ' + property.description
    @browser.assert_element_present("css=##{droplist_part_id(property_name, "#{widget_name}_span")} span[title='#{property_tooltip}']")
  end
end
