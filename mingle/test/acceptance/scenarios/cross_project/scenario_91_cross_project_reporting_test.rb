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

# Tags: scenario, tree-usage, properties, project, macro, user, cross_project
class Scenario91CrossProjectReportingTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  TYPE = 'Type'
  ITERATION = 'Iteration'
  STORY = 'Story'
  CARD = 'Card'

  PRIORITY = 'Priority'
  LOW = 'low'
  HIGH = 'high'
  STATUS = 'status'
  ACCEPTED = 'accepted'
  CLOSED = 'closed'

  NAME = 'Name'
  NUMBER = 'Number'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_one_member = users(:project_member)
    @project_two_member = users(:longbob)
    @project_one = create_project(:prefix => 'scenario_91', :admins => [@project_admin], :users => [@project_one_member], :read_only_users => [@project_two_member])
    @type_story_project_one = setup_card_type(@project_one, STORY)
    @project_two = create_project(:prefix => 'project_two', :admins => [@project_admin], :users => [@project_two_member])
    setup_property_definitions(PRIORITY => [LOW, HIGH], STATUS => [ACCEPTED, CLOSED])
    @type_story = setup_card_type(@project_two, STORY, :properties => [PRIORITY, STATUS])
    @type_iteration = setup_card_type(@project_two, ITERATION)

    login_as_admin_user
    @story_card_for_project_two = create_card!(:name => 'foo', :card_type => STORY, STATUS => ACCEPTED, PRIORITY => HIGH)
  end

  def test_cross_project_table_get_valid_error_on_project_name_change
    new_name = 'project_three'
    page_name = 'foo'
    open_wiki_page(@project_one, page_name)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo'])

    login_as_admin_user
    open_project_admin_for(@project_two)
    type_project_name(new_name)
    click_save_link
    open_wiki_page(@project_one, page_name)
    assert_mql_error_messages("Error in table macro: There is no project with identifier #{@project_two.identifier}.")
  end

  def test_multipal_projects_is_not_supported_in_mingle_built_in_macro
    macro_names = ['project', 'project-variable', 'average','value','table','pivot-table','stack-bar-chart', 'data-series-chart', 'ratio-bar-chart', 'pie-chart']
    # because of bug "view" macro's message is different, after the bug's fixed, add "view" into macro_names
    # macro_names = ['project', 'project-variable', 'average','table','value','view', 'pivot-table','stack-bar-chart', 'data-series-chart', 'ratio-bar-chart', 'pie-chart']
    open_project(@project_one)
    for macro_name in macro_names
      add_macro_with_only_project_parameter(macro_name,@project_one.identifier,@project_two.identifier)
      assert_mql_error_messages(
      "Error in #{macro_name} macro: There is no project with identifier #{@project_one.identifier}, #{@project_two.identifier}.")
    end
  end

  def add_macro_with_only_project_parameter(macro_name, *projects)
    edit_overview_page
    create_free_hand_macro(%{
         #{macro_name}
          project: #{projects.join(',')}
     })

  end

  def test_read_only_user_can_see_mql_table_of_cross_project_he_is_member_of
    open_overview_page_for_edit(@project_one)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo'])

    logout
    login_as(@project_two_member.login, 'longtest')
    navigate_to_project_overview_page(@project_one)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo'])
  end

  def test_read_only_user_can_not_see_mql_table_of_cross_project_he_is_not_member_of
    project_three = create_project(:prefix => 'scenario_91_3', :admins => [@project_admin],:read_only_users => [@project_one_member])
    open_overview_page_for_edit(project_three)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo'])

    login_as(@project_one_member.login)
    navigate_to_project_overview_page(project_three)
    assert_cross_project_reporting_restricted_message_for(@project_two)
  end

  def test_read_only_user_who_is_read_only_for_both_project_should_be_able_to_see_mqls
    cards = create_cards(@project_one, 2, :card_type => @type_story)
    project_three = create_project(:prefix => 'scenario_91_3', :admins => [@project_admin],:read_only_users => [@project_two_member])
    open_overview_page_for_edit(project_three)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_one)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['2', 'card 2'])

    login_as(@project_two_member.login, 'longtest')
    navigate_to_project_overview_page(project_three)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['2', 'card 2'])
  end

  def test_cross_project_tables_get_updated_on_project_changes
    new_name = 'project_three'
    page_name = 'foo'
    open_wiki_page(@project_one, page_name)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo'])
    open_card(@project_two, @story_card_for_project_two)
    edit_card(:name => "foo bar")

    login_as_admin_user
    open_wiki_page(@project_one, page_name)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['1', 'foo bar'])
  end

  # bug 3612
  def test_team_member_cannot_see_table_query_for_project_they_are_not_member_of
    page_name = 'foo'
    open_wiki_page(@project_one, page_name)
    table_query = add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    login_as_project_member
    open_wiki_page(@project_one, page_name)
    assert_cross_project_reporting_restricted_message_for(@project_two)
  end

  # bug 3615
  def test_team_member_can_create_card_from_type_default_that_creates_macro_for_project_they_are_not_member_of
    ratio_bar_markup = generate_ratio_bar_chart(PRIORITY, "COUNT(*)", :query_conditions => "#{TYPE} = #{STORY}", :restrict_conditions => "#{STATUS} = #{ACCEPTED}",
      :cross_project => @project_two.identifier)
    edit_card_type_defaults_for(@project_one, STORY, :description => ratio_bar_markup)
    login_as_project_member
    @project_one.with_active_project do |project_one|
      navigate_to_card_list_for(project_one)
      card_number = add_new_card('should have cross projo defaults', :type => STORY)
      assert_notice_message("Card ##{card_number} was successfully created.")
      open_card(project_one, card_number)
      assert_cross_project_reporting_restricted_message_for(@project_two, 'card-description')
    end
  end

  # bug 3609
  def test_user_can_edit_wiki_content_even_if_he_or_she_cannot_see_it
    table_query = generate_table_query_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    page_name = 'foo'
    open_wiki_page(@project_one, page_name)
    enter_text_in_editor('\\n\\nTHis is text\\n')
    create_free_hand_macro(table_query)
    click_save_link
    login_as_project_member
    open_wiki_page(@project_one, page_name)
    assert_cross_project_reporting_restricted_message_for(@project_two)

    table_query = generate_table_query_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    # edit_page(@project_one, page_name, table_query)
    open_wiki_page_for_edit(@project_one, page_name)
    create_free_hand_macro(table_query)
    click_save_link
    assert_cross_project_reporting_restricted_message_for(@project_two)
    logout
    login_as_admin_user
    with_ajax_wait {open_wiki_page(@project_one, page_name) }
    assert_table_column_headers_and_order('content', NUMBER, NAME)
  end

  # bug 3609
  def test_user_can_edit_cards_that_have_cross_project_content_in_description
    @project_one.activate
    setup_numeric_property_definition('numnum', [1, 2, 3])
    project_one_card = create_card!(:name => 'some card', :card_type => CARD)
    open_card_for_edit(@project_one, project_one_card)
    add_table_query_and_save_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)

    login_as_project_member
    open_card(@project_one, project_one_card)
    assert_cross_project_reporting_restricted_message_for(@project_two, 'card-description')
    open_card_for_edit(@project_one, project_one_card)
    type_card_name('new name for card')
    set_properties_in_card_edit('numnum' => '2')
    save_card

    login_as_admin_user
    open_card(@project_one, project_one_card)
    assert_card_name_in_show('new name for card')
    assert_property_set_on_card_show('numnum', '2')
  end

  # bug 3610
  def test_users_transition_changes_should_be_made_on_cards_that_contain_content_from_projects_they_are_not_member_of
    @project_one.activate
    setup_numeric_property_definition('numnum', [1, 2, 3])
    table_query = generate_table_query_for_cross_project([NUMBER, NAME], ["#{TYPE} = #{STORY}"], @project_two)
    project_one_card = create_card!(:name => 'some card', :card_type => CARD, :description => table_query)
    setup_property_definitions(STATUS => [ACCEPTED, CLOSED])
    transition = create_transition(@project_one, 'change status', :set_properties => {:status => ACCEPTED}, :require_comment => true)
    type_card_project_one = @project_one.card_types.find_by_name(CARD)
    tree = setup_tree(@project_one, 'some tree', :types => [@type_story_project_one, type_card_project_one], :relationship_names => ['some tree - story'])
    add_card_to_tree(tree, project_one_card)
    login_as_project_member

    navigate_to_tree_view_for(@project_one, 'some tree')
    click_on_card_in_tree(project_one_card)
    click_transition_link_on_card_with_input_required(transition)
    add_comment_for_transition_to_complete_text_area('foo added')
    click_on_complete_transition(:ajaxwait => true)

    open_card(@project_one, project_one_card)
    assert_property_set_on_card_show(STATUS, ACCEPTED)
  end

  # bug 8214
  def test_should_be_able_to_use_this_card_property_used_in_a_cross_project_macro_should
    @project_one.with_active_project do
      setup_property_definitions(STATUS => [ACCEPTED, CLOSED])
      open_project(@project_one)
      table_query = generate_table_query_for_cross_project([NUMBER, NAME], ["#{STATUS} = this card.status"], @project_two)
      card_number = create_new_card(@project_one, {:name => 'cross project card', :description => table_query})
      card = @project_one.cards.find_by_number(card_number)
      assert_card_present_in_list(card)
    end
  end
end
