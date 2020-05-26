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

# Tags: help
class Scenario165HelpLinksTest < ActiveSupport::TestCase

    fixtures :users, :login_access
    PAGE_NAME = "wikipage"
    PLV_NAME = "plv"
    MANAGED_NUMBER = 'managed number'
    FREE_NUMBER = 'free_number'

    MANAGED_TEXT_TYPE = "Managed text list"
    FREE_TEXT_TYPE = "Allow any text"
    MANAGED_NUMBER_TYPE = "Managed number list"
    FREE_NUMBER_TYPE = "Allow any number"
    USER_TYPE = "team"
    DATE_TYPE = "date"
    CARD_TYPE = "card"

    MANAGED_TEXT = 'managed text'
    FREE_TEXT = 'free_text'
    MANAGED_NUMBER = 'managed number'
    FREE_NUMBER = 'free_number'
    USER = 'user'
    DATE = 'date'
    RELATED_CARD = 'related_card'

    TRANSITION_ONLY = "transition_only"

     RELEASE = 'Release'
     ITERATION = 'Iteration'
     STORY = 'Story'
     TASK = 'Task'

     PLANNING_TREE = "planning_tree"
     RELEASE_ITERATION = "release-iteration"
     ITERATION_TASK = "iteration-task"
     TASK_STORY = "task-story"

     TRANSITION_1 = "transition 1"
     TRANSITION_2 = "transition 2"

    def setup
        destroy_all_records(:destroy_users => false, :destroy_projects => true)
        @browser = selenium_session
        @project = create_project(:prefix => 'project_with_tree', :admins => [users(:proj_admin)], :users => [users(:project_member)], :read_only_users => [users(:read_only_user)])
        login_as_admin_user
        add_properties_for_project(@project)
        add_card_types_for_project(@project)
        add_cards_of_different_card_types_for_project(@project)
        add_tree_and_card_for_project(@project)
        @numeric_plv = create_number_plv(@project, PLV_NAME,'3',[@project.all_property_definitions.find_by_name(MANAGED_NUMBER), @project.all_property_definitions.find_by_name(FREE_NUMBER)])
        create_new_wiki_page_via_model @project, PAGE_NAME, 'some text'
        add_normal_transtion_for_project(@project)
        add_transition_that_will_update_transition_only_property_for_project(@project)
    end

    def test_mingle_admin_should_be_able_to_see_help_links
        navigate_to_project_overview_page(@project)
        assert_help_link_on_page("project_overview_tab.html", "page-help")
        navigate_to_all_projects_page
        click_new_project_link
        assert_help_link_on_page("creating_mingle_projects.html", "page-help-at-action-bar")

        navigate_to_register_mingle_page
        assert_help_link_on_page("mingle_licenses.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        @browser.wait_for_element_present "tree-and-style-selector"
        assert_help_link_on_page("card_list_page.html", "full-contextual-help-link")
        navigate_to_grid_view_for(@project)
        assert_help_link_on_page("card_grid_page.html", "full-contextual-help-link")
        navigate_to_hierarchy_view_for(@project, @planning_tree)
        assert_help_link_on_page("hierarchy_view.html", "help-at-style-selector")
        navigate_to_tree_view_for(@project, @planning_tree.name)
        assert_help_link_on_page("tree_view.html", "help-at-style-selector")
        open_card_for_edit(@project, @release_1)
        assert_help_link_on_page("updating_cards.html", "page-help-at-action-bar")
        open_edit_defaults_page_for(@project, @release_1.card_type)
        assert_help_link_on_page("card_defaults.html", "page-help-at-action-bar")
        open_project_variable_create_page_for(@project)
        assert_help_link_on_page("creating_project_variables.html", "page-help-at-action-bar")
        open_project_variable_for_edit(@project, @numeric_plv.name)
        assert_help_link_on_page("modifying_or_deleting_project_variables.html", "page-help-at-action-bar")
        navigate_to_transition_management_for(@project)
        click_create_new_transition_link
        assert_help_link_on_page("creating_card_transitions.html", "page-help-at-action-bar")
        navigate_to_transition_management_for(@project)
        open_transition_for_edit(@project, @transition_with_comments_required.name)
        assert_help_link_on_page("modifying_or_deleting_card_transitions.html", "page-help-at-action-bar")
        open_wiki_page(@project, "wikipage")
        assert_help_link_on_page("working_with_pages.html", "page-help-at-action-bar")
        navigate_to_tree_configuration_management_page_for(@project)
        click_create_new_card_tree_link
        assert_help_link_on_page("creating_a_new_card_tree.html", "page-help-at-action-bar")
        navigate_to_property_management_page_for(@project)
        click_create_new_card_property
        assert_help_link_on_page("creating_card_properties.html", "page-help-at-action-bar")
        open_property_for_edit(@project, 'managed text')
        assert_help_link_on_page("modifying_or_deleting_card_properties.html", "page-help-at-action-bar")

        navigate_to_user_management_page
        click_new_user_link
        assert_help_link_on_page("creating_user_profiles.html", "page-help-at-action-bar")

        @browser.click_and_wait(class_locator("profile"))
        assert_help_link_on_page("managing_your_user_profile.html", "page-help-at-action-bar")
        @browser.click_and_wait(class_locator("profile"))
        @browser.click_and_wait("edit-profile")
        assert_help_link_on_page("edit_profile_page.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        click_import_from_excel
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        header_row = ['number', 'name', 'type']
        card_data = [['1', 'Release_1', 'Release'], ['2', 'Release_2', 'Release']]
        preview(excel_copy_string(header_row, card_data))
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")
    end

    def test_project_admin_should_be_able_to_see_help_links
        login_as_proj_admin_user
        navigate_to_project_overview_page(@project)
        assert_help_link_on_page("project_overview_tab.html", "page-help")
        navigate_to_card_list_for(@project)
        @browser.wait_for_element_present "tree-and-style-selector"
        assert_help_link_on_page("card_list_page.html", "full-contextual-help-link")
        navigate_to_grid_view_for(@project)
        assert_help_link_on_page("card_grid_page.html", "full-contextual-help-link")
        navigate_to_hierarchy_view_for(@project, @planning_tree)
        assert_help_link_on_page("hierarchy_view.html", "help-at-style-selector")
        navigate_to_tree_view_for(@project, @planning_tree.name)
        assert_help_link_on_page("tree_view.html", "help-at-style-selector")
        open_card_for_edit(@project, @release_1)
        assert_help_link_on_page("updating_cards.html", "page-help-at-action-bar")
        open_edit_defaults_page_for(@project, @release_1.card_type)
        assert_help_link_on_page("card_defaults.html", "page-help-at-action-bar")
        open_project_variable_create_page_for(@project)
        assert_help_link_on_page("creating_project_variables.html", "page-help-at-action-bar")
        open_project_variable_for_edit(@project, @numeric_plv.name)
        assert_help_link_on_page("modifying_or_deleting_project_variables.html", "page-help-at-action-bar")
        navigate_to_transition_management_for(@project)
        click_create_new_transition_link
        assert_help_link_on_page("creating_card_transitions.html", "page-help-at-action-bar")
        navigate_to_transition_management_for(@project)
        open_transition_for_edit(@project, @transition_with_comments_required.name)
        assert_help_link_on_page("modifying_or_deleting_card_transitions.html", "page-help-at-action-bar")
        open_wiki_page(@project, "wikipage")
        assert_help_link_on_page("working_with_pages.html", "page-help-at-action-bar")
        navigate_to_tree_configuration_management_page_for(@project)
        click_create_new_card_tree_link
        assert_help_link_on_page("creating_a_new_card_tree.html", "page-help-at-action-bar")
        navigate_to_property_management_page_for(@project)
        click_create_new_card_property
        assert_help_link_on_page("creating_card_properties.html", "page-help-at-action-bar")
        open_property_for_edit(@project, 'managed text')
        assert_help_link_on_page("modifying_or_deleting_card_properties.html", "page-help-at-action-bar")
        @browser.click_and_wait(class_locator("profile"))
        assert_help_link_on_page("managing_your_user_profile.html", "page-help-at-action-bar")

        @browser.click_and_wait(class_locator("profile"))
        @browser.click_and_wait("edit-profile")
        assert_help_link_on_page("edit_profile_page.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        click_import_from_excel
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        header_row = ['number', 'name', 'type']
        card_data = [['1', 'Release_1', 'Release'], ['2', 'Release_2', 'Release']]
        preview(excel_copy_string(header_row, card_data))
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")
    end

    def test_team_member_should_be_able_to_see_help_links
        login_as_project_member
        navigate_to_project_overview_page(@project)
        assert_help_link_on_page("project_overview_tab.html", "page-help")
        navigate_to_card_list_for(@project)
        @browser.wait_for_element_present "tree-and-style-selector"
        assert_help_link_on_page("card_list_page.html", "full-contextual-help-link")
        navigate_to_grid_view_for(@project)
        assert_help_link_on_page("card_grid_page.html", "full-contextual-help-link")
        navigate_to_hierarchy_view_for(@project, @planning_tree)
        assert_help_link_on_page("hierarchy_view.html", "help-at-style-selector")
        navigate_to_tree_view_for(@project, @planning_tree.name)
        assert_help_link_on_page("tree_view.html", "help-at-style-selector")
        open_card_for_edit(@project, @release_1)
        assert_help_link_on_page("updating_cards.html", "page-help-at-action-bar")
        open_wiki_page(@project, "wikipage")
        assert_help_link_on_page("working_with_pages.html", "page-help-at-action-bar")
        @browser.click_and_wait(class_locator("profile"))
        assert_help_link_on_page("managing_your_user_profile.html", "page-help-at-action-bar")

        @browser.click_and_wait(class_locator("profile"))
        @browser.click_and_wait("edit-profile")
        assert_help_link_on_page("edit_profile_page.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        click_import_from_excel
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")

        navigate_to_card_list_for(@project)
        header_row = ['number', 'name', 'type']
        card_data = [['1', 'Release_1', 'Release'], ['2', 'Release_2', 'Release']]
        preview(excel_copy_string(header_row, card_data))
        assert_help_link_on_page("import_export_component.html", "page-help-at-action-bar")
    end

    def test_read_only_user_should_be_able_to_see_help_links
        login_as_read_only_user
        navigate_to_project_overview_page(@project)
        assert_help_link_on_page("project_overview_tab.html", "page-help")
        navigate_to_card_list_for(@project)
        @browser.wait_for_element_present "tree-and-style-selector"
        assert_help_link_on_page("card_list_page.html", "full-contextual-help-link")
        navigate_to_grid_view_for(@project)
        assert_help_link_on_page("card_grid_page.html", "full-contextual-help-link")
        navigate_to_hierarchy_view_for(@project, @planning_tree)
        assert_help_link_on_page("hierarchy_view.html", "help-at-style-selector")
        navigate_to_tree_view_for(@project, @planning_tree.name)
        assert_help_link_on_page("tree_view.html", "help-at-style-selector")
        @browser.click_and_wait(class_locator("profile"))
        assert_help_link_on_page("managing_your_user_profile.html", "page-help-at-action-bar")

        @browser.click_and_wait(class_locator("profile"))
        @browser.click_and_wait("edit-profile")
        assert_help_link_on_page("edit_profile_page.html", "page-help-at-action-bar")

        navigate_to_all_wikis_page(@project)
        assert_help_link_on_page("pages_page.html", "page-help")
    end

    def test_anonymous_user_should_be_able_to_see_help_links
        enable_anonymous_access_for_project(@project)
        navigate_to_project_overview_page(@project)
        assert_help_link_on_page("project_overview_tab.html", "page-help")
        navigate_to_card_list_for(@project)
        @browser.wait_for_element_present "tree-and-style-selector"
        assert_help_link_on_page("card_list_page.html", "full-contextual-help-link")
        navigate_to_grid_view_for(@project)
        assert_help_link_on_page("card_grid_page.html", "full-contextual-help-link")
        navigate_to_hierarchy_view_for(@project, @planning_tree)
        assert_help_link_on_page("hierarchy_view.html", "help-at-style-selector")
        navigate_to_tree_view_for(@project, @planning_tree.name)
        assert_help_link_on_page("tree_view.html", "help-at-style-selector")
        navigate_to_all_wikis_page(@project)
        assert_help_link_on_page("pages_page.html", "page-help")

    end

    private
    def add_properties_for_project(project)
      project.activate
      create_property_for_card(MANAGED_TEXT_TYPE, MANAGED_TEXT)
      create_property_for_card(FREE_TEXT_TYPE, FREE_TEXT)
      create_property_for_card(MANAGED_NUMBER_TYPE, MANAGED_NUMBER)
      create_property_for_card(FREE_NUMBER_TYPE, FREE_NUMBER)
      create_property_for_card(USER_TYPE, USER)
      create_property_for_card(DATE_TYPE, DATE)
      create_property_for_card(CARD_TYPE, RELATED_CARD)
      @transition_only = create_property_for_card(MANAGED_NUMBER_TYPE, TRANSITION_ONLY)
      @transition_only.update_attribute(:transition_only, true)
    end

    def add_card_types_for_project(project)
      @type_release = setup_card_type(project, RELEASE, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
      @type_iteration = setup_card_type(project, ITERATION, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
      @type_task = setup_card_type(project, TASK, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
      @type_story = setup_card_type(project, STORY, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    end

    def add_cards_of_different_card_types_for_project(project)
       project.activate
       @release_1 = create_card!(:name => 'release 1', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => nil, USER => users(:project_member).id)
       @release_2 = create_card!(:name => 'release 2', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => @release_1, USER => users(:project_member).id)
       @iteration_1 = create_card!(:name => 'iteration 1', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
       @iteration_2 = create_card!(:name => 'iteration 2', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
       @story_1 = create_card!(:name => 'story 1', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
       @story_2 = create_card!(:name => 'story 2', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
       @tasks_1 = create_card!(:name => 'task 1', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
       @tasks_2 = create_card!(:name => 'task 2', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
       @special_card = project.cards.create!(:name => 'xyz', :card_type => @type_story, :cp_related_card => @release_1, :cp_free_text => "abcdefg")
     end

     def add_tree_and_card_for_project(project)
       @planning_tree = setup_tree(project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
       add_card_to_tree(@planning_tree, @release_1)
       add_card_to_tree(@planning_tree, @iteration_1, @release_1)
       add_card_to_tree(@planning_tree, @story_1, @iteration_1)
     end

     def add_normal_transtion_for_project(project)
       @transition_with_comments_required = create_transition(project, TRANSITION_1, :set_properties => {MANAGED_NUMBER => '2'}, :require_comment => true)
     end

     def add_transition_that_will_update_transition_only_property_for_project(project)
       @transition_that_will_update_transition_only_property = create_transition(project, TRANSITION_2, :set_properties => {TRANSITION_ONLY  => '3'}, :require_comment => true)
     end

end
