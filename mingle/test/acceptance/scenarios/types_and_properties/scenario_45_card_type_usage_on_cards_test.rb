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

# Tags: scenario, project, card-type, cards, properties, 2521
class Scenario45CardTypeUsageOnCardsTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access
  
  PRIORITY = 'priority'
  HIGH = 'high'
  LOW = 'low'
  SIZE = 'Size'
  HAS_NO_TYPE = 'no type'
  TYPE = 'Type'
  CARD = 'Card'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_45', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => [HIGH, LOW], SIZE => [1, 2, 4])
    login_as_proj_admin_user
    open_project(@project)
  end
  
  def test_only_properties_associated_to_specific_type_should_be_shown_on_card_show
    user_property_name = 'owner'
    story = 'Story'
    defect = 'DEFECT'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    setup_card_type(@project, story, :properties => [SIZE, user_property_name])
    setup_card_type(@project, defect, :properties => [PRIORITY])
    
    defect_card = create_card!(:name => 'testing', :card_type => defect)
    open_card(@project, defect_card.number)
    assert_property_not_present_on_card_show(user_property_name)
    assert_card_type_set_on_card_show(defect)
    assert_property_not_set_on_card_show(PRIORITY)
  end

  # bug 2521
  def test_only_properties_not_associated_to_any_card_types_should_be_shown_on_card_edit
    defect = 'DEFECT'
    create_property_definition_for(@project, HAS_NO_TYPE, :types => [])
    setup_card_type(@project, defect, :properties => [PRIORITY])

    defect_card = create_card!(:name => 'testing', :card_type => defect)
    open_card_for_edit(@project, defect_card.number)
    assert_property_not_present_on_card_edit(HAS_NO_TYPE)
    assert_property_not_set_on_card_edit(PRIORITY)
  end

  def test_only_properties_not_associated_to_any_card_types_should_be_shown_on_card_show
    defect = 'DEFECT'
    create_property_definition_for(@project, HAS_NO_TYPE, :types => [])
    setup_card_type(@project, defect, :properties => [PRIORITY])
  
    defect_card = create_card!(:name => 'testing', :card_type => defect)
    open_card(@project, defect_card.number)
    assert_property_not_present_on_card_show(HAS_NO_TYPE)
    assert_property_not_set_on_card_show(PRIORITY)
  end
  
  def test_property_added_to_existing_card_type_appears_on_card
    bug = 'B U G'
    setup_card_type(@project, bug)
    bug_card = create_card!(:name => 'more tests', :card_type => bug)
    
    edit_card_type_for_project(@project, bug, :properties => [PRIORITY])
    open_card(@project, bug_card.number)
    assert_property_present_on_card_show(PRIORITY)
    assert_property_not_present_on_card_show(SIZE)
    assert_history_for(:card, bug_card.number).version(2).not_present
  end
  
  def test_renaming_card_type_updates_existing_card
    card_type_name = 'rusk'
    new_card_type_name = 'RISK'
    setup_card_type(@project, card_type_name, :properties => [PRIORITY, SIZE])
    card = create_card!(:name => 'testing rename', :card_type => card_type_name, PRIORITY => LOW, SIZE => 2)
    open_card(@project, card.number)
    assert_card_type_set_on_card_show(card_type_name)
    
    edit_card_type_for_project(@project, card_type_name, :new_card_type_name => new_card_type_name)
    open_card(@project, card.number)
    assert_card_type_set_on_card_show(new_card_type_name)
    assert_properties_set_on_card_show(PRIORITY => LOW, SIZE => '2')
    assert_history_for(:card, card.number).version(2).not_present
  end
  
  def test_changing_card_type_on_card_show_updates_history_and_property_panel
    task = 'task'
    story = 'story'
    setup_card_type(@project, task, :properties => [SIZE])
    setup_card_type(@project, story, :properties => [PRIORITY])
    card = create_card!(:name => 'story for testing', :card_type => story)
    open_card(@project, card.number)
    assert_property_present_on_card_show(PRIORITY)
    assert_property_not_present_on_card_show(SIZE)
    
    set_card_type_on_card_show(task)
    assert_property_present_on_card_show(SIZE)
    assert_property_not_present_on_card_show(PRIORITY)
    assert_history_for(:card, card.number).version(2).shows(:changed => 'Type', :from => story, :to => task)
  end
  
  def test_can_not_edit_card_type_on_card_when_viewing_old_versions
    risk = 'RISK'
    setup_card_type(@project, risk, :properties => [PRIORITY, SIZE])
    card = create_card!(:name => 'testing rename', :card_type => risk) #version 1
    open_card(@project, card.number)
    edit_card(:name => 'creating version 2')
    open_card_version(@project, card.number, 1)
    assert_card_type_not_editable_on_card_show
  end
  
  def test_changing_card_types_in_card_edit_mode_maintains_shared_property_values_until_save
    story = 'story'
    bug = 'bug'
    setup_card_type(@project, story, :properties => [PRIORITY, SIZE])
    setup_card_type(@project, bug, :properties => [PRIORITY])
    card = create_card!(:name => 'testing', :card_type => bug)
    
    open_card_for_edit(@project, card.number)
    set_properties_in_card_edit(TYPE => story)
    set_properties_in_card_edit(SIZE => 4)
    set_properties_in_card_edit(PRIORITY => HIGH)
    assert_properties_set_on_card_edit(PRIORITY => HIGH)
    
    set_properties_in_card_edit(TYPE => bug)
    assert_property_not_present_on_card_edit(SIZE)
    assert_properties_set_on_card_edit(PRIORITY => HIGH)    
    save_card
    
    assert_property_not_present_on_card(@project, card, SIZE)
    assert_properties_set_on_card_show(PRIORITY => HIGH)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {PRIORITY => HIGH})
    assert_history_for(:card, card.number).version(2).does_not_show(:set_properties => {SIZE => 4})
    assert_history_for(:card, card.number).version(3).not_present
  end
  
  def test_can_create_card_types_that_contain_apostrophe_or_single_quotes
    name_with_apostrophe = "jen's"
    name_with_single_quotes = "'foo'"
    navigate_to_card_type_management_for(@project)
    
    create_card_type_for_project(@project, name_with_apostrophe)
    assert_notice_message("Card Type #{name_with_apostrophe} was successfully created")
    
    create_card_type_for_project(@project, name_with_single_quotes)
    assert_notice_message("Card Type #{name_with_single_quotes} was successfully created")
  end
  
  # bug 3188
  def test_removing_property_association_to_type_generates_system_comment
    story = 'story'
    setup_card_type(@project, story, :properties => [PRIORITY])
    card_with_priority_set = create_card!(:name => 'for testing', :card_type => story, PRIORITY => HIGH)
    card_without_priority_set = create_card!(:name => 'for testing', :card_type => story)
    open_edit_card_type_page(@project, story)
    uncheck_properties_required_for_card_type(@project, [PRIORITY])
    save_card_type
    click_continue_to_update
    @browser.run_once_history_generation
    open_card(@project, card_without_priority_set)
    assert_property_not_present_on_card(@project, card_with_priority_set, PRIORITY)
    assert_history_for(:card, card_with_priority_set.number).version(2).shows(:property_removed => PRIORITY, :from_card_type => story)
    open_card(@project, card_without_priority_set)
    assert_property_not_present_on_card(@project, card_without_priority_set, PRIORITY)
    assert_history_for(:card, card_without_priority_set.number).version(1).does_not_show(:property_removed => PRIORITY, :from_card_type => story)
    assert_history_for(:card, card_without_priority_set.number).version(2).not_present
  end
  
  # bug 3676
  def test_deleting_card_type_that_was_once_set_to_card_can_be_deleted_and_is_still_present_on_cards_history
    story = 'story'
    setup_card_type(@project, story)
    card = create_card!(:name => 'for testing', :card_type => story)
    open_card(@project, card)
    set_card_type_on_card_show(CARD)
    delete_card_type(@project, story)
    @browser.run_once_history_generation
    open_card(@project, card)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {TYPE => story})
    assert_history_for(:card, card.number).version(2).shows(:changed => TYPE, :from => story, :to => CARD)
  end
  
  # bug 4623
  def test_card_type_having_quote_in_its_name_does_not_fail_saving_card_from_card_edit_mode
    type_with_quote = "It's card type"
    setup_card_type(@project, type_with_quote, :properties => [PRIORITY])
    card = create_card!(:name => 'for testing', :card_type => type_with_quote)
    open_card_for_edit(@project, card.number)
    set_properties_in_card_edit(PRIORITY => HIGH)
    save_card
    assert_notice_message("Card ##{card.number} was successfully updated.")
    assert_card_type_set_on_card_show(type_with_quote)
    assert_properties_set_on_card_show(PRIORITY => HIGH)
  end
end
