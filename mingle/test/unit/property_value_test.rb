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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class PropertyValueTest < ActiveSupport::TestCase
  def setup
    @first_user = User.find_by_login('first')
    @bob = User.find_by_login('bob')
    @project = create_project :users => [@first_user, @bob]
    @project.activate
    setup_user_definition('owner')
    setup_property_definitions('status' => ['new', 'open', 'close'])
    setup_date_property_definition('finished')
    @owner_def = @project.find_property_definition('owner')
    @status_def = @project.find_property_definition('status')
    @finished_def = @project.find_property_definition('finished')
    @member = login_as_member
  end
  
  def test_to_xml_should_tag_name_as_property
    assert_not_nil get_element_text_by_xpath(PropertyValue.create_from_db_identifier(@status_def, '').to_xml, '/property')
  end
  
  def test_to_xml_should_render_type_description_as_tag_attribute
    assert_equal 'Managed text list', get_attribute_by_xpath(PropertyValue.create_from_db_identifier(@status_def, '').to_xml, '/property/@type_description')
    assert_equal 'Automatically generated from the team list', get_attribute_by_xpath(PropertyValue.create_from_db_identifier(@owner_def, @first_user.id).to_xml, '/property/@type_description')
    assert_equal 'Date', get_attribute_by_xpath(PropertyValue.create_from_url_identifier(@finished_def, "").to_xml, '/property/@type_description')
  end
  
  def test_should_treat_blank_as_nil
    blank = PropertyValue.create_from_db_identifier(@status_def, '')
    assert_nil blank.db_identifier
    assert_nil blank.url_identifier
    assert_equal PropertyValue::NOT_SET, blank.display_value
  end
  
  def test_should_create_property_value_with_db_identifier
    owner_value = PropertyValue.create_from_db_identifier(@owner_def, @first_user.id)
    assert_equal @first_user.name, owner_value.display_value
    assert_equal @first_user.id.to_s, owner_value.db_identifier
    assert_equal @first_user.login, owner_value.url_identifier
  end
  
  def test_should_create_property_value_with_url_identifier
    owner_value = PropertyValue.create_from_url_identifier(@owner_def, @first_user.login)
    assert_equal @first_user.name, owner_value.display_value
    assert_equal @first_user.id.to_s, owner_value.db_identifier
    assert_equal @first_user.login, owner_value.url_identifier
  end
  
  def test_display_value_should_be_not_set_if_url_identifier_is_blank
    owner_value = PropertyValue.create_from_url_identifier(@owner_def, '')
    assert_equal PropertyValue::NOT_SET, owner_value.display_value
    assert_nil owner_value.url_identifier
  end
  
  def test_for_enumerated_property_value_all_values_are_identical
    open = PropertyValue.create_from_db_identifier(@status_def, 'open')
    assert_equal 'open', open.display_value
    assert_equal 'open', open.db_identifier
    assert_equal 'open', open.url_identifier
  end
  
  def test_for_enumerated_property_value_blank_should_be_displayed_as_not_set
    blank = PropertyValue.create_from_db_identifier(@status_def, nil)
    assert_equal PropertyValue::NOT_SET, blank.display_value
    assert_nil blank.db_identifier
    assert_nil blank.url_identifier
  end  
  
  def test_for_date_property_value_blank_should_be_displayed_as_not_set
    blank = PropertyValue.create_from_url_identifier(@finished_def, "")
    assert_equal PropertyValue::NOT_SET, blank.display_value
    assert_nil blank.db_identifier
    assert_nil blank.url_identifier
  end
  
  def test_should_use_formated_date_string_as_property_value_field_value
    date = PropertyValue.create_from_url_identifier(@finished_def, "29 Apr 2009")
    assert_equal "29 Apr 2009", date.field_value
    @project.date_format = "%m/%d/%Y"
    @project.save!
    @project.reload
    assert_equal "04/29/2009", date.field_value
  end
  
  def test_field_value_for_not_set_property_value
    blank = PropertyValue.create_from_url_identifier(@finished_def, "")
    assert_equal nil, blank.field_value
  end
  
  def test_display_value_for_any_change
    any_change = PropertyValue.create_from_db_identifier(@owner_def, "(any change)")
    assert_equal PropertyValue::ANY_CHANGE, any_change.display_value
  end
  
  def test_equality_for_enumerated_property_value
    open = PropertyValue.create_from_db_identifier(@status_def, 'open')
    blank = PropertyValue.create_from_db_identifier(@status_def, '')
    close = PropertyValue.create_from_db_identifier(@status_def, 'close')
    owner_value = PropertyValue.create_from_url_identifier(@owner_def, '')
    assert_equal open, PropertyValue.create_from_db_identifier(@status_def, 'open')
    assert_not_equal open, nil
    assert_not_equal open, owner_value
    assert_not_equal open, blank
    assert_not_equal blank, open
    assert_not_equal open, close
  end

  def test_equality_on_user_property_value_include_current_user
    bob = PropertyValue.create_from_db_identifier(@owner_def, @bob.id)
    current_user = PropertyValue.create_from_db_identifier(@owner_def, PropertyType::UserType::CURRENT_USER)
    no_user = PropertyValue.create_from_db_identifier(@owner_def, nil)
    assert_not_equal bob, current_user
    assert_not_equal bob, no_user
    assert_not_equal current_user, no_user
    login(@bob.email)
    assert_equal bob, current_user
  end
  
  def test_should_able_to_calcuate_transitions_usage_of_itself
    open = PropertyValue.create_from_db_identifier(@status_def, 'open')
    close = PropertyValue.create_from_db_identifier(@status_def, 'close')
    assert_equal 0, open.transition_count
    assert_equal 0, close.transition_count
  
    transition = create_transition @project, 'some transition', :set_properties => {:status => 'close'}
      
    Project.current.reload
    assert_equal 1, close.transition_count
      
    transition.add_value_prerequisite(@status_def.name, 'open')
    transition.save!
    
    Project.current.reload
    assert_equal 1, close.transition_count
    
    transition = create_transition @project, 'another one', :set_properties => {:status => 'close'}
    Project.current.reload
    assert_equal 2, close.transition_count
  end
  
  def test_unused_returns_false_unless_no_cards_and_no_transitions
    setup_property_definitions :unused => ['value']
    unused_def = @project.find_property_definition('unused')
    unused_value = PropertyValue.create_from_db_identifier(unused_def, 'value')
    
    assert unused_value.unused?    
    
    card1 =create_card!(:name => 'first card', :unused => 'value') 
    open = create_transition @project, 'open', :required_properties => {:unused => 'value'}, :set_properties => {:unused => nil}
    
    Project.current.reload
    assert !unused_value.unused?
    card1.update_attribute :cp_unused, nil
    
    Project.current.reload
    assert !unused_value.unused?
  end
  
  def test_assigned_to_should_tell_whether_property_is_on_the_card
    fixed = @project.property_value('status', 'fixed')
    not_set = @project.property_value('status', nil)
    card =create_card!(:name => 'some card')
    assert !fixed.assigned_to?(card)
    assert not_set.assigned_to?(card)
    
    card.cp_status = 'fixed'
    
    assert fixed.assigned_to?(card)
    assert !not_set.assigned_to?(card)
  end
  
  def test_should_use_database_formate_for_date_property_as_db_identifier
    finshed_value = PropertyValue.create_from_db_identifier(@finished_def, "27 Mar 2007")
    assert_equal '2007-03-27', finshed_value.db_identifier
    assert_equal '27 Mar 2007', finshed_value.display_value
    assert_equal '27 Mar 2007', finshed_value.url_identifier
  end
  
  def test_preserved_identifier_should_remain_as_db_identifier
    ignored_value = PropertyValue.create_from_db_identifier(@finished_def, PropertyValue::IGNORED_IDENTIFIER)
    assert ignored_value.ignored?
    assert_equal PropertyValue::IGNORED_IDENTIFIER, ignored_value.db_identifier
    require_user_input = PropertyValue.create_from_db_identifier(@finished_def, Transition::USER_INPUT_REQUIRED)
    assert_equal Transition::USER_INPUT_REQUIRED, require_user_input.db_identifier
    today = PropertyValue.create_from_db_identifier(@finished_def, PropertyType::DateType::TODAY)
    assert_equal PropertyType::DateType::TODAY, today.db_identifier
  end    
  
  def test_property_value_can_tell_you_if_it_has_the_current_user_special_value
    @project.add_member(@member)
    
    special_property_value = PropertyValue.create_from_db_identifier(@owner_def, PropertyType::UserType::CURRENT_USER)
    regular_property_value = PropertyValue.create_from_db_identifier(@owner_def, @member.id)
    
    assert special_property_value.has_current_user_special_value?
    assert !regular_property_value.has_current_user_special_value?
  end
  
  def test_can_give_property_value_for_charting
    assert_equal @member.name_and_login, PropertyValue.create_from_db_identifier(@owner_def, @member.id).charting_value
  end
  
  def test_should_know_if_property_value_is_used_in_any_card_defaults
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.update_properties :owner => @bob.id
    card_defaults.save!    
    property_value = PropertyValue.create_from_db_identifier(@owner_def, @bob.id)
    property_usage = property_value.card_defaults_usage
    assert_equal [card_defaults], property_usage.card_defaults
  end
end
