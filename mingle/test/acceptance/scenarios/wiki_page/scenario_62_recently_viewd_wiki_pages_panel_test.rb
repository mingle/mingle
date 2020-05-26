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

# Tags: scenario, wiki, page
class Scenario62RecentlyViewedWikiPagesPanelTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_62', :users => [@non_admin_user], :admins => [@project_admin_user])
    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'sample card_1')
  end
  
  def test_first_time_recently_viewed_panel_gives_no_viewed_pages
    create_new_overview_page_with_content_for(@project, 'welcome to overview')
    assert_no_recently_viewed_pages_present
  end

  def test_maximum_five_recenlty_viewed_wiki_pages_are_allowd
    create_new_overview_page_with_content_for(@project, 'welcome [[link1]] [[link2]] [[link3]] [[link4]]')
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    click_and_add_content_to_wiki_page('link2', '[[link3]]')
    click_and_add_content_to_wiki_page('link3', '[[link4]]')
    click_and_add_content_to_wiki_page('link4', '[[go to page 5]]')
    click_and_add_content_to_wiki_page('go to page 5', 'this is sample')
    click_overview_tab
    assert_links_present_on_recently_viewed_page_for(@project, 'link4','link3', 'link2', 'link1', 'go_to_page_5')
  end

  def test_most_recently_visited_page_will_be_listed_on_top_except_current_viewing_page
    create_new_overview_page_with_content_for(@project, 'welcome [[link1]] [[link2]] [[link3]] [[link4]]')
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    click_and_add_content_to_wiki_page('link2', '[[link3]]')
    click_and_add_content_to_wiki_page('link3', '[[link4]]')
    click_and_add_content_to_wiki_page('link4', '[[go to page 5]]')
    click_and_add_content_to_wiki_page('go to page 5', 'this is sample')
    click_overview_tab
    assert_links_present_on_recently_viewed_page_for(@project, 'link4','link3', 'link2', 'link1', 'go to page 5')
    assert_links_not_present_on_recently_viewed_page_for(@project, 'Overview_Page')
    assert_order_of_recenlty_viewed_pages('go to page 5', 'link4','link3', 'link2', 'link1')
  end

  def test_no_duplicate_page_link_displayed_on_recently_visited_page_pane
    create_new_overview_page_with_content_for(@project, 'welcome [[link1]] [[link2]] [[link3]] [[link4]]')
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    click_and_add_content_to_wiki_page('link2', '[[link1]]')
    click_on_wiki_page_link_for('link1')
    click_overview_tab
    assert_links_present_on_recently_viewed_page_for(@project, 'link2', 'link1', 'Overview Page')
    assert_order_of_recenlty_viewed_pages( 'link1', 'link2', 'Overview Page')
  end

  def test_should_be_able_to_visit_pages_through_recently_viewed_page_links
    create_new_overview_page_with_content_for(@project, 'welcome [[link1]] [[link2]] [[link3]] [[link4]]')
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    click_and_add_content_to_wiki_page('link2', 'hello world')
    click_overview_tab
    assert_links_present_on_recently_viewed_page_for(@project, 'link2', 'link1', 'Overview Page')
    click_on_wiki_page_link_for('link1')
    assert_opened_wiki_page('link1')
    assert_order_of_recenlty_viewed_pages('Overview Page', 'link2', 'link1')
  end

  def test_non_existant_link_becomes_existant_when_page_added_for_that_wiki_on_a_page
    create_new_overview_page_with_content_for(@project, '[[link1]]')
    assert_non_existant_wiki_link_present
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    click_overview_tab
    assert_non_existant_wiki_page_link_not_present
  end
  
  # bug 2755
  def test_non_existant_link_becomes_existant_when_page_added_for_that_wiki_on_a_card
    open_card_for_edit(@project, @card_1.number)
    type_card_description('[[link1]]')
    save_card
    assert_non_existant_wiki_link_present
    click_and_add_content_to_wiki_page('link1', '[[link2]]')
    open_card(@project, @card_1.number)
    assert_non_existant_wiki_page_link_not_present
  end  
end
