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

# Tags: scenario, bug, properties, enum-property
class Scenario14StandardPropertyCrudTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'
  UPDATE_SUCCESSFUL_MESSAGE = 'Property was successfully updated.'
  NAME_ALREADY_TAKEN_MESSAGE = 'Name has already been taken'
  VALUE_ALREADY_TAKEN_MESSAGE = 'Value has already been taken'
  COLUMN_NAME_INVALID_MESSAGE = 'Column name is invalid'
  COLUMN_NAME_ALREADY_TAKEN_MESSAGE = 'Column name has already been taken'
  NAME_CANNOT_BE_BLANK = "Name can't be blank"
  
  BUG_STATUS = 'Bug Status'
  STATUS = 'status'
  PRIORITY = 'priority'
  RELEASE = 'release'
  CARD_NAME = 'testing card'
  CARD_NAME_2 = 'testing card 2'
  NEW = 'new'
  OPEN = 'open'
  HIGH = 'high'
  IN_PROGRESS = 'in progress'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_14', :admins => [users(:proj_admin)])
    @project.activate
    login_as_proj_admin_user
  end
  
  def test_cannot_create_properties_with_duplicate_names
    property_name = "dev's status"
    create_property_definition_for(@project, property_name)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    
    create_property_definition_for(@project, property_name)
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
    assert_error_message_does_not_contain(COLUMN_NAME_ALREADY_TAKEN_MESSAGE)# bug 1129
    assert_error_message_does_not_contain(COLUMN_NAME_INVALID_MESSAGE)# bug 1129
  end
  
  def test_cannot_see_properties_across_projects
    open_project(@project)
    @another_project = create_project(:prefix => 'scenario_14_other', :admins => [users(:proj_admin)])
    create_property_definition_for(@project, 'Iteration')
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@another_project, 'milestone')
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    navigate_to_property_management_page_for(@project)
    assert_property_present_on_property_management_page('Iteration')
    assert_property_not_present_on_property_management_page('milestone')
    navigate_to_property_management_page_for(@another_project)
    assert_property_present_on_property_management_page('milestone')
    assert_property_not_present_on_property_management_page('Iteration')
  end
  
  def test_cannot_create_property_with_name_with_greater_than_forty_characters
    forty_character_name = 'this is exactly forty characters long hi'
    greater_than_forty_character_name = 'food very long what high nice stop fool stuff'
    property_with_valid_name_length = create_property_definition_for(@project, forty_character_name)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, greater_than_forty_character_name) # user cannot type in value greater than 40 characters, but selenium only SEEMS like it can
    assert_property_does_not_exist(greater_than_forty_character_name) 
    assert_property_exists(property_with_valid_name_length)
  end
  
  def test_assign_card_type_while_property_creation
     new_card_type = 'task'
     setup_property_definitions(BUG_STATUS => ['new', 'asigned', 'closed'])
     create_card_type_for_project(@project, new_card_type)
     navigate_to_property_management_page_for(@project)
     open_property_for_edit(@project, BUG_STATUS)
     assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [new_card_type,'Card'] )
     select_none
     check_the_card_types_required_for_a_property(@project, :card_types => [new_card_type])
     assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [new_card_type], :card_types_unchecked => ['Card'])
     select_all
     assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [new_card_type,'Card'] )
     select_none
     assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_unchecked => [new_card_type,'Card'] )
   end
      
  # bug 920
  def test_property_creation_trims_leading_and_trailing_whitespace
    property_name = 'dev estimate'
    description = "dev's effort"
    create_property_definition_for(@project, "    #{property_name}    ", :description => "   #{description}   ")
    
    property_from_db = EnumeratedPropertyDefinition.find(:first,
      :conditions => ["project_id = ? and name = ?", @project.id, property_name])
    
    assert_equal(property_name, property_from_db.name)
    assert_equal(description, property_from_db.description)
    
    create_property_definition_for(@project, " #{property_name}           ")
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
    assert_error_message_does_not_contain(COLUMN_NAME_INVALID_MESSAGE)# bug 1129
    assert_error_message_does_not_contain(COLUMN_NAME_ALREADY_TAKEN_MESSAGE)# bug 1129
    
    # verify that additional valid properties can be created
    @browser.click_and_wait('link=Cancel')
    property_def_foo = create_property_definition_for(@project, 'foo')
    
    assert_property_exists(property_from_db)
    assert_property_exists(property_def_foo)
  end
  
  # bug 970 & 2294
  def test_cannot_create_custom_properties_with_names_that_are_used_as_predefined_card_properties
    predefined_properties = ['number', 'name', 'description', 'type', 'created by', 'modified by']
    variations_of_modified_by = ['modified-by', 'modified_by', 'modified:by']
    variations_of_created_by = ['created_by', 'created_by', 'created.by']
    predefined_properties = predefined_properties + variations_of_created_by + variations_of_modified_by
    predefined_properties.each {|predefined_property| assert_property_not_created(predefined_property)}
    predefined_properties.each {|predefined_property| assert_property_not_created(predefined_property.capitalize)}
    predefined_properties.each {|predefined_property| assert_property_not_created(predefined_property.upcase)}
  end
  
   def assert_property_not_created(property_name)
     expected_error_msg = "Name #{property_name} is a reserved property name"
     create_property_definition_for(@project, property_name)
     assert_error_message(expected_error_msg)
     navigate_to_property_management_page_for(@project)
     @browser.assert_element_does_not_match('content', /property_name/)
   end
  
   # bug 1098 & 1129
   def test_cannot_create_blank_value_for_property
     create_property_definition_for(@project, '')
     assert_error_message(NAME_CANNOT_BE_BLANK)
     assert_error_message_does_not_contain(COLUMN_NAME_ALREADY_TAKEN_MESSAGE)# bug 1129
     assert_error_message_does_not_contain(COLUMN_NAME_INVALID_MESSAGE)# bug 1129
     click_link('Cancel')
     assert_text_present("There are currently no card properties to list.")
   end
  
   # bug 1099
   def test_cancel_during_property_creation_does_not_create_property
     property_name = 'foo'
     property_description = 'foo barring'
     navigate_to_property_management_page_for(@project)
     click_link('Create new card property')
     type_property_name(property_name)
     type_property_description(property_description)
     click_link('Cancel')
     assert_current_url("/projects/#{@project.identifier}/property_definitions")
     assert_text_not_present(property_name)
     assert_text_not_present(property_description)
   end
   
   # bug 1421
   def test_creating_properties_that_only_differ_by_special_characters_do_not_break_db
     create_property_definition_for(@project, 'foo bar')
     create_property_definition_for(@project, 'foo_bar')
     assert_error_message_not_present
     assert_text_not_present(COLUMN_NAME_ALREADY_TAKEN_MESSAGE)
   end

   def test_can_delete_properties_that_do_not_have_enum_values
     property_to_be_deleted = 'type-o'
     create_managed_text_list_property(property_to_be_deleted, [])
     create_managed_text_list_property('status', ['foo'])
     navigate_to_property_management_page_for(@project)
     delete_property_for(@project, property_to_be_deleted)
     assert_notice_message("Property #{property_to_be_deleted} has been deleted.")
     assert_property_does_not_exist(property_to_be_deleted)
   end

   def test_can_delete_locked_and_hidden_properties
     locked_property = 'locked'
     enum_value_for_locked_1 = 'foo'
     enum_value_for_locked_2 = 'bar'
     hidden_property = 'hidden One'
     enum_value_for_hidden = 'foobar'
     setup_property_definitions(locked_property => [enum_value_for_locked_1, enum_value_for_locked_2], hidden_property => [enum_value_for_hidden], STATUS => ['placeholder'])
     card_with_properties = create_card!(:name => 'for testing', locked_property => enum_value_for_locked_1, hidden_property => enum_value_for_hidden)
     lock_property(@project, locked_property)
     hide_property(@project, hidden_property)

     delete_property_for(@project, locked_property)
     assert_notice_message("Property #{locked_property} has been deleted.")
     assert_property_does_not_exist(locked_property)

     delete_property_for(@project, hidden_property, :with_hidden => true)
     assert_notice_message("Property #{hidden_property} has been deleted.")
     assert_property_does_not_exist(hidden_property)

     assert_property_not_present_on_card(@project, card_with_properties, locked_property)
     assert_property_not_present_on_card(@project, card_with_properties, hidden_property)
   end
   
   # bug 1437, 1832
   def test_properties_cannot_be_created_with_invalid_characters
     invalid_characters = ['[', ']', '=', '&', '#']
     property_name_stub = 'foo'
     invalid_characters.each {|invalid_character| assert_cannot_create_property("#{property_name_stub}#{invalid_character}")}
     invalid_characters.each {|invalid_character| assert_cannot_create_property_via_excel_import("#{invalid_character}#{property_name_stub}")}
   end
   
   # bug 1583 and bug 9613
   def test_saved_view_is_deleted_when_hiding_property_in_the_saved_view_definition
     setup_property_definitions(RELEASE => [1], STATUS => [NEW, OPEN])
     create_card!(:name => CARD_NAME, RELEASE => 1)
     create_card!(:name => CARD_NAME_2, STATUS => OPEN)
     navigate_to_card_list_for(@project)
     filter_card_list_by(@project, RELEASE => 1)
     saved_view_1 = create_card_list_view_for(@project, '<h1>saved_view_1</h1>')
     reset_view
     add_column_for(@project, [STATUS])
     saved_view_2 = create_card_list_view_for(@project, 'saved_view_2')
     navigate_to_favorites_management_page_for(@project)
     toggle_tab_for_saved_view(saved_view_2)
     navigate_to_property_management_page_for(@project)
     hide_property(@project, RELEASE, :stop_at_confirmation => true)
     assert_include('<h1>saved_view_1</h1>'.escape_html, @browser.get_raw_inner_html('info-box-confirm'))
     @browser.assert_text_present("The following 1 team favorite will be deleted: #{saved_view_1.name}")
     click_hide_property_link
     hide_property(@project, STATUS, :stop_at_confirmation => true)
     @browser.assert_text_present("The following 1 tabbed view will be deleted: #{saved_view_2.name}")
     click_hide_property_link
     navigate_to_favorites_management_page_for(@project)
     @browser.assert_text_not_present(saved_view_1.name)
     @browser.assert_text_not_present(saved_view_2.name)
     assert_link_not_present(saved_view_2.name)
   end
   
   # bug 2275
   def test_edit_property_page_holds_the_changes_made_to_type_selections_when_an_invalid_name_entered
     status = 'Status'
     setup_property_definitions(status => ['NEW', 'OPEN', 'IN_PROGRESS', 'DONE', 'CLOSE'])
     setup_card_type(@project, 'story', :properties => [status])
     setup_card_type(@project, 'bug')
     card1 = create_card!(:name => 'simple card', :card_type => 'story', status =>  'NEW')
     open_property_for_edit(@project, status)
     check_the_card_types_required_for_property(@project, :types => ['bug'])
     type_property_name('new&old')
     click_save_property
     click_continue_update
     assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => ['bug'], :card_types_unchecked => ['story'])
  end
  
  # bug 2985
  def test_property_admin_label_highlights_upon_selection
    setup_property_definitions(BUG_STATUS => [])
    navigate_to_property_management_page_for(@project)
    assert_project_admin_menu_item_is_highlighted('Card properties')
  end
  
  # different situations when removing property from card type p used in F; P used in A; P used in F then used in A
  # def test_property_used_in_formula_can_not_be_updated_if_it_would_not_cause_aggregate_deletion
  #   setup_numeric_text_property_definition('p1')
  #   setup_formula_property_definition('f1', "p1") 
  #   update_property_by_removing_card_type(@project, 'p1', "Card")
  #   @browser.assert_text_present("This update will remove card type Card from formula property f1")
  # end
  
  def test_property_used_in_aggregate_can_not_be_updated_if_it_would_cause_aggregate_deletion
    a_type = setup_card_type(@project, 'type_A')
    b_type = setup_card_type(@project, 'type_B')
    setup_numeric_text_property_definition('p1').update_attributes(:card_types => [a_type, b_type])
    a_b_tree = setup_tree(@project, 'a b tree', :types => [a_type, b_type], :relationship_names => ["A"])            
    aggregate = setup_aggregate_property_definition('a1', AggregateType::SUM, @project.all_property_definitions.find_by_name('p1'), a_b_tree.id, a_type.id, b_type)
    
    update_property_by_removing_card_type(@project, 'p1', a_type.name)
    assert_error_message_not_present    
    update_property_by_removing_card_type(@project, 'p1', b_type.name)
    assert_info_message("is used as the target property of a1")
  end
  
  def test_property_name_is_case_insensitive
    create_property_definition_for(@project, 'iteration', :type  => 'number list')
    create_property_definition_for(@project, 'ITERATION', :type  => 'any number')
    assert_error_message("Name has already been taken")
    create_property_definition_for(@project, 'Iteration', :type  => 'any number')
    assert_error_message("Name has already been taken")
  end

  def test_only_one_space_is_left_between_words_in_property_name
    date_property = create_property_definition_for(@project, 'Added    to Scope on', :type  => 'Date')
    assert_property_present_on_property_management_page('Added to Scope on')
    create_property_definition_for(@project, 'Added to    Scope on', :type  => 'Date')
    assert_error_message("Name has already been taken")
  end
  
  
  # def test_property_used_in_formula_used_in_aggregate_can_not_be_updated_if_it_would_cause_aggregate_deletion
  #   get_a_R_I_S_tree_ready
  #   setup_numeric_text_property_definition('p1').update_attributes(:card_types => [@iteration_type, @story_type])
  #   setup_formula_property_definition('f1', "p1").update_attributes(:card_types => [@iteration_type, @story_type])   
  #   aggregate = setup_aggregate_property_definition('a1', AggregateType::SUM, @project.all_property_definitions.find_by_name('f1'), @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
  #   
  #   update_property_by_removing_card_type(@project, 'p1', @iteration_type.name)
  #   assert_error_message_not_present
  #   click_continue_update
  #   update_property_by_removing_card_type(@project, 'p1', @story_type.name)
  #   assert_info_message("used by aggregate property a1")   
  # end
  
  private
  def get_a_R_I_S_tree_ready
    @release_type = setup_card_type(@project, 'Release')
    @iteration_type = setup_card_type(@project, 'Iteration')
    @story_type = setup_card_type(@project, 'Story')
    @project.reload.activate
    @tree = setup_tree(@project, "Planning Tree", :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])         
  end
  
  def assert_cannot_create_property(property_name)
    @browser.open "/projects/#{@project.identifier}/property_definitions/new"
    @browser.type 'property_definition_name', property_name
    click_create_property
    assert_error_message("Name should not contain")
  end
  
  def assert_cannot_create_property_via_excel_import(property_name)
    navigate_to_card_list_for(@project)
    header_row = ['number', property_name]
    card_data = [[15, "shouldn't work"]]
    preview(excel_copy_string(header_row, card_data))
    @browser.assert_value("#{property_name.gsub(/\W/, '_')}_import_as", 'description')
  end
  
end
