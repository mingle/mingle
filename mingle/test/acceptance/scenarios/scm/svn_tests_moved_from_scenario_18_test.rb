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

# Tags: svn
class SvnTestsMovedFromScenario18Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  DEFAULT_KEYWORDS = 'card, #'
  DIFFERENT_SYNONYM = 'cardigan'
  does_not_work_without_subversion_bindings

  def setup
    ElasticSearch.enable
    Messaging.enable
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @driver = RepositoryDriver.new(name) do |driver|
      driver.initialize_with_test_data_and_checkout
    end
    @project = create_project(:prefix => 'scenario_18', :admins => [users(:proj_admin)],
      :users => [@admin],:repository_path => @driver.repos_dir)

    cache_revisions_content_for @project

    login_as_admin_user
    @project.save!
  end

  def teardown
    ElasticSearch.disable
    Messaging.disable
    @project.deactivate
  end

  # bug 3032
  def test_commit_messages_escape_html
    commit_with_html_tags = "foo <b>BAR</b>"
    same_commit_without_html_tags = "foo BAR"
    open_project(@project)
    @driver.unless_initialized do
      #revision 2
      @driver.update_file_with_comment('a.txt', 'code code code', commit_with_html_tags)
    end
    recreate_revisions_for(@project)
    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    @browser.assert_element_matches('revision-2', /#{commit_with_html_tags}/)
    @browser.assert_element_does_not_match('revision-2', /#{same_commit_without_html_tags}/)
  end

  # bug 3038
  def test_repos
    navigate_to_subversion_repository_settings_page(@project)
    assert_current_highlighted_option_on_side_bar_of_management_page('Project repository settings')
  end

  # bug 3543
  def test_commit_message_do_not_display_html_entities
    user_with_quotes_in_name = users(:user_with_quotes)
    user_with_quotes_in_name.update_attribute(:version_control_user_name, 'Ice_user')
    same_name_with_entities_for_quotes = "foo &quot;bar&quot;"
    add_full_member_to_team_for(@project, user_with_quotes_in_name)
    @project.reload
    open_project(@project)
    @driver.unless_initialized do
      @driver.user = 'Ice_user'
      #revision 2
      @driver.update_file_with_comment('a.txt', 'code code code', 'commited by user with quotes')
    end
    recreate_revisions_for(@project)

    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    @browser.assert_element_matches('revision-2', /#{user_with_quotes_in_name.name}/)
    @browser.assert_element_does_not_match('revision-2', /#{same_name_with_entities_for_quotes}/)
  end

  #bug 4669
  def test_card_keywords_are_case_insensitive_and_provide_links_on_revision_comments_cor_cards
    open_project(@project)
    @card_number = create_new_card(@project, :name => 'some work')
    @commit_message_with_card = "implemented card #{@card_number}"
    @commit_message_with_caps_Card = "implemented Card #{@card_number}"
    @commit_message_with_all_caps_CARD = "added features for CARD #{@card_number}"
    @driver.unless_initialized do
      @driver.update_file_with_comment 'a.txt', 'code code code', @commit_message_with_card
      @driver.update_file_with_comment 'a.txt', 'code code code', @commit_message_with_caps_Card
      @driver.update_file_with_comment 'a.txt', 'more code', @commit_message_with_all_caps_CARD
    end
    recreate_revisions_for(@project)
    open_card(@project, @card_number)
    assert_history_for(:revision, 4).shows(:link_to_card => @card_number, :with_text => 'CARD 1', :in_project => @project.name)
    assert_history_for(:revision, 3).shows(:link_to_card => @card_number, :with_text => 'Card 1', :in_project => @project.name)
    assert_history_for(:revision, 2).shows(:link_to_card => @card_number, :with_text => 'card 1', :in_project => @project.name)
  end

  # bug 3543
  def test_commit_message_do_not_display_html_entities
    user_with_quotes_in_name = users(:user_with_quotes)
    user_with_quotes_in_name.update_attribute(:version_control_user_name, 'Ice_user')
    same_name_with_entities_for_quotes = "foo &quot;bar&quot;"
    add_full_member_to_team_for(@project, user_with_quotes_in_name)
    @project.reload
    open_project(@project)
    @driver.unless_initialized do
      @driver.user = 'Ice_user'
      #revision 2
      @driver.update_file_with_comment('a.txt', 'code code code', 'commited by user with quotes')
    end
    recreate_revisions_for(@project)

    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    @browser.assert_element_matches('revision-2', /#{user_with_quotes_in_name.name}/)
    @browser.assert_element_does_not_match('revision-2', /#{same_name_with_entities_for_quotes}/)
  end

  #bug 4669
  def test_card_keywords_are_case_insensitive_and_provide_links_on_revision_comments_cor_cards
    open_project(@project)
    @card_number = create_new_card(@project, :name => 'some work')
    @commit_message_with_card = "implemented card #{@card_number}"
    @commit_message_with_caps_Card = "implemented Card #{@card_number}"
    @commit_message_with_all_caps_CARD = "added features for CARD #{@card_number}"
    @driver.unless_initialized do
      @driver.update_file_with_comment 'a.txt', 'code code code', @commit_message_with_card
      @driver.update_file_with_comment 'a.txt', 'code code code', @commit_message_with_caps_Card
      @driver.update_file_with_comment 'a.txt', 'more code', @commit_message_with_all_caps_CARD
    end
    recreate_revisions_for(@project)
    open_card(@project, @card_number)
    assert_history_for(:revision, 4).shows(:link_to_card => @card_number, :with_text => 'CARD 1', :in_project => @project.name)
    assert_history_for(:revision, 3).shows(:link_to_card => @card_number, :with_text => 'Card 1', :in_project => @project.name)
    assert_history_for(:revision, 2).shows(:link_to_card => @card_number, :with_text => 'card 1', :in_project => @project.name)
  end

  def test_keywords_for_revisions_creates_links_in_revision_comments
    @project.update_full_text_index
    create_test_card_and_generate_revisions
    assert_links_present_in_global_history
    assert_links_present_in_card_history

    assert_revision_view_message_section_contain_card_links
    assert_testing_new_pattern_finds_appropriate_matches_in_revision_comments
  end

  # bug 631
  def test_keywords_for_revisions_finds_appropriate_matches_when_repos_set
    create_test_card_and_generate_revisions
    navigate_to_card_keywords_for(@project)
    type_project_card_keywords(DEFAULT_KEYWORDS)
    click_show_last_ten_matching_revisions_button
    assert_link_present "/projects/#{@project.identifier}/cards/#{@card_number}"
  end

  def test_default_revision_matching_expression_should_find_correct_matches
    card = create_card!(:name => '1st card', :description => 'card123, test90, #12345')

    open_card(@project, card.number)
    assert_link_to_card_present(@project, 123)
    assert_link_to_card_present(@project, 12345)
    assert_link_to_card_not_present(@project, 90)

    create_new_wiki_page(@project, 'testpage', 'card123, test90, #12345')
    assert_link_to_card_present(@project, 123)
    assert_link_to_card_present(@project, 12345)
    assert_link_to_card_not_present(@project, 90)
  end

  def test_bad_repos_path_gives_friendly_error_message
    navigate_to_project_repository_settings_page(@project)
    type_project_repos_path('non-existing repos')
    click_save_settings_link
    click_source_tab
    assert_error_message('Error in connection with repository. Please contact your Mingle administrator and check your logs.')
   end

  # bug 632
  def test_keywords_for_revisions_returning_no_matches_gives_friendly_feedback
    some_other_card_number = 42
    navigate_to_card_keywords_for(@project)
    type_project_card_keywords('unmatching')
    type_card_number_for_testing_pattern_matching(some_other_card_number)
    click_show_last_ten_matching_revisions_button
    @browser.assert_text_present "No matches for pattern against card number #{some_other_card_number} were found."
  end

  def test_keywords_for_revisions_creates_links_in_card_and_wiki_content
    navigate_to_card_keywords_for(@project)
    type_project_card_keywords(DEFAULT_KEYWORDS + ', story card')
    click_update_keywords_link
    content_with_good_links = "card 211 card42 #37 # 444      story card 786"
    card_number = create_new_card(@project, :name => 'card with valid links', :description => content_with_good_links)
    open_card(@project, card_number)
    assert_link_to_card_present(@project, 211)
    assert_link_to_card_present(@project, 42)
    assert_link_to_card_present(@project, 37)
    assert_link_to_card_present(@project, 444)
    assert_link_to_card_present(@project, 786)

    wiki_page = 'good_links_page'
    create_new_wiki_page(@project, wiki_page, content_with_good_links)
    open_wiki_page(@project, wiki_page)
    assert_link_to_card_present(@project, 211)
    assert_link_to_card_present(@project, 42)
    assert_link_to_card_present(@project, 37)
    assert_link_to_card_present(@project, 444)
    assert_link_to_card_present(@project, 786)
  end

  private
  def assert_revision_view_message_section_contain_card_links
    assert_link_to_card_present_on_revision(@card_number, 2)
    assert_link_to_card_present_on_revision(@card_number, 4)

    assert_link_to_card_not_present_on_revision(@card_number, 3)
    assert_link_to_card_not_present_on_revision(@card_number, 5)
    assert_link_to_card_not_present_on_revision(@card_number, 6)
  end

  def assert_search_result_present_for(number, content)
    assert_equal content, @browser.get_text(css_locator("#revision-result-#{number} .description a[href='/projects/#{@project.identifier}/cards/1')]"))
  end

  def assert_search_result_not_present_for(number)
    @browser.assert_element_not_present css_locator("#revision-result-#{number} .description a[href='/projects/#{@project.identifier}/cards/1')]")
  end

  def assert_link_to_revision_present_for(project, revision_number)
    assert_link_present("/projects/#{@project.identifier}/revisions/#{revision_number}")
  end

  def assert_link_to_card_present_on_revision(card_number, revision)
    cache_revisions_content_for(@project)
    @browser.open "/projects/#{@project.identifier}/revisions/#{revision}"
    assert_link_to_card_present @project.name, card_number
  end

  def assert_link_to_card_not_present_on_revision(card_number, revision)
    cache_revisions_content_for(@project)
    @browser.open "/projects/#{@project.identifier}/revisions/#{revision}"
    assert_link_to_card_not_present @project.name, card_number
  end

  def assert_invalid_keywords_display_error_message(keywords)
    keywords.each do |keyword|
      type_project_card_keywords(keyword)
      click_update_keywords_link
      @browser.assert_text_present "Card keywords are limited to words and the '#' symbol"
      @browser.assert_value 'project[card_keywords]', keyword
      navigate_to_card_keywords_for(@project.name)
    end
  end

  def assert_links_present_in_global_history
    navigate_to_history_for(@project)
    assert_history_for(:revision, 2).shows(:link_to_card => @card_number, :with_text => 'card 1', :in_project => @project.name)
    assert_history_for(:revision, 3).does_not_show(:link_to_card => @card_number, :with_text => 'cardigan 1', :in_project => @project.name)
    assert_history_for(:revision, 4).shows(:link_to_card => @card_number, :with_text => '#1', :in_project => @project.name)
    assert_history_for(:revision, 5).does_not_show(:link_to_card => @card_number, :with_text => 'cardigan 1', :in_project => @project.name)
    assert_history_for(:revision, 6).does_not_show(:link_to_card => @card_number, :with_text => 'card', :in_project => @project.name)
  end

  def assert_links_present_in_card_history
    open_card(@project, @card_number)
    assert_history_for(:revision, 2).shows(:link_to_card => @card_number, :with_text => 'card 1', :in_project => @project.name)
    assert_history_for(:revision, 4).shows(:link_to_card => @card_number, :with_text => '#1', :in_project => @project.name)
    assert_history_for(:revision, 3).not_present
    assert_history_for(:revision, 5).not_present
    assert_history_for(:revision, 6).not_present
  end

  def assert_testing_new_pattern_finds_appropriate_matches_in_revision_comments
    navigate_to_card_keywords_for(@project.name)
    type_project_card_keywords(DIFFERENT_SYNONYM)
    click_show_last_ten_matching_revisions_button
    assert_link_to_card_present(@project.name, @card_number)
  end

  def create_new_project_with(name)
    click_create_project_button
    click_new_project_link
    type_project_name(name)
    click_create_project_button
    navigate_to_project_project_repository_settings_page(@project)
    type_project_repos_path(@driver.repos_dir)
    click_save_link
    @project = Project.find_by_name(name)
  end

  def create_test_card_and_generate_revisions
    open_project(@project)
    @card_number = create_new_card(@project, :name => 'some work')
    @commit_message_with_card = "implemented card #{@card_number}"
    @commit_message_with_hash = "added features for ##{@card_number}"
    @driver.unless_initialized do
      #revision 2
      @driver.update_file_with_comment 'a.txt', 'code code code', @commit_message_with_card
      #revision 3
      @driver.update_file_with_comment 'a.txt', 'more content', "added a #{DIFFERENT_SYNONYM} #{@card_number}"
      #revision 4
      @driver.update_file_with_comment 'a.txt', 'more code', @commit_message_with_hash
      #revision 5
      @driver.update_file_with_comment 'a.txt', 'super stuff', "more work on #{@card_number}"
      #revision 6
      @driver.update_file_with_comment 'a.txt', 'added text', "more work on card"
    end
    recreate_revisions_for(@project)
    @browser.run_once_history_generation
    @browser.run_once_full_text_search
    open_project(@project)
  end

end
