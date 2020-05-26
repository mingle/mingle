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

#Tags: user, subscriptions, profile
class Scenario161HistorySubscriptionManagementTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STORY = 'story'
  BUG = 'bug'
  DEFECT = 'defect'
  STATUS = 'status'
  STORY_STATUS = 'story status'
  BY_DESIGN_TAG = 'by design'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session

    @project_member = User.find_by_login('member')
    @admin = User.find_by_login('admin')
    @project = create_project(:prefix => 'project_161', :admins => [@admin], :users => [@project_member])
    login_as_project_member
  end

  def test_user_can_see_different_types_of_subscription_on_profile_page
    user_have_different_subscriptions_from_one_project
    user_go_to_his_profile_page
    should_see_all_the_subscription
  end

  def test_user_can_unsubscribe_card_on_profile_page
    user_subscribe_to_one_card
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('card', 0)
    @browser.assert_element_not_present(css_locator("table#card_subscriptions a[onclick]",0))
    @browser.assert_text_present("You have successfully unsubscribed from Card ##{@card_been_subscribed.number} #{@card_been_subscribed.name}")
    open_card(@project, @card_been_subscribed.number)
    assert_current_content_subscribable
  end

  #bug7705
  def test_should_create_correct_card_link_in_warning_message_when_deleting_a_card_subscription
    @project.activate
    create_cards(@project, 22)
    open_card(@project, 22)
    @browser.with_ajax_wait { @browser.click("link=via email") }
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('card', 0)
    @browser.assert_element_not_present(css_locator("table#card_subscriptions a[onclick]",0))
    @browser.assert_text_present("You have successfully unsubscribed from Card #22")
    @browser.assert_element_present("link=#22")
  end

  #bug 7264
  def test_hash_and_card_number_should_be_shown_as_a_link_on_unsubscribe_notice_message
    user_subscribe_to_one_card
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('card', 0)
    @browser.assert_element_present("link=##{@card_been_subscribed.number}")
    click_link("##{@card_been_subscribed.number}")
    assert_on_card(@project, @card_been_subscribed)
  end

  def test_user_can_unsubscribe_page_on_profile_page
    @page_been_subscribed = "check page subscription"
    create_new_wiki_page(@project, @page_been_subscribed, "content")
    click_subscribe_via_email
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('page', 0)
    @browser.assert_element_not_present(css_locator("table#page_subscriptions a[onclick]",0))
    @browser.assert_text_present("You have successfully unsubscribed from #{@page_been_subscribed} page.")
    open_wiki_page(@project, @page_been_subscribed)
    assert_current_content_subscribable
  end

  def test_user_can_unsubscribe_history_on_profile_page

    navigate_to_history_for(@project)
    click_type_for_history_filtering('pages')
    click_subscribe_via_email
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('global', 0)
    @browser.assert_element_not_present(css_locator("table#global_subscriptions a[onclick]",0))
    @browser.assert_text_present("You have successfully unsubscribed from #{@project.name} history")
    navigate_to_history_for(@project)
    click_type_for_history_filtering('pages')
    assert_current_content_subscribable
  end

  def test_admin_can_see_other_users_subscriptions
    user_have_different_subscriptions_from_one_project
    login_as("admin")
    open_show_profile_for(@project_member)
    should_see_all_the_subscription
  end

  def test_admin_should_be_able_to_unsubscribe_users_subscription
    user_have_different_subscriptions_from_one_project
    login_as("admin")
    open_show_profile_for(@project_member)
    click_unsubscribe_on_subscriptions_table('card', 0)
    click_unsubscribe_on_subscriptions_table('page', 0)
    click_unsubscribe_on_subscriptions_table('global', 0)
    login_as_project_member
    user_go_to_his_profile_page
    user_should_no_longer_see_his_subscriptions_from_the_project
    open_card(@project, @card_been_subscribed.number)
    assert_current_content_subscribable
    open_wiki_page(@project, @page_been_subscribed)
    assert_current_content_subscribable
    navigate_to_history_for(@project)
    click_type_for_history_filtering('pages')
    assert_current_content_subscribable
  end

  def test_card_subscriptions_would_be_updated_when_user_update_card_name
    user_subscribe_to_one_card
    @new_card_name = 'change to new name'
    open_card(@project, @card_been_subscribed.number)
    edit_card(:name => @new_card_name)
    user_go_to_his_profile_page
    assert_card_name_on_subscription_page(2,@new_card_name)
  end

  def test_subscription_would_be_updated_when_user_update_project_name
    user_have_different_subscriptions_from_one_project
    @new_project_name = "new project name"
    login_as("admin")
    open_project_admin_for(@project)
    type_project_name(@new_project_name)
    click_save_link
    login_as_project_member
    user_go_to_his_profile_page
    assert_project_name_on_subscription_table('card', 2, @new_project_name)
    assert_project_name_on_subscription_table('page', 2, @new_project_name)
    assert_project_name_on_subscription_table('global', 2, @new_project_name)
  end

  def test_subscription_table_can_show_details_of_complex_subscription
    user_subscribe_to_stories_changed_to_new_by_admin
    user_go_to_his_profile_page
    assert_content_on_subscription_table('global', 2, 2, "#{STATUS} is newType is #{STORY}")
    assert_content_on_subscription_table('global', 2, 4, "#{@admin.name}")
  end

  def test_update_card_type_property_user_name_will_also_update_content_in_subscription_table
    user_subscribe_to_stories_changed_to_new_by_admin

    login_as("admin")
    edit_card_type_for_project(@project, BUG, :new_card_type_name => DEFECT)
    edit_property_definition_for(@project, STATUS, :new_property_name => STORY_STATUS)
    open_edit_profile_for(@admin)
    @browser.type('user_name', 'new name')
    click_save_profile_button
    login_as_project_member
    user_go_to_his_profile_page
    assert_content_on_subscription_table('global', 2, 2, "#{STORY_STATUS} is newType is #{STORY}")
    assert_content_on_subscription_table('global', 2, 4, "new name")
  end

  def user_subscribe_to_stories_changed_to_new_by_admin
    bug_type = setup_card_type(@project, BUG)
    story_type = setup_card_type(@project, STORY)
    property = setup_managed_text_definition(STATUS, ['new', 'open', 'closed'])
    status = property.update_attributes(:card_types => [story_type])
    @project.activate
    navigate_to_history_for(@project)
    click_type_for_history_filtering('cards')
    filter_history_using_first_condition_by @project, 'type' => STORY, STATUS => 'new'
    filter_history_by_team_member(@admin)
    click_subscribe_via_email
  end

  def test_user_will_lose_his_subscription_in_following_situations
    Outline(<<-Examples) do | admin_does_different_things                     |
      | { admin_remove_user_from_the_project }          |
      | { admin_delete_that_project }                   |
      | { admin_deactivate_user_and_then_activate_him } |
      Examples

      user_have_different_subscriptions_from_one_project
      admin_does_different_things.happened
      user_go_to_his_profile_page
      user_should_no_longer_see_his_subscriptions_from_the_project
    end
  end

  def test_subscriptions_are_grouped_by_project
    @p_project = @project
    user_have_different_subscriptions_from_one_project
    user_have_different_subscriptions_from_one_project(:new_page_name => 'page to test group by project',:only_show_to => 'cards')
    @q_project = create_project(:prefix => 'qroject_142', :admins => [@admin], :users => [@project_member])
    @project = @q_project
    user_have_different_subscriptions_from_one_project
    user_have_different_subscriptions_from_one_project(:new_page_name => 'page to test group by project',:only_show_to => 'cards')
    @project = @p_project
    user_go_to_his_profile_page
    assert_project_name_on_subscription_table('card', 2, @p_project.name)
    assert_project_name_on_subscription_table('card', 3, @p_project.name)
    assert_project_name_on_subscription_table('card', 4, @q_project.name)
    assert_project_name_on_subscription_table('card', 5, @q_project.name)
    assert_project_name_on_subscription_table('page', 2, @p_project.name)
    assert_project_name_on_subscription_table('page', 3, @p_project.name)
    assert_project_name_on_subscription_table('page', 4, @q_project.name)
    assert_project_name_on_subscription_table('page', 5, @q_project.name)
    assert_project_name_on_subscription_table('global', 2, @p_project.name)
    assert_project_name_on_subscription_table('global', 3, @p_project.name)
    assert_project_name_on_subscription_table('global', 4, @q_project.name)
    assert_project_name_on_subscription_table('global', 5, @q_project.name)
  end

  #bug 8309
  def test_user_with_no_subscriptions_should_see_a_correct_message_on_their_profile_page
    user_go_to_his_profile_page
    assert_table_values("global_subscriptions", 1, 0, "There are currently no subscriptions to list.")
  end

  #bug 8004 sce 1
  def test_should_be_able_to_edit_profile_of_user_who_has_subscriptions_after_a_project_is_deleted
    login_as_admin_user
    @another_project = create_project(:prefix => 'another proj', :admins => [@admin], :users => [@project_member])
    navigate_to_all_projects_page
    delete_project_permanently(@another_project)

    login_as_project_member
    user_subscribe_to_one_card
    user_go_to_his_profile_page
    assert_card_subscription_present(2,@card_been_subscribed.number)
  end

  #bug 8004 sce 2
  def test_should_be_able_to_edit_profile_of_user_who_has_subscription_in_a_deleted_project
    login_as_admin_user
    @card_in_current_project = create_card!(:name => "card in project: #{@project.name}", :card_type => "Card")

    @another_project = create_project(:prefix => 'another proj', :admins => [@admin], :users => [@project_member])
    card_in_another_project = create_card!(:name => 'card in project: another proj', :card_type => "Card")

    login_as_project_member
    open_card(@another_project, card_in_another_project.number)
    @browser.with_ajax_wait { @browser.click("link=via email") }

    open_card(@project, @card_in_current_project.number)
    @browser.with_ajax_wait { @browser.click("link=via email") }
    login_as_admin_user
    delete_project_permanently(@another_project) # yes mingle is deleting this project
    user_go_to_his_profile_page
    assert_card_subscription_present(2,@card_in_current_project.number)
  end

  private
  def user_subscribe_to_one_card
    @project.activate
    @card_been_subscribed = create_card!(:name => 'check card subscription', :card_type => "Card")
    open_card(@project, @card_been_subscribed.number)
    @browser.with_ajax_wait { @browser.click("link=via email") }
  end

  def user_have_different_subscriptions_from_one_project(options={})
    @project.activate
    @card_been_subscribed = create_card!(:name => 'check card subscription', :card_type => "Card")
    open_card(@project, @card_been_subscribed.number)
    @browser.with_ajax_wait { @browser.click("link=via email") }
    @page_been_subscribed = options[:new_page_name] || "check page subscription"
    create_new_wiki_page(@project, @page_been_subscribed, "content")
    click_subscribe_via_email
    only_show_to = options[:only_show_to] || 'pages'
    navigate_to_history_for(@project)
    click_type_for_history_filtering(only_show_to)
    click_subscribe_via_email
  end

  def should_see_all_the_subscription
    assert_page_subscription_present(2,@page_been_subscribed)
    assert_table_values("global_subscriptions", 2, 1, "Pages")
    assert_card_subscription_present(2,@card_been_subscribed.number)
  end


  def user_go_to_his_profile_page
    open_show_profile_for(@project_member)
  end

  def admin_go_to_delete_bug_type
    login_as("admin")
    delete_card_type(@project, BUG)
    login_as_project_member
  end

  def admin_go_to_delete_status_property
    login_as("admin")
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    login_as_project_member
  end

  def admin_go_to_remove_status_from_story
    login_as("admin")
    edit_property_definition_for(@project, STATUS, :card_types_to_uncheck => [STORY])
    login_as_project_member
  end


  def admin_go_to_remove_himself_from_project
    login_as("admin")
    navigate_to_team_list_for(@project)
    remove_from_team_for(@project, @admin, :update_permanently => true)
    login_as_project_member
  end

  def admin_remove_user_from_the_project
    login_as("admin")
    navigate_to_team_list_for(@project)
    remove_from_team_for(@project, @project_member, :update_permanently => true)
    login_as_project_member
  end

  def admin_deactivate_user_and_then_activate_him
    login_as("admin")
    toggle_activation_for(@project_member)
    toggle_activation_for(@project_member)
    login_as_project_member
  end

  def admin_delete_that_project
    login_as("admin")
    delete_project_permanently(@project)
    login_as_project_member
  end


  def user_should_no_longer_see_his_subscriptions_from_the_project
    @browser.assert_element_not_present(css_locator("table#page_subscriptions a[onclick]",0))
    @browser.assert_element_not_present(css_locator("table#card_subscriptions a[onclick]",0))
    @browser.assert_element_not_present(css_locator("table#global_subscriptions a[onclick]",0))
  end

end
