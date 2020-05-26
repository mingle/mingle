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

# Tags: numeric-properties
class Scenario63NumericPropertiesCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_63', :users => [users(:longbob)], :admins => [users(:proj_admin)])
    login_as_proj_admin_user
    navigate_to_property_management_page_for(@project)# check if this is necessary?, also, need to check , updating property value then the card show, transition, filter status in favorites.. behavior
  end
  
  def test_should_be_able_to_create_managed_number_property
    size_property = create_property_definition_for(@project, 'Size', :type => 'number list')
    assert_properties_exist(size_property)
  end
  
  def test_should_be_able_to_create_any_number_property
    iteration_property = create_property_definition_for(@project, 'Iteration', :type => 'any number')
    assert_properties_exist(iteration_property)    
  end
    
  def test_add_values_for_managed_number_list_property
    values = ['1', '4.0', '5.0']
    size_property = setup_managed_number_list_definition('Size', ['2'])
    
    values.each do |value|
      create_enumeration_value_for(@project, size_property, value)
      assert_enum_value_present_on_enum_management_page(value)
    end
  end
  
  def test_order_of_numeric_values_always_ascending_order
    valid_numeric_values = ['1', '3', '1.5', '100',  '4.0', '7.5',  '0', '-1']
    size_property = setup_managed_number_list_definition('Size',[])
    valid_numeric_values.each {|value|create_enumeration_value_for(@project, size_property, value)}
    assert_enumerated_values_order_in_propertys_edit_page(@project, size_property, ['-1', '0', '1', '1.5', '3', '4.0', '7.5', '100'])

    edit_enumeration_value_from_edit_page(@project, 'Size', '100', '5.5')
    assert_enumerated_values_order_in_propertys_edit_page(@project, size_property, ['-1', '0', '1', '1.5', '3', '4.0', '5.5', '7.5'])
  end

  def test_managed_number_properties_will_take_only_numeric_values_during_creation
    non_numeric_values = ['one', '2341D', 'c1', '#1', '.01a', '!1Xy.02']
    size_property = setup_managed_number_list_definition('Size',[])
    
    non_numeric_values.each do |value|
      create_enumeration_value_for(@project, size_property, value)
      assert_error_message("Value #{value} is an invalid numeric value")
     end
  end
  
  def test_cannot_add_duplicate_value_for_managed_number_property
    duplicate_values = ['1.0', '1.00', '01.00', '1.000', '00', '01.50']
    size_property = setup_managed_number_list_definition('Size',['1', '0', '1.5'])

    for_postgresql do
      duplicate_values.each do |value|
        create_enumeration_value_for(@project, size_property, value)
        assert_error_message('Value has already been taken')
       end
    end
  end
      
  def test_edit_value_for_managed_number_property
    size_property = setup_managed_number_list_definition('Size', ['1', '5'])

    open_edit_enumeration_values_list_for(@project, 'Size')
    edit_enumeration_value_from_edit_page(@project, 'Size', '5', '5.5')
    assert_enum_value_present_on_enum_management_page('5.5')
    edit_enumeration_value_from_edit_page(@project, 'Size', '1', '10')
    assert_enum_value_present_on_enum_management_page('10')
  end
  
  def test_can_not_edit_value_to_existing_value
    duplicate_values = ['4.0', '00']
    setup_managed_number_list_definition('Size', ['1', '4', '0'])

    open_edit_enumeration_values_list_for(@project, 'Size')
    duplicate_values.each do |value|
      edit_enumeration_value_from_edit_page(@project, 'Size', '1', value)
      assert_error_message('Value has already been taken')
      assert_enum_value_present_on_enum_management_page('1', '4', '0')
    end
  end

  def test_can_not_edit_value_to_non_numeric_value
    non_numeric_values = ['one', '#1', '.01a', '.a01', '1a']  
    setup_managed_number_list_definition('Size', ['1', '4', '0'])

    open_edit_enumeration_values_list_for(@project, 'Size')    
    non_numeric_values.each do |value|
      edit_enumeration_value_from_edit_page(@project, 'Size', '1', value)
      assert_error_message("Value #{value} is an invalid numeric value")
      assert_enum_value_present_on_enum_management_page('1', '4', '0')
    end
  end
  
  def test_managed_number_properties_can_be_locked_and_unlocked
    setup_managed_number_list_definition('Size', ['1', '4', '0'])
    navigate_to_property_management_page_for(@project)

    assert_lock_check_box_enabled_for(@project, 'Size')
    lock_property(@project, 'Size')
    assert_locked_for(@project, 'Size')
    unlock_property(@project, 'Size')
    assert_unlocked_for(@project, 'Size')
  end
  
  def test_managed_number_property_can_be_hidden_and_unhidden
    setup_managed_number_list_definition('Size',[])
    navigate_to_property_management_page_for(@project)
    assert_hide_check_box_enabled_for(@project, 'Size')
    
    hide_property(@project, 'Size')
    assert_hidden_is_checked_for(@project, 'Size')
    show_hidden_property(@project, 'Size')
    assert_hidden_is_not_checked_for(@project, 'Size')
  end

  def test_any_number_property_can_be_hidden_and_unhidden
    setup_allow_any_number_property_definition('Iteration')
    
    navigate_to_property_management_page_for(@project)
    assert_hide_check_box_enabled_for(@project, 'Iteration')
    
    hide_property(@project, 'Iteration')
    assert_hidden_is_checked_for(@project, 'Iteration')
    show_hidden_property(@project, 'Iteration')
    assert_hidden_is_not_checked_for(@project, 'Iteration')
  end

  def test_managed_number_property_can_be_set_to_transition_only
    setup_managed_number_list_definition('Size',[])
    
    navigate_to_property_management_page_for(@project)
    assert_transition_only_check_box_enabled(@project, 'Size')
    
    make_property_transition_only_for(@project, 'Size')
    assert_transition_only_is_checked_for(@project, 'Size')
    
    make_property_not_transition_only_for(@project, 'Size')
    assert_transition_only_is_not_checked_for(@project, 'Size')    
  end
  
  def test_any_number_property_can_be_set_to_transition_only
    setup_allow_any_number_property_definition('Iteration')
    
    navigate_to_property_management_page_for(@project)
    assert_transition_only_check_box_enabled(@project, 'Iteration')
    
    make_property_transition_only_for(@project, 'Iteration')
    assert_transition_only_is_checked_for(@project, 'Iteration')
    
    make_property_not_transition_only_for(@project, 'Iteration')
    assert_transition_only_is_not_checked_for(@project, 'Iteration')    
  end
  
  def test_cannot_give_managed_number_property_non_numeric_value_during_transition_creation
    size_property = setup_managed_number_list_definition('Size',[])
    invalid_value_1 = 'foo'
    invalid_value_2 = 'bar'
    
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    type_transition_name('set size')
    add_value_to_property_on_transition_sets(@project, 'Size', invalid_value_1)
    click_create_transition
    assert_error_message("Property to set Size: #{invalid_value_1} is an invalid numeric value")
    
    add_value_to_property_on_transition_requires(@project, 'Size', invalid_value_2)
    set_sets_properties(@project, 'Size' => '(not set)')
    click_create_transition
    assert_error_message("Required property Size: #{invalid_value_2} is an invalid numeric value")
        
    assert_transition_not_present_on_managment_page_for(@project, 'Size')
    navigate_to_property_management_page_for(@project)
    assert_property_does_not_have_value(size_property, invalid_value_1)
    assert_property_does_not_have_value(size_property, invalid_value_2)
  end

  def test_cannot_give_any_number_property_non_numeric_value_during_transition_creation
    setup_allow_any_number_property_definition('Iteration')
    invalid_value_1 = 'foo'
    invalid_value_2 = 'bar'

    transition_name = 'set iteration'
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    type_transition_name(transition_name)
    
    add_value_to_property_on_transition_sets(@project, 'Iteration', invalid_value_1)
    click_create_transition
    assert_error_message("Property to set Iteration: #{invalid_value_1} is an invalid numeric value")     
    
    add_value_to_property_on_transition_requires(@project, 'Iteration', invalid_value_2)
    set_sets_properties(@project, 'Iteration' => '(not set)')
    click_create_transition
    assert_error_message("Required property Iteration: #{invalid_value_2} is an invalid numeric value")
    
    assert_transition_not_present_on_managment_page_for(@project, transition_name)
  end

  def test_cannot_give_managed_number_property_non_numeric_value_during_transition_edition
    invalid_value_1 = 'foo'
    invalid_value_2 = 'bar'
    
    setup_allow_any_number_property_definition('Iteration')
    transition = create_transition(@project, 'Set Iteration', :set_properties => {:iteration => '2'})
    
    open_transition_for_edit(@project, transition)
    add_value_to_property_on_transition_sets(@project, 'Iteration', invalid_value_1)
    click_save_transition
    assert_error_message("Property to set Iteration: #{invalid_value_1} is an invalid numeric value")     
    
    open_transition_for_edit(@project, transition)
    add_value_to_property_on_transition_requires(@project, 'Iteration', invalid_value_2)
    click_save_transition
    assert_error_message("Required property Iteration: #{invalid_value_2} is an invalid numeric value")

    open_transition_for_edit(@project, transition)
    assert_requires_property('Iteration' => '(any)')
    assert_sets_property('Iteration' => '2')
  end
  
  def test_cannot_give_any_number_property_non_numeric_value_during_transition_edition
    invalid_value_1 = 'foo'
    invalid_value_2 = 'bar'
    
    setup_managed_number_list_definition('Size',['1', '2'])
    transition = create_transition(@project, 'Set Size', :set_properties => {'Size' => '2'})
    
    open_transition_for_edit(@project, transition)
    add_value_to_property_on_transition_sets(@project, 'Size', invalid_value_1)
    click_save_transition
    assert_error_message("Property to set Size: #{invalid_value_1} is an invalid numeric value")     
    
    add_value_to_property_on_transition_requires(@project, 'Size', invalid_value_2)
    click_save_transition
    assert_error_message("Required property Size: #{invalid_value_2} is an invalid numeric value")

    open_transition_for_edit(@project, transition)
    assert_requires_property('Size' => '(any)')
    assert_sets_property('Size' => '2')
  end
    
  def test_numeric_hidden_properties_showup_on_transitions
    size_property = setup_managed_number_list_definition('Size',[])
    iteration_property = setup_allow_any_number_property_definition('Iteration')
    hide_property(@project, 'Size')
    hide_property(@project, 'Iteration')
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    type_transition_name('set iteration and size')
    assert_sets_property_present('Size', 'Iteration')
    assert_requires_property_present('Size', 'Iteration')
    add_value_to_property_on_transition_sets(@project, 'Iteration', 0)
    add_value_to_property_on_transition_sets(@project, 'Size', 4)
    click_create_transition
    assert_transition_present_for(@project, 'set iteration and size')
  end
  
  def test_cannot_create_managed_number_property_with_names_that_are_used_as_predefined_card_propperties
    predefined_properties = ['number', 'name', 'description', 'type', 'project',  'created by', 'modified by', 'created on', 'modified on']
    predefined_properties.each  do |predefined_property|
      create_property_definition_for(@project, predefined_property, :type  => 'number list')
      assert_error_message("Name #{predefined_property} is a reserved property name")
      navigate_to_property_management_page_for(@project)
      assert_property_does_not_exist(predefined_property)
      end
  end
  
  def test_cannot_create_any_number_property_with_names_that_are_used_as_predefined_card_propperties
    predefined_properties = ['number', 'name', 'description', 'type', 'project',  'created by', 'modified by', 'created on', 'modified on']
    predefined_properties.each  do |predefined_property|
      create_property_definition_for(@project, predefined_property, :type  => 'any number')
      assert_error_message("Name #{predefined_property} is a reserved property name")
      navigate_to_property_management_page_for(@project)
      assert_property_does_not_exist(predefined_property)
      end
  end

  def test_cannot_create_any_number_property_with_names_that_are_variations_of_predefined_card_propperty_names
    predefined_properties = ['created:by', 'modified_by', 'created-on', 'modified.by']
    predefined_properties.each  do |predefined_property|
      create_property_definition_for(@project, predefined_property, :type  => 'any number')
      assert_error_message("Name #{predefined_property} is a reserved property name")
      navigate_to_property_management_page_for(@project)
      assert_property_does_not_exist(predefined_property)
      end
  end
  
  def test_cannot_create_managed_number_property_with_names_that_are_variations_of_predefined_card_propperty_names
    predefined_properties = ['created:by', 'modified_by', 'created-on', 'modified.by']
    predefined_properties.each  do |predefined_property|
      create_property_definition_for(@project, predefined_property, :type  => 'number list')
      assert_error_message("Name #{predefined_property} is a reserved property name")
      navigate_to_property_management_page_for(@project)
      assert_property_does_not_exist(predefined_property)
      end
  end

  # bug 2863
  def test_error_message_are_not_ambiguous_while_adding_numeric_values
    size_property = setup_managed_number_list_definition('Size',['0'])
    create_enumeration_value_for(@project, size_property, 'foo')
    assert_error_message("Value foo is an invalid numeric value")
    assert_error_message_does_not_contain('Value must be numericValue has already been taken')
  end
  
end
