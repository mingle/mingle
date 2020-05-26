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
# Tags: history, properties, anyChange
class Scenario160AnyChangeUsageInHistoryTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = User.find_by_login('member')
    @admin = User.find_by_login('admin')

    login_as_project_member
    @project = create_project(:prefix => 'project_160', :users => [@project_member, @admin])
    open_project(@project)
  end

  def teardown
    super
    @project.deactivate
  end

  def test_any_change_should_be_available_in_second_history_filter_for_different_properties
    Outline(<<-Examples) do | user_have_different_properties  , property_name, property_type|
      | { create_property_for_card("Managed text list", 'status') } | status | enumerated   |
      | { create_property_for_card("Managed number list", 'size') } | size   | enumerated   |
      | { create_property_for_card("team", 'owner')}                | owner  | user         |
      | { create_property_for_card("card", "friend")}               | friend | cardrelationship|
      | {create_relationshop_property_for_card("relationship")}| relationship| treerelationship |
      Examples
      user_have_different_properties.happened
      navigate_to_history_for(@project)
      assert_value_present_in_history_filter_drop_list_for_property_in_second_filter_widget(property_name, "(any change)", :property_type => property_type)
    end
  end

  def test_using_any_change_to_filter_managed_text_property
    setup_property_definitions('status' => ['new', 'in progress'])
    user_have_some_versions_changes_on_managed_text_property
    user_filter_to_track_any_change_on('status', 'open')
    user_should_only_get_correct_versions_match_any_change
  end

  def test_using_any_change_to_filter_managed_number_property
    user_have_some_versions_changes_on_managed_number_property
    user_filter_to_track_any_change_on('size', '1')
    user_should_only_get_correct_versions_match_any_change
  end

  def test_using_any_change_to_filter_user_property
    user_have_some_versions_changes_on_user_property
    user_filter_to_track_any_change_on('owner', @project_member.name)
    user_should_only_get_correct_versions_match_any_change
  end

  def test_using_any_change_to_filter_card_property
    user_have_some_versions_changes_on_card_property
    user_filter_to_track_any_change_on('friend', card_number_and_name(@value_of_card_property))
    user_should_only_get_correct_versions_match_any_change
  end

  def test_using_any_change_to_filter_relationship_property
    user_have_some_versions_changes_on_relationship_property
    user_filter_to_track_any_change_on('parent', card_number_and_name(@value_of_relationship_property))
    user_should_only_get_correct_versions_match_any_change
  end

  def test_using_the_AND_logic_when_using_any_change_and_another_property_in_history_filter
    setup_property_definitions("status" => ['open', 'closed'])
    setup_property_definitions("size" => ['1', '2'])
    @card = create_card!(:name => "card 1", 'status' => "open", 'size' => '1')
    @card.update_attributes({:cp_status => 'closed'})
    @card.update_attributes({:cp_size => '2'})
    @card.update_attributes({:cp_status => 'open', :cp_size => 1})
    @card.update_attributes({:cp_status => nil, :cp_size => 2})
    @browser.run_once_history_generation

    navigate_to_history_for(@project)
    filter_history_using_first_condition_by(@project, 'size' => '1')
    filter_history_using_second_condition_by(@project, 'size' => '2')
    filter_history_using_first_condition_by(@project, 'status' => 'open')
    filter_history_using_second_condition_by(@project, 'status' => '(any change)')

    assert_history_for(:card, @card.number).version(5).present
    assert_history_for(:card, @card.number).version(1).not_present
    assert_history_for(:card, @card.number).version(2).not_present
    assert_history_for(:card, @card.number).version(3).not_present
    assert_history_for(:card, @card.number).version(4).not_present

  end


  def test_user_can_subscribe_event_to_track_any_change_on_different_properties
    Outline(<<-Examples) do | user_have_different_properties  , property_name, property_type|
      | { create_property_for_card("Managed text list", 'status') } | status | enumerated   |
      | { create_property_for_card("Managed number list", 'size') } | size   | enumerated   |
      | { create_property_for_card("team", 'owner')}                | owner  | user         |
      | { create_property_for_card("card", "friend")}               | friend | cardrelationship|
      | {create_relationshop_property_for_card("relationship")}| relationship| treerelationship |
      Examples
      user_have_different_properties.happened
      user_filter_to_track_any_change_on(property_name, '(any)')
      user_should_be_able_to_subscribe_it_successfully
    end
  end

  def test_user_can_subscribe_event_to_track_any_change_of_more_than_one_property
    create_property_for_card("team", 'owner')
    create_property_for_card("card", "friend")
    navigate_to_history_for(@project)
    filter_history_using_second_condition_by(@project, 'owner' => '(any change)')
    filter_history_using_second_condition_by(@project, 'friend' => '(any change)')
    user_should_be_able_to_subscribe_it_successfully
  end

  # bug 8354
  def test_handle_the_special_case_when_card_type_used_to_narrow_down_property
    user_have_some_versions_changes_on_managed_text_property
    user_set_filter_with_card_type_and_any_change_on_property('Card', 'status', 'open')
    user_should_only_get_correct_versions_match_any_change
  end


  private
  def user_have_some_versions_changes_on_managed_text_property
    setup_property_definitions("status" => ['open', 'closed'])
    @card = create_card!(:name => "card 1", 'status' => "open")
    @card.update_attributes({:cp_status => 'closed'})
    @card.update_attributes({:cp_status => 'open'})
    @card.update_attributes({:cp_status => nil})
    @card.update_attributes({:content => 'property is not changed'})
    @browser.run_once_history_generation
  end

  def user_have_some_versions_changes_on_managed_number_property
    setup_property_definitions("size" => ['1', '2'])
    @card = create_card!(:name => "card 1", 'size' => "1")
    @card.update_attributes({:cp_size => '2'})
    @card.update_attributes({:cp_size => '1'})
    @card.update_attributes({:cp_size => nil})
    @card.update_attributes({:content => 'property is not changed'})
    @browser.run_once_history_generation
  end

  def user_have_some_versions_changes_on_user_property
    setup_user_definition("owner")
    @card = create_card!(:name => "card 1", 'owner' => @project_member.id)
    @card.update_attributes({:cp_owner => @admin})
    @card.update_attributes({:cp_owner => @project_member})
    @card.update_attributes({:cp_owner => nil})
    @card.update_attributes({:content => 'property is not changed'})
    @browser.run_once_history_generation
  end

  def user_have_some_versions_changes_on_relationship_property
    create_relationshop_property_for_card('parent')
    parent_card_type = @project.card_types.find_by_name('parent')
    @value_of_relationship_property = create_card!(:name => "value of relationship property", :card_type => parent_card_type)
    changed_value_of_relationship_property = create_card!(:name => "changed value of relationship property", :card_type => parent_card_type)
    @card = create_card!(:name => "card 1", "parent" => @value_of_relationship_property.id)
    @card.update_attributes({:cp_parent => changed_value_of_relationship_property})
    @card.update_attributes({:cp_parent => @value_of_relationship_property})
    @card.update_attributes({:cp_parent => nil})
    @card.update_attributes({:content => 'property is not changed'})
    @browser.run_once_history_generation
  end

  def user_have_some_versions_changes_on_card_property
    create_card_type_property("friend")
    @value_of_card_property = create_card!(:name => "value of card property")
    @card = create_card!(:name => "card 1", "friend" => @value_of_card_property.id)
    @card.update_attributes({:cp_friend => @card})
    @card.update_attributes({:cp_friend => @value_of_card_property})
    @card.update_attributes({:cp_friend => nil})
    @card.update_attributes({:content => 'property is not changed'})
    @browser.run_once_history_generation
  end

  def user_should_only_get_correct_versions_match_any_change
    assert_history_for(:card, @card.number).version(4).present
    assert_history_for(:card, @card.number).version(2).present
    assert_history_for(:card, @card.number).version(1).not_present
    assert_history_for(:card, @card.number).version(3).not_present
    assert_history_for(:card, @card.number).version(5).not_present
  end

end
