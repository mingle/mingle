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

# Tags: macro, mql, average_query
class Scenario96MqlAverageQueryTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  SIZE = 'size'
  ITERATION_SIZE = 'iteration_size'
  TYPE = 'type'
  PLANNING_TREE = 'planning tree'
  PLANNING_RELEASE = 'planning tree - release'
  PLANNING_ITERATION = 'planning tree - iteration'

  RELEASE = 'release'
  ITERATION = 'iteration'
  STORY = 'story'

  AVERAGE = 'average'
  INSERT_AVERAGE = 'Insert Average'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_95', :admins => [@project_admin_user, users(:admin)])
    @size = setup_numeric_property_definition(SIZE, [0, 1, 2, 3])
    @iteration_size = setup_numeric_property_definition(ITERATION_SIZE, [1, 2, 3])

    @type_release = setup_card_type(@project, RELEASE)
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [SIZE, ITERATION_SIZE])
    @type_story = setup_card_type(@project, STORY, :properties => [SIZE])
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [PLANNING_RELEASE, PLANNING_ITERATION])

    login_as_proj_admin_user
  end

  # Bug 3075 - scenario 1.
  def test_should_exclude_null_values
    create_card!(:name => 'story size 2', TYPE => STORY, SIZE => 2)
    create_card!(:name => 'story size 0', TYPE => STORY, SIZE => 0)
    create_card!(:name => 'story not set', TYPE => STORY)
    open_overview_page_for_edit(@project)
    create_free_hand_macro(generate_average_query(SIZE, "#{TYPE}=#{STORY}"))
    click_save_link
    assert_contents_on_page("1")
  end

  pending "Add it back when we decide to make AS OF a public feature for Average query"
  def test_should_be_able_to_use_AS_OF_in_average_query
    Clock.now_is("2009-05-14") do
      @story_1 = create_card!(:name => 'story_1', TYPE => STORY, SIZE => '1')
      @story_2 = create_card!(:name => 'story_2', TYPE => STORY, SIZE => '2')
    end

    Clock.now_is("2009-08-16") do
      @story_1.update_attribute(:cp_size, 2)
      @story_2.update_attribute(:cp_size, 3)
    end

    Clock.now_is("2009-10-18") do
      @story_1.update_attribute(:cp_size, 0)
      @story_2.update_attribute(:cp_size, 1)
    end

    create_new_wiki_page(@project, "Overview_Page", generate_average_query("#{SIZE} AS OF '2009, May, 30'", "#{TYPE}=#{STORY}"))
    assert_contents_on_page("1.5")
    edit_page(@project, "Overview_Page", generate_average_query("#{SIZE} AS OF '2009, Aug, 30'", "#{TYPE}=#{STORY}"))
    assert_contents_on_page("2.5")
    edit_page(@project, "Overview_Page", generate_average_query("#{SIZE} AS OF '2009, Oct, 30'", "#{TYPE}=#{STORY}"))
    assert_contents_on_page("0.5")
  end

  # Bug 3075 - scenario 2.
  def test_should_only_include_cards_with_the_property
    release = create_card!(:name => 'release', TYPE => RELEASE)
    iteration1 = create_card!(:name => 'iteration1', TYPE => ITERATION, SIZE => 2, ITERATION_SIZE => 3)
    iteration2 = create_card!(:name => 'iteration2', TYPE => ITERATION, SIZE => 2, ITERATION_SIZE => 2)
    story1 = create_card!(:name => 'story1', TYPE => STORY, SIZE => 1)
    story2 = create_card!(:name => 'story2', TYPE => STORY, SIZE => 1)
    add_card_to_tree(@planning_tree, release)
    add_card_to_tree(@planning_tree, iteration1, release)
    add_card_to_tree(@planning_tree, iteration2, release)
    add_card_to_tree(@planning_tree, story1, iteration1)
    add_card_to_tree(@planning_tree, story2, iteration1)
    current_release = 'current release'
    setup_project_variable(@project, :name => current_release, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => release, :properties => [PLANNING_RELEASE])

    open_overview_page_for_edit(@project)
    query_condition = "'#{PLANNING_RELEASE}'=(#{current_release})"
    size_average_query = generate_average_query(SIZE, query_condition)
    iteration_size_average_query = generate_average_query(ITERATION_SIZE, query_condition)
    click_save_link
    edit_overview_page
    create_free_hand_macro(size_average_query)

    click_save_link
    assert_contents_on_page("1.5")

    click_edit_link_and_wait_for_page_load
    enter_text_in_editor('\\n')
    create_free_hand_macro(iteration_size_average_query)
    click_save_link
    assert_contents_on_page("2.5")
  end

  # random-failures: 1
  def test_macro_editor_for_average_macro_on_wiki_edit
    open_wiki_page_in_edit_mode
    click_toolbar_wysiwyg_editor(INSERT_AVERAGE)
    @browser.wait_for_element_present 'wysiwyg_macro_editor_dialog'
    assert_should_see_macro_editor_lightbox
    assert_macro_parameters_field_exist(AVERAGE, ['query', 'project'])
    assert_text_present('Example: SELECT property WHERE condition')
  end

  def test_macro_editor_preview_for_average_macro_on_card_edit
    create_card!(:name => 'plain card 1', TYPE => STORY, SIZE => 200)
    create_card!(:name => 'plain card 2', TYPE => STORY, SIZE => 300)
    create_card!(:name => 'plain card 3', TYPE => STORY, SIZE => 700)

    open_macro_editor_without_param_input(INSERT_AVERAGE)
    type_macro_parameters(AVERAGE, :query => "")
    preview_macro
    preview_content_should_include("Error in average macro: Parameter query is required")

    type_macro_parameters(AVERAGE, :query => "select #{SIZE} where")


    preview_macro
    preview_content_should_include("Error in average macro")

    add_macro_parameters_for(AVERAGE, ['project'])
    type_macro_parameters(AVERAGE, :query => "select #{SIZE} where #{TYPE} = #{STORY}")
    type_macro_parameters(AVERAGE, :project => @project.identifier)


    preview_macro
    preview_content_should_include("400")
  end

  def test_should_give_nice_error_message_when_give_project_parameter_a_numeric_value_123
    create_card!(:name => 'plain card 1', TYPE => STORY, SIZE => 200)
    open_macro_editor_without_param_input(INSERT_AVERAGE)
    add_macro_parameters_for(AVERAGE, ['project'])
    type_macro_parameters(AVERAGE, :query => "select #{SIZE} where #{TYPE} = #{STORY}")
    type_macro_parameters(AVERAGE, :project => "123")
    preview_macro
    assert_mql_error_messages("Error in average macro: There is no project with identifier 123.")
  end
end
