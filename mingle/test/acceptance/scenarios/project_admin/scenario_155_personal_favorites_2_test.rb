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

require File.expand_path('../../../acceptance/acceptance_test_helper', File.dirname(__FILE__))
require File.expand_path('personal_favorites_acceptance_support.rb', File.dirname(__FILE__))

#Tags: users, project

class Scenario155PersonalFavorites2Test < ActiveSupport::TestCase

  include PersonalFavoritesAcceptanceSupport
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @full_team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    login_as_admin_user
    @project = create_project(:prefix => 'scenario_155', :admins => [users(:proj_admin)], :users => [users(:project_member)], :read_only_users => [users(:read_only_user)])
    add_properties_for_project(@project)
    add_card_types_for_project(@project)
    add_cards_of_different_card_types_for_project(@project)
    add_tree_and_card_for_project(@project)
    create_new_wiki_page_via_model @project, PAGE_NAME, 'some text'
  end

  def test_personal_favorites_that_user_have_in_all_projects_should_be_ordered_on_profile_page
    another_project = create_project(:prefix => 'a_project_with_cards', :admins => [users(:proj_admin)], :users => [users(:project_member)], :read_only_users => [users(:read_only_user)])
    add_properties_for_project(another_project)
    add_card_types_for_project(another_project)
    add_cards_of_different_card_types_for_project(another_project)

    as_admin do
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_1)
      create_personal_favorite_on_card_grid_view_with_card_filter(another_project, PERSONAL_FAV_2)
      reload_current_page
      go_to_profile_page
      should_see_personal_favorite_on_profile_page(1, another_project.name, PERSONAL_FAV_2, "grid")
      should_see_personal_favorite_on_profile_page(2, @project.name, PERSONAL_FAV_1, "list")
    end
  end

  #Story 8394 -  Allow admin to delete team member's favorite.
  def test_mingle_or_project_admin_can_delete_team_members_personal_favorite

    as_project_member do
      create_personal_favorite_using_mql_condition(@project, "'#{MANAGED_NUMBER}' = 1", PERSONAL_FAV_1)
      create_personal_favorite_using_mql_condition(@project, "'#{FREE_TEXT}' = a", PERSONAL_FAV_2)
    end

    as_admin do
      navigate_to_property_management_page_for(@project)
      click_delete_link_of_property(@project, MANAGED_NUMBER)
      assert_text_present("Any personal favorites using this property will be deleted too.")
      click_continue_to_delete_link
    end

    as_project_member do
      assert_personal_favorites_names_present(PERSONAL_FAV_2)
      assert_personal_favorites_names_not_present(PERSONAL_FAV_1)
    end

    as_proj_admin do
      navigate_to_property_management_page_for(@project)
      click_delete_link_of_property(@project, FREE_TEXT)
      assert_text_present("Any personal favorites using this property will be deleted too.")
      click_continue_to_delete_link
    end

    as_project_member do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
    end
  end

  def test_mingle_or_project_admin_can_hide_on_property_that_used_by_someones_personal_favorite

    as_project_member do
      create_personal_favorite_using_mql_condition(@project, "'#{MANAGED_NUMBER}' = 1", PERSONAL_FAV_1)
      create_personal_favorite_using_mql_condition(@project, "'#{FREE_TEXT}' = a", PERSONAL_FAV_2)
    end

    as_admin do
      navigate_to_property_management_page_for(@project)
      hide_property(@project, "#{MANAGED_NUMBER}", :stop_at_confirmation => true)
      assert_text_present("In addition, any personal favorites using this property will be deleted.")
      click_hide_property_link
      assert_text_present("Property #{MANAGED_NUMBER} is now hidden. The following favorites have been deleted: #{PERSONAL_FAV_1}.")
    end

    as_project_member do
      assert_personal_favorites_names_present(PERSONAL_FAV_2)
      assert_personal_favorites_names_not_present(PERSONAL_FAV_1)
    end

    as_proj_admin do
      navigate_to_property_management_page_for(@project)
      navigate_to_property_management_page_for(@project)
      hide_property(@project, "#{FREE_TEXT}", :stop_at_confirmation => true)
      assert_text_present("In addition, any personal favorites using this property will be deleted.")
      click_hide_property_link
      assert_text_present("Property #{FREE_TEXT} is now hidden. The following favorites have been deleted: #{PERSONAL_FAV_2}.")
    end

    as_project_member do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
    end
  end

  def test_mingle_admin_can_delete_a_tree_which_is_used_by_someones_personal_favorite

    as_project_member { create_personal_favorite_using_tree_filter(@project, PERSONAL_FAV_1) }
    as_admin do
      click_delete_link_for(@project, @planning_tree)
      assert_warning_box_present
      assert_text_present("Any favorites and tabs that use this tree or its properties will be deleted.")
      click_on_continue_to_delete_link
      assert_text_present("Card tree #{@planning_tree.name} has been deleted.")
    end

    as_project_member do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
    end
  end

  def test_project_admin_can_delete_a_tree_which_is_used_by_someones_personal_favorite


    as_project_member { create_personal_favorite_using_tree_filter(@project, PERSONAL_FAV_1) }

    as_proj_admin do
      click_delete_link_for(@project, @planning_tree)
      assert_warning_box_present
      assert_text_present("Any favorites and tabs that use this tree or its properties will be deleted.")
      click_on_continue_to_delete_link
      assert_text_present("Card tree #{@planning_tree.name} has been deleted.")
    end

    as_project_member {
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
    }
  end

  def test_project_admin_can_bulk_delete_cards_which_are_invoked_by_tree_property_and_used_by_someones_personal_favorite

    as_project_member { create_personal_favorite_using_tree_filter(@project, PERSONAL_FAV_1) }

    as_proj_admin do
      navigate_to_card_list_for(@project)
      select_all
      click_bulk_delete_button
      assert_text_present("Any personal favorites that use these cards may not work as expected.")
      click_confirm_bulk_delete
      assert_text_present("Cards deleted successfully.")
    end
  end

  def test_mingle_admin_can_delete_one_card_which_is_invoked_by_tree_property_and_used_by_someones_personal_favorite

    as_project_member { create_personal_favorite_using_tree_filter(@project, PERSONAL_FAV_1) }

    as_proj_admin do
      navigate_to_card_list_for(@project)
      select_cards([@release_1])
      click_bulk_delete_button
      assert_text_present("Any personal favorites that use this card may not work as expected.")
      click_confirm_bulk_delete
      assert_text_present("Card deleted successfully.")
    end
  end

  def test_mingle_admin_can_delete_one_card_which_used_as_card_type_property_value_and_used_by_someones_personal_favorite
    as_project_member { create_personal_favorite_using_card_type_property(@project, PERSONAL_FAV_1) }

    as_admin do
      navigate_to_card_list_for(@project)
      select_cards([@release_1])
      click_bulk_delete_button
      assert_text_present("Any personal favorites that use this card may not work as expected.")
      click_confirm_bulk_delete
      assert_text_present("Card deleted successfully.")
    end
  end

  def test_mingle_admin_can_delete_one_plv_which_used_by_someones_personal_favorite
    User.with_current(@mingle_admin) do
      create_number_plv(@project, PLV_NAME, '3', [@project.all_property_definitions.find_by_name(MANAGED_NUMBER), @project.all_property_definitions.find_by_name(FREE_NUMBER)])
    end

    User.with_current(@full_team_member) do
      create_personal_favorite_using_numeric_plv(@project, PERSONAL_FAV_1)
    end

    as_admin do
      delete_project_variable(@project, 'plv')
      assert_text_present("In addition, any personal favorites using this project variable will be deleted")
      click_continue_to_delete
      assert_notice_message("Project variable plv was successfully deleted")
    end

  end

  def test_admin_and_teammember_should_be_able_to_create_personal_page_favorite
    [@mingle_admin, @project_admin, @full_team_member].each do |user|
      login_as(user.login)
      create_personal_page_favorite(User.current, PAGE_NAME)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(PAGE_NAME)
    end
  end

  def test_user_should_be_able_to_delete_personal_page_favorite
    as_admin do
      create_personal_page_favorite(User.current, PAGE_NAME)
      go_to_profile_page
      should_see_personal_favorite_on_profile_page(1, @project.name, PAGE_NAME, 'wiki')
      delete_personal_favorite(1)
      assert_personal_favorite_delete_message(PAGE_NAME)
    end
  end

  def test_readonly_user_should_not_be_able_to_create_personal_page_favorite
    as_read_only_user do
      open_wiki_page(@project, PAGE_NAME)
      should_not_see_my_favorite_section
    end
  end

  def test_mingle_admin_should_be_able_to_delete_others_personal_page_favorite
    User.with_current(@full_team_member) do
      create_personal_page_favorite(User.current, PAGE_NAME)
    end

    as_admin do
      open_show_profile_for(@full_team_member)
      should_see_personal_favorite_on_profile_page(1, @project.name, PAGE_NAME, 'wiki')
      delete_personal_favorite(1)
      assert_personal_favorite_delete_message(PAGE_NAME)
    end
  end

end
