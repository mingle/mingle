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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')  

# Tags: scenario, properties, enum-property, cards
class Scenario33RenamingPropertiesAndEnumerationValuesTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access   
  
  
  UPDATE_SUCCESSFUL_MESSAGE = 'Property was successfully updated.'
  NAME_ALREADY_TAKEN_MESSAGE = 'Name has already been taken'
  VALUE_ALREADY_TAKEN_MESSAGE = 'Value has already been taken'
  STATUS = 'status'
  NEW = 'new'
  IN_PROGRESS = 'in progress'
  
  PRIORITY = 'priority'
  MED_TO_HIGH = 'medToHigh'
  
  NEW_NAME_FOR_STATUS = 'where is it?'
  NEW_NAME_FOR_IN_PROGRESS = 'TBD'
  NEW_NAME_FOR_MED_TO_HIGH = 'tested & approved'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)    
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_33', :users => [users(:admin)])
    setup_property_definitions(:status => [NEW, IN_PROGRESS], :priority => [MED_TO_HIGH])
    @project.find_property_definition('status').update_attribute(:name, 'status')
    @project.find_enumeration_value('status', 'in progress').update_attribute(:color, "#0059bf")
    login_as_admin_user
  end
  
  def test_cannot_update_property_by_changing_name_to_another_existing_property
    feature_property_name = 'feature'
    setup_property_definitions(feature_property_name => ['wiki'])
    card_with_status_set = create_card!(:name => 'card that has status set', STATUS => NEW)
    open_property_for_edit(@project, STATUS)
    type_property_name(feature_property_name)
    click_save_property
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
    @browser.run_once_history_generation
    open_card(@project, card_with_status_set.number)
    assert_history_for(:card, card_with_status_set.number).version(1).shows(:set_properties => {STATUS => NEW})
    assert_history_for(:card, card_with_status_set.number).version(1).does_not_show(:set_properties => {feature_property_name => NEW})
    assert_history_for(:card, card_with_status_set.number).version(2).not_present
  end
  
  def test_cannot_update_property_by_changing_name_to_another_existing_property_despite_case
    feature_property_name = 'feature'
    feature_property_name_upcased = feature_property_name.upcase
    setup_property_definitions(feature_property_name => ['wiki'])
    card_with_status_set = create_card!(:name => 'card that has status set', STATUS => NEW)
    open_property_for_edit(@project, STATUS)
    type_property_name(feature_property_name_upcased)
    click_save_property
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
    @browser.run_once_history_generation
    open_card(@project, card_with_status_set.number)
    assert_history_for(:card, card_with_status_set.number).version(1).shows(:set_properties => {STATUS => NEW})
    assert_history_for(:card, card_with_status_set.number).version(1).does_not_show(:set_properties => {feature_property_name_upcased => NEW})
    assert_history_for(:card, card_with_status_set.number).version(2).not_present
  end
  
  def test_cannot_update_property_value_by_changing_value_name_to_another_existing_value_for_that_property
    feature = 'feature'
    rss = 'rss'
    atom = 'atom'
    atom_upcased = atom.upcase
    setup_property_definitions(feature => [rss, atom])
    card_with_rss_set = create_card!(:name => 'card with rss set', feature => rss)
    open_edit_enumeration_values_list_for(@project, feature)
    edit_enumeration_value_from_edit_page(@project, feature, rss, atom_upcased)
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)
    @browser.run_once_history_generation
    open_card(@project, card_with_rss_set.number)
    assert_history_for(:card, card_with_rss_set.number).version(1).shows(:set_properties => {feature => rss})
    assert_history_for(:card, card_with_rss_set.number).version(1).does_not_show(:set_properties => {feature => atom_upcased})
    assert_history_for(:card, card_with_rss_set.number).version(2).not_present
  end
  
  def test_cannot_update_property_value_by_changing_value_name_to_another_existing_value_for_that_property_despite_case
    feature = 'feature'
    rss = 'rss'
    atom = 'atom'
    setup_property_definitions(feature => [rss, atom])
    card_with_rss_set = create_card!(:name => 'card with rss set', feature => rss)
    open_edit_enumeration_values_list_for(@project, feature)
    edit_enumeration_value_from_edit_page(@project, feature, rss, atom)
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)
    @browser.run_once_history_generation
    open_card(@project, card_with_rss_set.number)
    assert_history_for(:card, card_with_rss_set.number).version(1).shows(:set_properties => {feature => rss})
    assert_history_for(:card, card_with_rss_set.number).version(1).does_not_show(:set_properties => {feature => atom})
    assert_history_for(:card, card_with_rss_set.number).version(2).not_present
  end
  
  # bug 1214
  def test_renaming_property_also_renames_property_in_past_history_events
    property_definition_name = 'feeture'
    new_property_definition_name = 'Feature'
    enum_value_name = 'cards'
    setup_property_definitions(property_definition_name => [enum_value_name])
    card_using_property = create_card!(:name => 'testing rename', property_definition_name => enum_value_name)
    @browser.run_once_history_generation
    open_card(@project, card_using_property.number)
    assert_history_for(:card, card_using_property.number).version(1).shows(:set_properties => {property_definition_name => enum_value_name})
 
    edit_property_definition_for(@project, property_definition_name, :new_property_name => new_property_definition_name)
    @browser.run_once_history_generation
    open_card(@project, card_using_property.number)
    assert_history_for(:card, card_using_property.number).version(1).shows(:set_properties => {new_property_definition_name => enum_value_name})
  end
  
  # bug 1214
  def test_renaming_enum_value_also_renames_enum_value_in_past_history_events
    enum_value_name = 'cards and pages'
    new_enum_value_name = 'CARDS'
    property_definition_name = 'Feature'
    setup_property_definitions(property_definition_name => [enum_value_name])
    card_with_enum_set = create_card!(:name => 'testing rename', property_definition_name => enum_value_name)
    @browser.run_once_history_generation
    open_card(@project, card_with_enum_set.number)
    assert_history_for(:card, card_with_enum_set.number).version(1).shows(:set_properties => {property_definition_name => enum_value_name})
    
    edit_enumeration_value_for(@project, property_definition_name, enum_value_name, new_enum_value_name)
    @browser.run_once_history_generation
    open_card(@project, card_with_enum_set.number)
    assert_history_for(:card, card_with_enum_set.number).version(1).shows(:set_properties => {property_definition_name => new_enum_value_name})
  end
  
  # this test will test order of two properties in filter, and the property name will be changed, so the order of objects in 
  # the Hash is different between cruby and jruby.
  # so we should always use Array to specify what's order we need
  def test_renaming_property_and_enums_updates_throughout_project
    card_without_properties  = create_card!(:name => 'plain card') 
    card_with_properties_set  = create_card!(:name => 'card for transitioning', :status => IN_PROGRESS, :priority => MED_TO_HIGH)
    transition = create_transition_for(@project, 'downgrade', :required_properties => {:status => IN_PROGRESS}, :set_properties => {:priority => MED_TO_HIGH})
    
    list_saved_view = 'testing - list'
    create_list_saved_view(list_saved_view, :columns => [STATUS, PRIORITY], :filter_by => [[STATUS, IN_PROGRESS], [PRIORITY, MED_TO_HIGH]], :sort_by => STATUS)
    
    grid_saved_view = 'testing - grid'
    remove_column_for @project, [STATUS, PRIORITY]
    create_grid_saved_view(grid_saved_view, :group_by => STATUS, :color_by => PRIORITY)
    
    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, 'status', :new_property_name => NEW_NAME_FOR_STATUS, :description => 'card status')
    edit_enumeration_value_for(@project, NEW_NAME_FOR_STATUS, IN_PROGRESS, NEW_NAME_FOR_IN_PROGRESS)
    @browser.click_and_wait('link=Up')
    edit_enumeration_value_for(@project, PRIORITY, MED_TO_HIGH, NEW_NAME_FOR_MED_TO_HIGH)
    @browser.run_once_history_generation
    
    assert_existing_transtion_updates(transition)
    assert_updated_transition_still_appears_on_correct_card(card_with_properties_set, transition)
    assert_updated_transition_still_does_not_appear_for_inappropriate_card(card_without_properties, transition)
    assert_properties_on_card_updated(card_with_properties_set)
    assert_properties_in_card_history_events_updated(card_with_properties_set)
    assert_properties_in_global_history_events_and_filters_updated(card_with_properties_set)
    assert_bulk_edit_property_widget_updated
    assert_properties_in_add_remove_widget_updated
    assert_existing_list_saved_view_still_works(list_saved_view)
    assert_existing_grid_saved_view_still_works(grid_saved_view)
  end
  
  def create_list_saved_view(view_name, options)
    click_all_tab
    add_column_for(@project, options[:columns])
    filter_card_list_by(@project, options[:filter_by])
    sort_by(options[:sort_by])
    create_card_list_view_for(@project, view_name)
  end
  
  def create_grid_saved_view(view_name, options)
    switch_to_grid_view
    group_columns_by(options[:group_by])
    color_by(options[:color_by])
    create_card_list_view_for(@project, view_name)
    reset_all_filters_return_to_all_tab
  end
  
  # bug 1166
  def assert_existing_transtion_updates(transition)
    @browser.open("/projects/#{@project.identifier}/transitions/edit/#{transition.id}")
    assert_requires_property(:"where is it?" => NEW_NAME_FOR_IN_PROGRESS, :priority => '(any)')
    assert_sets_property(:priority => NEW_NAME_FOR_MED_TO_HIGH, :"where is it?" => '(no change)')
  end
  
  def assert_updated_transition_still_appears_on_correct_card(card, transition)
    open_card(@project, card.number)
    @browser.assert_element_present("transition_#{transition.id}")
  end
  
  def assert_updated_transition_still_does_not_appear_for_inappropriate_card(card, transition)
    open_card(@project, card.number)
    @browser.assert_element_not_present("transition_#{transition.id}")
  end
  
  def assert_properties_on_card_updated(card)
    open_card(@project, card.number)
    assert_properties_set_on_card_show(:"where is it?" => NEW_NAME_FOR_IN_PROGRESS, :priority => NEW_NAME_FOR_MED_TO_HIGH)
    click_edit_link_on_card
    assert_properties_set_on_card_edit(:"where is it?" => NEW_NAME_FOR_IN_PROGRESS, :priority => NEW_NAME_FOR_MED_TO_HIGH)
  end
  
  def assert_properties_in_card_history_events_updated(card)
    open_card(@project, card.number)
    load_card_history
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {:priority => NEW_NAME_FOR_MED_TO_HIGH, :"where is it?" => NEW_NAME_FOR_IN_PROGRESS})
    assert_history_for(:card, card.number).version(2).not_present ## asserting rename does not create a new version
  end
  
  def assert_properties_in_global_history_events_and_filters_updated(card)
    any = '(any)'
    navigate_to_history_for(@project)
    assert_properties_in_first_filter_widget({NEW_NAME_FOR_STATUS => any, PRIORITY => any})
    assert_properties_in_second_filter_widget({NEW_NAME_FOR_STATUS => any, PRIORITY => any})
    filter_history_using_first_condition_by(@project, NEW_NAME_FOR_STATUS => NEW_NAME_FOR_IN_PROGRESS)
    filter_history_using_first_condition_by(@project, PRIORITY => NEW_NAME_FOR_MED_TO_HIGH)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {:priority => NEW_NAME_FOR_MED_TO_HIGH, :"where is it?" => NEW_NAME_FOR_IN_PROGRESS})
  end
  
  def assert_bulk_edit_property_widget_updated
    click_all_tab
    filter_card_list_by(@project, {NEW_NAME_FOR_STATUS => NEW_NAME_FOR_IN_PROGRESS})
    select_all
    click_edit_properties_button
    assert_properties_set_in_bulk_edit_panel(@project,{NEW_NAME_FOR_STATUS => NEW_NAME_FOR_IN_PROGRESS, PRIORITY => NEW_NAME_FOR_MED_TO_HIGH})
  end

  def assert_properties_in_add_remove_widget_updated
    click_all_tab
    reset_all_filters_return_to_all_tab
    @browser.click 'link=Add / remove columns'
    @browser.assert_element_matches('column-selector', /#{NEW_NAME_FOR_STATUS}/)
    @browser.assert_element_does_not_match('column-selector', /#{STATUS}/)
  end
  
  def assert_existing_list_saved_view_still_works(view_name)
    click_all_tab
    @browser.click_and_wait("link=#{view_name}")
    assert_column_present_for(PRIORITY)
    assert_column_present_for(NEW_NAME_FOR_STATUS, PRIORITY) #bug 1211
    assert_column_not_present_for(STATUS)
    assert_properties_present_on_card_list_filter([[NEW_NAME_FOR_STATUS, NEW_NAME_FOR_IN_PROGRESS], [PRIORITY, NEW_NAME_FOR_MED_TO_HIGH]])
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', PRIORITY, NEW_NAME_FOR_STATUS], 1, 1)
    cards.assert_ascending(NEW_NAME_FOR_STATUS)
  end

  def assert_existing_grid_saved_view_still_works(view_name)
    click_all_tab
    @browser.click_and_wait("link=#{view_name}")
    assert_properties_present_on_card_list_filter([[NEW_NAME_FOR_STATUS, NEW_NAME_FOR_IN_PROGRESS], [PRIORITY, NEW_NAME_FOR_MED_TO_HIGH]])
    # bug 1211
    @browser.assert_text(group_by_columns_drop_link_id, NEW_NAME_FOR_STATUS)
    @browser.assert_text(color_by_drop_link_id, PRIORITY)
  end
  
  def test_renaming_property_and_enum_does_not_affect_different_project
    decoy_project = create_project(:prefix => 'decoy_scenario_33', :users => [users(:admin)])
    setup_property_definitions(:status => [NEW, IN_PROGRESS], :priority => [MED_TO_HIGH])
    decoy_card  = create_card!(:name => 'decoy card', :status => NEW, :priority => MED_TO_HIGH)
    decoy_project.deactivate
    
    # todo : also test transitions and existing history  (card or global -- not both) in decoy project 
    @project.activate
    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, 'status', :new_property_name => 'Age')
    edit_enumeration_value_for(@project, PRIORITY, MED_TO_HIGH, 'medium')
    @browser.run_once_history_generation
    decoy_project.activate
    decoy_card.reload
    assert_equal(NEW, decoy_card.cp_status)
    assert_equal(NEW, decoy_card.versions[0].cp_status)
    assert_equal(NEW, decoy_card.versions[0].changes.detect{|change| change.field == STATUS}.new_value)
    assert_equal(MED_TO_HIGH, decoy_card.cp_priority)
    assert_equal(MED_TO_HIGH, decoy_card.versions[0].cp_priority)
    assert_equal(MED_TO_HIGH, decoy_card.versions[0].changes.detect{|change| change.field == PRIORITY}.new_value)
  end
  
  # bug 2743
  def test_can_rename_property_by_only_changing_its_case
    all_upper_case_status = 'STATUS'
    property_defintion = edit_property_definition_for(@project, STATUS, :new_property_name => all_upper_case_status)
    @browser.assert_text_not_present(NAME_ALREADY_TAKEN_MESSAGE)
    assert_error_message_not_present
    assert_notice_message(UPDATE_SUCCESSFUL_MESSAGE)
    assert_property_does_not_exist(STATUS)
    assert_property_exists(property_defintion)
  end
  
  # bug 656
  def test_enumeration_values_auto_sorted_in_nature_order_and_show_correctly_in_pseduo_drop_down
    create_property_definition_for(@project, 'feature')
    create_enumeration_value_for(@project, 'feature', 'zzzzs')
    create_enumeration_value_for(@project, 'feature', 'apple')
    create_enumeration_value_for(@project, 'feature', 'bee')

    @browser.assert_ordered enumeration_html_id('feature', 'apple'), enumeration_html_id('feature', 'bee')
    @browser.assert_ordered enumeration_html_id('feature', 'bee'), enumeration_html_id('feature', 'zzzzs')

    edit_enumeration_value_for(@project, 'feature', 'apple', 'vat')

    @browser.assert_ordered enumeration_html_id('feature', 'bee'), enumeration_html_id('feature', 'vat')
    @browser.assert_ordered enumeration_html_id('feature', 'vat'), enumeration_html_id('feature', 'zzzzs')
    @browser.open "/projects/#{@project.identifier}/cards/new"
    assert_properties_in_order(@project, 'feature', %w{bee vat zzzzs})
  end
  
  def enumeration_html_id(property_name, enumeration_value)
    prop_def = @project.reload.find_property_definition(property_name)
    enum_value = prop_def.find_enumeration_value(enumeration_value)
    "#{enum_value.class.to_s.underscore}_#{enum_value.id}"
  end
end
