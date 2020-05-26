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

class Scenario155PersonalFavorites1Test < ActiveSupport::TestCase

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

  def test_should_show_help_links_for_personal_and_team_favorites
    create_personal_page_favorite(User.current, PERSONAL_FAV_1)
    create_team_page_favorite(FAVORITE)
    navigate_to_project_overview_page(@project)
    @browser.assert_element_present(css_locator("#favorites-container-team .component-help"))
    @browser.assert_element_present(css_locator("#favorites-container-personal .component-help"))
  end

  def test_mingle_admin_should_be_able_to_create_their_personal_favorite_on_any_card_views
    create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
    create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_2)
    create_personal_favorite_on_card_grid_view_with_card_filter(@project, PERSONAL_FAV_3)
    create_personal_favorite_on_card_grid_view_with_mql_filter(@project, PERSONAL_FAV_4)
    create_personal_favorite_on_card_tree_view(@project, PERSONAL_FAV_5)
    navigate_to_project_overview_page(@project)
    assert_personal_favorites_names_present(PERSONAL_FAV_1)
    assert_personal_favorites_names_present(PERSONAL_FAV_2)
    assert_personal_favorites_names_present(PERSONAL_FAV_3)
    assert_personal_favorites_names_present(PERSONAL_FAV_4)
    assert_personal_favorites_names_present(PERSONAL_FAV_5)
  end

  # Story 5523
  def test_user_can_view_personal_favorite_they_saved
    create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
    create_personal_favorite_on_card_grid_view_with_mql_filter(@project, PERSONAL_FAV_2)
    create_personal_favorite_on_card_tree_view(@project, PERSONAL_FAV_3)
    create_personal_favorite_on_card_grid_view_with_card_filter(@project, PERSONAL_FAV_4)
    navigate_to_project_overview_page(@project)
    open_my_favorite(PERSONAL_FAV_1)
    assert_cards_present_in_list(@release_1, @release_2)
    open_my_favorite(PERSONAL_FAV_2)
    assert_cards_present_in_grid_view(@release_1, @release_2)
    open_my_favorite(PERSONAL_FAV_3)
    assert_cards_showing_on_tree(@release_1, @iteration_1, @story_1)
    open_my_favorite(PERSONAL_FAV_4)
    assert_cards_present_in_grid_view(@release_1, @release_2)
    go_to_profile_page
    open_tab_on_profile_page("My Favorites")
    open_my_favorite(PERSONAL_FAV_4)
    assert_cards_present_in_grid_view(@release_1, @release_2)
  end

  def test_read_only_user_should_not_see_my_favorite_section
    as_read_only_user do
      navigate_to_card_list_for(@project)
      assert_my_favorites_drop_down_not_present
    end
  end

  def test_anon_user_should_not_see_my_favorite_section
    as_anon_user do
      register_and_enable_anonymous_accessible(@project)
      navigate_to_card_list_for(@project)
      assert_my_favorites_drop_down_not_present
    end
  end

  def test_users_cannot_see_each_others_personal_favorite
    User.with_current(@mingle_admin) do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
    end

    as_user('member') do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_2)
    end

    as_user('proj_admin') do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
      create_personal_favorite_on_card_grid_view_with_card_filter(@project, PERSONAL_FAV_3)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_3)
      assert_personal_favorites_names_not_present(PERSONAL_FAV_1, PERSONAL_FAV_2)
    end

    as_user('admin') do
      navigate_to_card_list_for(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
      assert_personal_favorites_names_not_present(PERSONAL_FAV_2, PERSONAL_FAV_3)
    end
  end

  def test_if_team_member_is_removed_from_team_then_his_personal_favorite_will_be_also_removed
    as_user('member') do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
    end

    as_user('admin') do
      remove_user_from_team_and_add_it_back_as_full_team_member(@project, @full_team_member)
    end

    as_user('member') do
      navigate_to_card_list_for(@project)
      assert_no_personal_favorite_for_current_user
    end
  end

  def test_if_user_is_deactived_his_personal_favorite_will_be_kept_and_availale_when_he_is_reactived
    as_user('proj_admin') do
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_2)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_2)
    end

    as_user('admin') do
      deactive_user(@project_admin)
      active_user(@project_admin)
    end

    as_user('proj_admin') { assert_personal_favorites_names_present(PERSONAL_FAV_2) }
  end

  def test_if_project_admin_become_a_read_only_team_member_his_personal_favorite_will_not_available


    as_user('proj_admin') { create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1) }

    as_user('admin') do
      navigate_to_team_list_for(@project)
      make_read_only(@project_admin)
    end

    as_user('proj_admin') { should_not_see_my_favorite_section }

    as_user('admin') do
      navigate_to_team_list_for(@project)
      make_full_member(@project_admin)
    end

    as_user('proj_admin') { assert_personal_favorites_names_present(PERSONAL_FAV_1) }

    as_user('admin') do
      navigate_to_team_list_for(@project)
      make_project_admin(@project_admin)
    end

    as_user('proj_admin') { assert_personal_favorites_names_present(PERSONAL_FAV_1) }
  end

  def test_mingle_admin_can_always_see_his_personal_favorite

    as_admin do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
      add_to_team_as_project_admin_for(@project, @mingle_admin)
      navigate_to_card_list_for(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
      navigate_to_team_list_for(@project)
      make_read_only(@mingle_admin)
      navigate_to_card_list_for(@project)
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
    end
  end

  def test_mingle_admin_will_lost_his_personal_favorite_if_he_is_not_mingle_admin_anymore

    as_admin do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_1)
      add_to_team_as_project_admin_for(@project, @mingle_admin)
    end

    as_admin_not_on_project do
      revoke_mingle_admin_for_user(@mingle_admin)
    end

    as_admin do
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
    end

    as_proj_admin do
      navigate_to_team_list_for(@project)
      make_read_only(@mingle_admin)
    end

    as_admin do
      navigate_to_card_list_for(@project)
      should_not_see_my_favorite_section
    end

    as_proj_admin do
      navigate_to_team_list_for(@project)
      make_full_member(@mingle_admin)
    end

    as_admin do
      assert_personal_favorites_names_present(PERSONAL_FAV_1)
    end
  end

  def test_user_can_create_personal_favorite_that_has_same_name_as_team_favorites
    as_admin do
      create_team_favorite_on_card_list_view_with_card_filter(@project, FAVORITE)
      create_personal_favorite_on_card_list_view_with_card_filter(@project, FAVORITE)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(FAVORITE)
    end

    as_proj_admin do
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, FAVORITE)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(FAVORITE)
    end

    as_project_member do
      create_personal_favorite_on_card_grid_view_with_card_filter(@project, FAVORITE)
      navigate_to_project_overview_page(@project)
      assert_personal_favorites_names_present(FAVORITE)
    end
  end

  def test_link_to_update_existing_personal_favorite_should_not_be_escaped
    # When the link is escaped it results in a new favorite being created with the escaped name

    as_admin do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, '<b>123</b>')
      navigate_to_project_overview_page(@project)
      open_my_favorite('<b>123</b>')
      set_the_filter_value_option(0, 'Story')
      update_my_favorite_for(1)
      assert_number_of_personal_favorites(1)
    end
  end

  def test_user_can_update_existing_personal_favorite
    as_admin do
      create_personal_favorite_on_card_list_view_with_card_filter(@project, FAVORITE)
      navigate_to_project_overview_page(@project)
      open_my_favorite(FAVORITE)
      set_the_filter_value_option(0, 'Story')
      update_my_favorite_for(1)
      open_my_favorite(FAVORITE)
      assert_cards_present_in_list(@story_1, @story_2)
    end
  end

  def test_should_not_see_personal_favorite_on_team_favorite_management_page
    as_admin do
      create_team_favorite_on_card_list_view_with_card_filter(@project, FAVORITE)
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_1)
      navigate_to_favorites_management_page_for(@project)
      assert_text_not_present(PERSONAL_FAV_1)
    end
  end

  def test_should_not_have_manage_favorites_and_tabs_link_in_personal_favorite_section
    as_admin do
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_1)
      navigate_to_project_overview_page(@project)
      should_see_manage_favorite_and_tabs_link_in_personal_favorite_section
    end
  end

  #Manage personal favorite
  def test_user_can_manage_their_personal_favorites_on_profile_page

    as_admin do
      create_personal_favorite_on_card_list_view_with_mql_filter(@project, PERSONAL_FAV_1)
      create_personal_favorite_on_card_list_view_with_card_filter(@project, PERSONAL_FAV_2)
      create_personal_favorite_on_card_grid_view_with_card_filter(@project, PERSONAL_FAV_3)
      create_personal_favorite_on_card_grid_view_with_mql_filter(@project, PERSONAL_FAV_4)
      create_personal_favorite_on_card_tree_view(@project, PERSONAL_FAV_5)
      go_to_profile_page
      should_see_personal_favorite_on_profile_page(1, @project.name, PERSONAL_FAV_1, "list")
      should_see_personal_favorite_on_profile_page(2, @project.name, PERSONAL_FAV_2, "list")
      should_see_personal_favorite_on_profile_page(3, @project.name, PERSONAL_FAV_3, "grid")
      should_see_personal_favorite_on_profile_page(4, @project.name, PERSONAL_FAV_4, "grid")
      should_see_personal_favorite_on_profile_page(5, @project.name, PERSONAL_FAV_5, "tree")
      delete_personal_favorite(1)
      assert_personal_favorite_delete_message(PERSONAL_FAV_1)
    end
  end

end
