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

# Tags: project-variable-usage
class Scenario118UsingProjectVariableInCardViewTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STORY = 'Story'
  ANY_TEXT_PROPERTY = 'any text'
  ANY_NUMBER_PROPERTY = 'any number'
  MANAGED_TEXT_PROPERTY = 'managed text list'
  MANAGED_NUMBER_PROPERTY = 'managed number list'
  TEAM_MEMBER_PROPERTY = 'user'
  CARD_TYPE_PROPERTY = 'releated card'
  DATE_PROPERTY = 'today'

  CARD_NAME = 'simple card'
  CARD_NAME_2 = 'simple card 2'

  NOTSET = '(not set)'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @project = create_project(:prefix => 'scenario_118', :read_only_users => [@read_only_user], :users => [@team_member], :admins => [@project_admin], :anonymous_accessible => true)
    @project.activate
    @type_story = setup_card_type(@project, STORY)
    login_as_proj_admin_user
    @story1 = create_card!(:name => CARD_NAME, :card_type  => STORY)
    @story2 = create_card!(:name => CARD_NAME_2, :card_type  => STORY)
  end

  def test_user_can_set_any_text_property_or_managed_text_property_with_available_text_type_plv
    text_plv_name = 'text plv'
    text_plv_value = 'I am the value of text plv!'

    any_text_property = create_allow_any_text_property(ANY_TEXT_PROPERTY)
    managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['a', 'b', 'c'])
    create_text_plv(@project, text_plv_name, text_plv_value, [any_text_property, managed_text_property])
    add_properties_for_card_type(@type_story, [any_text_property,managed_text_property])

    open_card(@project, @story1)

    set_properties_on_card_show(ANY_TEXT_PROPERTY  =>  "(#{text_plv_name})")
    set_properties_on_card_show(MANAGED_TEXT_PROPERTY => "(#{text_plv_name})")
    assert_properties_set_on_card_show({ ANY_TEXT_PROPERTY => text_plv_value })
    assert_properties_set_on_card_show(MANAGED_TEXT_PROPERTY => text_plv_value)

    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {ANY_TEXT_PROPERTY => text_plv_value})
    assert_history_for(:card, @story1.number).version(3).shows(:set_properties => {MANAGED_TEXT_PROPERTY => text_plv_value})

    open_card_for_edit(@project, @story2)
    set_properties_in_card_edit(ANY_TEXT_PROPERTY  =>  "(#{text_plv_name})")
    set_properties_in_card_edit(MANAGED_TEXT_PROPERTY => "(#{text_plv_name})")
    assert_edit_property_set(ANY_TEXT_PROPERTY, "(#{text_plv_name})")
    assert_edit_property_set(MANAGED_TEXT_PROPERTY, "(#{text_plv_name})")
    save_card
    assert_properties_set_on_card_show({ ANY_TEXT_PROPERTY => text_plv_value })
    assert_properties_set_on_card_show(MANAGED_TEXT_PROPERTY => text_plv_value)

    # should be able to search a plv as value in dropdown for property. AC for # 6441
    click_property_on_card_show(MANAGED_TEXT_PROPERTY)
    type_keyword_to_search_value_for_property_on_card_show(MANAGED_TEXT_PROPERTY,'(')
    assert_value_present_in_property_drop_down_on_card_show(MANAGED_TEXT_PROPERTY, ["(#{text_plv_name})"])
    select_value_in_drop_down_for_property_on_card_show(MANAGED_TEXT_PROPERTY,"(#{text_plv_name})")
    assert_property_set_on_card_show(MANAGED_TEXT_PROPERTY, text_plv_value)

    delete_project_variable(@project, text_plv_name)
    click_continue_to_delete
    open_card(@project, @story1)
    assert_properties_set_on_card_show(ANY_TEXT_PROPERTY => text_plv_value)
    assert_properties_set_on_card_show(MANAGED_TEXT_PROPERTY => text_plv_value)
  end


  def test_user_can_set_any_number_property_or_managed_number_property_with_available_numeric_type_plv
    number_plv_name = 'number plv'
    number_plv_value = '20090119'

    any_number_property = create_allow_any_number_property(ANY_NUMBER_PROPERTY)
    managed_number_property = create_managed_number_list_property(MANAGED_NUMBER_PROPERTY, [1,2,3])
    create_number_plv(@project, number_plv_name, number_plv_value, [any_number_property, managed_number_property])
    add_properties_for_card_type(@type_story, [any_number_property, managed_number_property])

    open_card(@project, @story1.number)
    set_properties_on_card_show(ANY_NUMBER_PROPERTY => "(#{number_plv_name})")
    set_properties_on_card_show(MANAGED_NUMBER_PROPERTY => "(#{number_plv_name})")
    assert_properties_set_on_card_show({ ANY_NUMBER_PROPERTY => number_plv_value })
    assert_properties_set_on_card_show(MANAGED_NUMBER_PROPERTY => number_plv_value)

    open_card_for_edit(@project, @story2.number)
    set_properties_in_card_edit(ANY_NUMBER_PROPERTY => "(#{number_plv_name})")
    set_properties_in_card_edit(MANAGED_NUMBER_PROPERTY => "(#{number_plv_name})")
    assert_edit_property_set(ANY_NUMBER_PROPERTY, "(#{number_plv_name})")
    assert_edit_property_set(MANAGED_NUMBER_PROPERTY,  "(#{number_plv_name})")
    save_card
    assert_properties_set_on_card_show({ ANY_NUMBER_PROPERTY => number_plv_value })
    assert_properties_set_on_card_show(MANAGED_NUMBER_PROPERTY => number_plv_value)

    disassociate_project_variable_from_property(@project, number_plv_name, ANY_NUMBER_PROPERTY)
    open_card(@project, @story1)
    assert_free_text_does_not_have_drop_down(ANY_NUMBER_PROPERTY, "show")

    # should be able to search a plv as value in dropdown for property. AC for # 6441
    click_property_on_card_show(MANAGED_NUMBER_PROPERTY)
    type_keyword_to_search_value_for_property_on_card_show(MANAGED_NUMBER_PROPERTY,'(')
    assert_value_present_in_property_drop_down_on_card_show(MANAGED_NUMBER_PROPERTY,["(#{number_plv_name})"])
    select_value_in_drop_down_for_property_on_card_show(MANAGED_NUMBER_PROPERTY,"(#{number_plv_name})")
    assert_property_set_on_card_show(MANAGED_NUMBER_PROPERTY, number_plv_value)

    delete_project_variable(@project, number_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{number_plv_name} was successfully deleted")

    open_card(@project, @story1.number)
    assert_properties_set_on_card_show(ANY_NUMBER_PROPERTY => number_plv_value)
    assert_properties_set_on_card_show(MANAGED_NUMBER_PROPERTY => number_plv_value)
  end


  def test_user_can_set_user_property_with_available_user_type_plv
    team_plv_name = 'team plv'
    team_plv_id = @team_member
    team_plv_value = "member@ema..."

    team_property = create_team_property(TEAM_MEMBER_PROPERTY)
    create_user_plv(@project, team_plv_name, team_plv_id, [team_property])
    add_properties_for_card_type(@type_story, [team_property])

    open_card(@project, @story1.number)
    set_properties_on_card_show(TEAM_MEMBER_PROPERTY => "(#{team_plv_name})")
    assert_properties_set_on_card_show(TEAM_MEMBER_PROPERTY => team_plv_value)

    open_card_for_edit(@project, @story2.number)
    set_properties_in_card_edit(TEAM_MEMBER_PROPERTY => "(#{team_plv_name})")
    assert_edit_property_set(TEAM_MEMBER_PROPERTY, "(#{team_plv_name})")
    save_card
    assert_properties_set_on_card_show(TEAM_MEMBER_PROPERTY => team_plv_value)

    # should be able to search a plv as value in dropdown for property. AC for # 6441
    click_property_on_card_show(TEAM_MEMBER_PROPERTY)
    type_keyword_to_search_value_for_property_on_card_show(TEAM_MEMBER_PROPERTY, "")
    assert_value_present_in_property_drop_down_on_card_show(TEAM_MEMBER_PROPERTY, ["(#{team_plv_name})"])
    select_value_in_drop_down_for_property_on_card_show(TEAM_MEMBER_PROPERTY, "(#{team_plv_name})")
    assert_property_set_on_card_show(TEAM_MEMBER_PROPERTY, team_plv_value)

    delete_project_variable(@project, team_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{team_plv_name} was successfully deleted")

    open_card(@project, @story1.number)
    assert_properties_set_on_card_show(TEAM_MEMBER_PROPERTY => team_plv_value)
  end


  def test_user_can_set_card_type_property_with_available_card_type_plv
    card_type_plv_name = 'card type plv'
    card_type_plv_value = "#1 simple card"

    card_type_property = create_card_type_property(CARD_TYPE_PROPERTY)
    create_card_plv(@project, card_type_plv_name, @type_story, @story1, [card_type_property])

    add_properties_for_card_type(@type_story, [card_type_property])

    open_card(@project, @story1.number)
    set_properties_on_card_show(CARD_TYPE_PROPERTY  => "(#{card_type_plv_name})")
    assert_properties_set_on_card_show(CARD_TYPE_PROPERTY => card_type_plv_value)

    open_card_for_edit(@project, @story2.number)
    set_properties_in_card_edit(CARD_TYPE_PROPERTY => "(#{card_type_plv_name})")
    assert_edit_property_set(CARD_TYPE_PROPERTY, "(#{card_type_plv_name})")
    save_card
    assert_properties_set_on_card_show(CARD_TYPE_PROPERTY => card_type_plv_value)

    delete_project_variable(@project, card_type_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{card_type_plv_name} was successfully deleted")

    open_card(@project, @story1.number)
    assert_properties_set_on_card_show(CARD_TYPE_PROPERTY => card_type_plv_value)
  end


  def test_user_can_set_date_type_property_with_available_date_type_plv
    date_type_plv_name = 'date type plv'
    date_type_plv_value = '01 Jan 2009'

    date_type_property = create_date_property(DATE_PROPERTY)
    create_date_plv(@project, date_type_plv_name, date_type_plv_value, [date_type_property])

    add_properties_for_card_type(@type_story, [date_type_property])

    open_card(@project, @story1)
    set_properties_on_card_show(DATE_PROPERTY => "(#{date_type_plv_name})")
    assert_properties_set_on_card_show(DATE_PROPERTY => date_type_plv_value)

    open_card_for_edit(@project, @story2)
    set_properties_in_card_edit(DATE_PROPERTY => "(#{date_type_plv_name})")
    assert_edit_property_set(DATE_PROPERTY, "(#{date_type_plv_name})")
    save_card
    assert_properties_set_on_card_show(DATE_PROPERTY => date_type_plv_value)

    delete_project_variable(@project, date_type_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{date_type_plv_name} was successfully deleted")

    open_card(@project, @story1)
    assert_properties_set_on_card_show(DATE_PROPERTY => date_type_plv_value)
  end

end
