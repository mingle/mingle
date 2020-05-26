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

# Tags: scenario, cards, wiki, history, project, #143
class Scenario18PatternMatchingForCardsTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  DEFAULT_KEYWORDS = 'card, #'
  DIFFERENT_SYNONYM = 'cardigan'
  does_not_work_without_subversion_bindings

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project = create_project(:prefix => 'scenario_18', :admins => [users(:proj_admin)],
      :users => [@admin])
    login_as_admin_user
    @project.save!
  end

  def teardown
    @project.deactivate
  end

  def test_new_project_created_with_default_matching_pattern
    navigate_to_card_keywords_for(@project)
    @browser.assert_value 'project[card_keywords]', DEFAULT_KEYWORDS
  end

  # bug 636
  def test_keywords_can_only_be_words_or_hash_symbol
    invalid_keywords = ['-', '~', '!', '@', '##', '$', '\\', '0', '^', '%', '`', '..', '=~', '$&', '&', 'story-card', ',,', ',', ', #']
    navigate_to_card_keywords_for(@project)
    assert_invalid_keywords_display_error_message invalid_keywords
  end

  def test_changing_pattern_is_not_applied_across_projects
    other_project_name = "other_proj_#{Time.new.to_i}"
    other_project = Project.create!(:name => other_project_name, :identifier => other_project_name)
    assert_equal DEFAULT_KEYWORDS, other_project.card_keywords.to_s

    navigate_to_card_keywords_for(@project)
    type_project_card_keywords('fix,bug,card')
    click_update_keywords_link

    assert DEFAULT_KEYWORDS, other_project.reload.card_keywords.to_s
  end

  def test_links_not_created_in_card_or_wiki_with_partial_matches
    content_with_bad_links = "cardigan 21    card. 43 bottels of beer   #nine"
    open_project(@project)
    card_number = create_new_card(@project, :name => 'card with invalid links', :description => content_with_bad_links)
    open_card(@project, card_number)
    assert_link_to_card_not_present(@project, 21)
    assert_link_to_card_not_present(@project, 43)
    assert_link_to_card_not_present(@project, 9)

    wiki_page = 'bad_links_page'
    create_new_wiki_page(@project, wiki_page, content_with_bad_links)
    open_wiki_page(@project, wiki_page)
    assert_link_to_card_not_present(@project, 21)
    assert_link_to_card_not_present(@project, 43)
    assert_link_to_card_not_present(@project, 9)
  end

  # bug 634
  def test_can_alter_pattern_even_if_repos_is_not_set
    navigate_to_card_keywords_for(@project)
    @browser.assert_element_editable 'project[card_keywords]'
  end

  #2169
  def test_keywords_links_the_cards_even_within_parenthesis
    navigate_to_card_keywords_for(@project)
    content_with_links_within_parenthisis = "(#211) (card 42) # 444"
    card_number = create_new_card(@project, :name => 'card with valid links', :description => content_with_links_within_parenthisis)
    open_card(@project, card_number)
    assert_link_to_card_present(@project, 211)
    assert_link_to_card_present(@project, 42)
    assert_link_to_card_present(@project, 444)

    wiki_page = 'good_links_page'
    create_new_wiki_page(@project, wiki_page, content_with_links_within_parenthisis)
    open_wiki_page(@project, wiki_page)
    assert_link_to_card_present(@project, 211)
    assert_link_to_card_present(@project, 42)
    assert_link_to_card_present(@project, 444)
  end

  private

  def assert_invalid_keywords_display_error_message(keywords)
    keywords.each do |keyword|
      type_project_card_keywords(keyword)
      click_update_keywords_link
      @browser.assert_text_present "Card keywords are limited to words and the '#' symbol"
      @browser.assert_value 'project[card_keywords]', keyword
      navigate_to_card_keywords_for(@project.name)
    end
  end

end
