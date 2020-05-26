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

# Tags: scenario, new_user_role, user, anonymous
class Scenario106AnonUserUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  TAG = 'tagged'
  OWNER = 'owner'
  STATUS = 'status'
  CURRENT_USER = '(current user)'
  OPEN = 'open'
  CLOSED = 'close'
  TYPE = 'Type'
  CARD = 'Card'
  CARD_NAME = 'plain card'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @mingle_admin = users(:admin)
    register_license_that_allows_anonymous_users
    @project = create_project(:prefix => 'scenario_106', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :anonymous_accessible => true)
  end

  #bug 8162
  def test_should_allow_anon_user_to_go_directly_to_a_card_url
    card = with_first_admin { create_card!(:name => 'this is not a very confidential card') }

    as_anon_user do
      open_card(@project, card)
      assert_equal "this is not a very confidential card", @browser.get_text(css_locator("#card-short-description"))
    end
  end

  def test_anon_user_can_add_remove_lanes_or_columns_in_grid_or_list_view
    with_first_admin do
      create_card!(:name => 'first card')
      setup_property_definitions(STATUS => [OPEN, CLOSED])
    end
    as_anon_user do
      navigate_to_grid_view_for(@project)
      group_columns_by(STATUS)
      assert_lane_not_present(STATUS,OPEN)
      add_lanes(@project, STATUS,[OPEN])
      assert_lane_present(STATUS,OPEN)

      navigate_to_card_list_for(@project)
      add_column_for(@project, [TYPE])
      assert_column_present_for(TYPE)
    end
  end

  #bug 5226
  def test_we_should_never_show_an_error_about_not_having_rights_to_a_resource_on_the_login_page
    new_project = with_first_admin { create_project(:name => 'not allow anno user', :users => [@team_member], :admins => [@mingle_admin, @project_admin]) }

    as_anon_user do
      @browser.open("/projects/#{new_project.identifier}")
      assert_error_message_not_present
    end

    as_admin do
      navigate_to_project_admin_for(@project)
      click_show_advanced_options_link
      disable_project_anonymous_accessible_on_project_admin_page
    end

    as_anon_user do
      @browser.open("/projects/#{new_project.identifier}")
      assert_error_message_not_present
    end
  end

  def test_anon_user_should_be_redirected_to_projects_list_if_enterprise_and_projects_are_anon_accessible
    @new_project = create_project(:name => 'for_anon_user', :users => [@team_member], :admins => [@mingle_admin], :anonymous_accessible => true)
    register_limited_license_that_allows_anonymous_users(100,100)
    as_anon_user do
      click_on_mingle_logo
      assert_located_at_project_list_page
    end
  end

  def test_on_anon_user_should_only_see_cross_project_macro_when_all_related_project_are_anon_accessible
    as_admin do
      @new_project = create_project(:name => 'for_anon_user', :users => [@team_member], :admins => [@mingle_admin], :anonymous_accessible => true)
      setup_property_definitions(STATUS => [OPEN, CLOSED])
      setup_user_definition(OWNER)
      card1 = create_card!(:name => 'card1', OWNER => @mingle_admin.id, STATUS  => OPEN)
      open_overview_page_for_edit(@project)
      @table_query = add_table_query_and_save_for_cross_project([STATUS, OWNER], ["#{TYPE} = #{CARD}"], @new_project)
    end

    as_anon_user do
      navigate_to_project_overview_page(@project)
      assert_table_row_data_for(@table_query, :row_number => 1, :cell_values => ["#{OPEN}", "#{@mingle_admin.name_and_login}"])
    end

    as_admin do
      navigate_to_project_admin_for(@new_project)
      disable_project_anonymous_accessible_on_project_admin_page
    end

    as_anon_user do
      navigate_to_project_overview_page(@project)
      assert_cross_project_reporting_restricted_message_for(@new_project)
    end
  end

  def test_current_user_in_fileter_shoule_not_match_anything_for_anon_user
    as_proj_admin do
      setup_user_definition(OWNER)
      @mingle_admin_card = create_card!(:name => 'card1', OWNER => @mingle_admin.id)
      @pro_admin_card = create_card!(:name => 'card2', OWNER => CURRENT_USER)
      @other_card = create_card!(:name => 'card3')
      navigate_to_card_list_for(@project)
      add_new_filter
      set_the_filter_property_and_value(1, :property => OWNER, :value => "#{@mingle_admin.name}")
      add_new_filter
      set_the_filter_property_and_value(2, :property => OWNER, :value => CURRENT_USER)
      @favorite = create_card_list_view_for(@project, 'view')
      assert_card_present_in_list(@mingle_admin_card)
      assert_card_present_in_list(@pro_admin_card)
    end

    as_anon_user do
      navigate_to_card_list_for(@project)
      assert_card_favorites_link_present(@favorite.name)
      open_saved_view(@favorite.name)
      assert_card_present_in_list(@mingle_admin_card)
      assert_card_not_present_in_list(@pro_admin_card)
    end
  end

  def test_sign_off_should_go_to_project_list_page_or_login_page
    as_admin do
      @new_project = create_project(:name => 'for_anon_user', :users => [@team_member], :admins => [@mingle_admin])
      navigate_to_card_list_for(@project)
    end

    # as_anon_user do
      assert_located_at_project_list_page
      assert_project_link_present(@project)
    # end
    #
    # as_admin do
    #   navigate_to_project_admin_for(@project)
    #   disable_project_anonymous_accessible_on_project_admin_page
    # end
    #
    # assert_located_at_login_page
  end

  def test_without_anonymous_access_project_anon_user_should_be_promoted_to_login
    as_admin do
      navigate_to_project_admin_for(@project)
      disable_project_anonymous_accessible_on_project_admin_page
    end

    as_anon_user do
      navigate_to_all_projects_page
      assert_located_at_login_page
    end
  end

  def test_anon_user_could_access_anon_user_acessible_project_via_URL
    as_admin do
      @project = create_project(:name => 'for_anon_user', :users => [@team_member], :admins => [@mingle_admin], :anonymous_accessible => true)
      @cards = create_cards(@project, 1)
    end

    as_anon_user do
      open_card(@project, @cards[0])
      assert_card_name_in_show(@cards[0].name)
      assert_not_logged_in
    end
  end

  def test_logged_in_user_could_access_other_anon_user_accessible_project_which_he_does_not_belong_to
    as_admin do
      @new_project = create_project(:name => 'for_anon_user', :users => [@team_member], :admins => [@project_admin], :anonymous_accessible => true)
    end

    as_anon_user do
      navigate_to_all_projects_page
      assert_project_link_present(@project)
      assert_project_link_present(@new_project)

      open_project(@new_project)
      assert_via_email_not_present
      navigate_to_project_admin_for(@new_project)
      assert_export_and_export_as_template_not_present
      navigate_to_team_list_for(@new_project)
      assert_table_column_headers_and_order('users', 'Display name', 'Sign-in name', 'Permissions', 'User groups')
    end

    as_proj_admin do
      navigate_to_all_projects_page
      assert_project_link_present(@project)
      assert_project_link_present(@new_project)

      open_project(@new_project)
      assert_via_email_not_present
      navigate_to_project_admin_for(@new_project)
      assert_export_and_export_as_template_present
      navigate_to_team_list_for(@new_project)
      assert_table_column_headers_and_order('users', '', 'Display name', 'Sign-in name', 'Email', 'Permissions', 'User groups')
    end
  end

  def test_expired_license_only_make_project_list_read_only_for_anon_user
    as_admin do
      @new_project = create_project(:prefix => 'annon', :users => [@team_member], :admins => [@mingle_admin], :read_only_users => [@read_only_user], :anonymous_accessible => true)
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    register_expired_license_that_allows_anonymous_users

    as_admin do
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    as_project_member do
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    as_proj_admin do
      navigate_to_all_projects_page
      assert_license_expired_message
      assert_project_link_present(@project)
      assert_project_in_list_not_linkable(@new_project.name)
    end

    as_read_only_user do
      navigate_to_all_projects_page
      assert_license_expired_message
      assert_project_link_present(@new_project)
      assert_project_in_list_not_linkable(@project.name)
    end

    as_anon_user do
      navigate_to_all_projects_page
      assert_license_expired_message
      assert_project_in_list_not_linkable(@new_project.name)
      assert_project_in_list_not_linkable(@project.name, 1)
    end
  end

  def test_license_violations_only_make_project_list_read_only_for_anon_user
    as_admin do
      @new_project = create_project(:prefix => 'annon', :users => [@team_member], :admins => [@mingle_admin], :read_only_users => [@read_only_user], :anonymous_accessible => true)
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    register_limited_license_that_allows_anonymous_users(8,3)

    as_admin do
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    as_project_member do
      navigate_to_all_projects_page
      assert_project_links_present(@new_project, @project)
    end

    as_proj_admin do
      navigate_to_all_projects_page
      assert_license_violations_message_caused_by_too_many_users(8,13)
      assert_project_link_present(@project)
      assert_project_in_list_not_linkable(@new_project.name)
    end

    as_read_only_user do
      navigate_to_all_projects_page
      assert_license_violations_message_caused_by_too_many_users(8,13)
      assert_project_link_present(@new_project)
      assert_project_in_list_not_linkable(@project.name)
    end

    as_anon_user do
      navigate_to_all_projects_page
      assert_license_violations_message_caused_by_too_many_users(8,13)
      assert_project_in_list_not_linkable(@new_project.name)
      assert_project_in_list_not_linkable(@project.name, 1)
    end
  end


  def test_advanced_admin_page_is_not_visiable_for_anonymous_user
    as_anon_user do
      open_project_admin_for(@project)
      assert_advanced_project_admin_link_is_not_present
    end
  end

  #bug 4633
  def test_info_messages_for_no_overview_and_no_cards_in_project_for_anon_user
    as_anon_user do
      navigate_to_project_overview_page(@project)
      assert_info_message("This project does not have an overview page")
      click_all_tab
      assert_info_message("There are no cards for #{@project.name}")
    end
  end

  #bug 4658
  def ignored_test_do_not_show_special_headerlinks_to_logged_in_readonly_user_access_anon_project
   as_admin do
     @new_project = create_project(:name  => 'project 1', :read_only_user  => [@read_only_user])
     create_special_header_for_creating_new_card(@project, CARD)
    end

    as_read_only_user do
     navigate_to_project_overview_page(@project)
     assert_special_header_not_present(CARD)
    end
  end

  #bug 5226
  def test_should_redirect_to_login_page_if_user_has_not_logged_in_but_try_to_access_one_project
    @non_anon_project = create_project(:prefix => 'non_anon', :users => [@team_member])
    @browser.open("/projects/#{@non_anon_project.identifier}")
    assert_current_url("/profile/login?project_id=#{@non_anon_project.identifier}")

    as_project_member do
      assert_current_url("/projects/#{@non_anon_project.identifier}/overview")
    end
  end

  # bug 5506
  def test_logging_into_anon_accessible_project_direct_user_to_the_project_overview
    @new_project = create_project(:prefix => 'bug_5506_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :anonymous_accessible => true)

    open_project(@new_project)

    as_admin do
      assert_located_project_overview(@new_project)
    end

    logout
    open_project(@new_project)

    as_project_member do
      assert_located_project_overview(@new_project)
    end
  end

  #6126
  def test_anon_user_should_be_returned_to_the_page_he_was_looking_at_before_sign_in
    card_1 = User.with_first_admin { create_card!(:name => CARD_NAME) }
    open_card(@project, card_1.number)
    assert_current_url("/projects/#{@project.identifier}/cards/#{card_1.number}")
    click_link('Sign in')
    @browser.type "user_login", 'admin'
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    assert_card_name_in_show(CARD_NAME)
    assert_current_url("/projects/#{@project.identifier}/cards/#{card_1.number}?tab=All")
  end

  # bug 6230
  def test_anon_user_should_not_be_able_to_see_ranking_turn_on_off_button
    card_1 = User.with_first_admin { create_card!(:name => CARD_NAME) }
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_not_present
  end

  def test_anon_user_should_not_be_able_to_see_quick_add_card
    as_anon_user do
      navigate_to_grid_view_for(@project)
      assert_quick_add_card_is_invisible
    end
  end

end
