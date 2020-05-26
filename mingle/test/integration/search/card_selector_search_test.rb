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

require File.expand_path(File.dirname(__FILE__) + '/search_test_helper')

class CardSelectorSearchTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  fixtures :users, :login_access

  def setup
    login_as_admin
    ElasticSearch.delete_index
  end

  def test_search_should_append_context_of_tree_and_tree_prop_valid_card_type_to_the_search_query_when_action_type_is_filter_or_history
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      run_all_search_message_processors

      type_release = project.card_types.find_by_name 'Release'
      type_story = project.card_types.find_by_name 'Story'

      project.cards.create!(:number => 1001, :name => 'release1 card not associated with tree', :card_type => type_release)
      story_card = project.cards.find_by_name('story1')
      story_card.update_attribute(:name, 'a release1 story')

      run_all_search_message_processors

      release_prop = project.find_property_definition('Planning Release')
      filter_selector = CardSelector::Factory.create_card_selector(release_prop, :filter)
      assert_equal ['release1'], filter_selector.search('release1').map(&:name)

      history_filter_selector = CardSelector::Factory.create_card_selector(release_prop, :history_filter)
      assert_equal ['release1'], history_filter_selector.search('release1').map(&:name)
    end
  end

  def test_search_should_append_context_of_tree_prop_valid_card_type_to_the_search_query_when_action_type_is_edit
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      run_all_search_message_processors

      type_release = project.card_types.find_by_name 'Release'
      type_story = project.card_types.find_by_name 'Story'

      release1 = project.cards.find_by_name('release1')
      another_release_card = project.cards.create!(:number => 1001, :name => 'another release1 card', :card_type => type_release)
      story_card = project.cards.find_by_name('story1')
      story_card.update_attribute(:name, 'a release1 story')

      run_all_search_message_processors

      release_prop = project.find_property_definition('Planning Release')
      selector = CardSelector::Factory.create_card_selector(release_prop, :edit)
      assert_equal [release1.number, 1001], selector.search('release1').map(&:number).sort
    end
  end

  def test_no_additional_filtering_is_applied_to_search_results_when_search_context_is_card_property
    with_new_project do |project|
      card_prop = setup_card_relationship_property_definition('parent')

      type_release = project.card_types.create!(:name => 'release')
      type_story = project.card_types.create!(:name => 'story')

      another_release_card = project.cards.create!(:number => 1001, :name => 'release1 card', :card_type => type_release)
      story_card = project.cards.create!(:number => 1002, :name => 'a release1 story card', :card_type => type_story)

      run_all_search_message_processors

      selector = CardSelector::Factory.create_card_selector(card_prop, :edit)
      assert_equal [1001, 1002], selector.search('release1').map(&:number).sort

      selector = CardSelector::Factory.create_card_selector(card_prop, :filter)
      assert_equal [1001, 1002], selector.search('release1').map(&:number).sort

      selector = CardSelector::Factory.create_card_selector(card_prop, :history_filter)
      assert_equal [1001, 1002], selector.search('release1').map(&:number).sort
    end
  end

  def test_search_should_return_cards_contain_query_string_and_meet_context
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 1', :card_type => project.card_types.first)
      create_card!(:number => 2, :name => 'haha', :card_type => project.card_types.first)
      create_card!(:number => 3, :name => 'hello world', :card_type => project.card_types.first)
      create_card!(:number => 4, :name => 'card 4', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_sort_equal [1, 4], CardSelector.new(project).search('card').collect(&:number)
      assert_equal [1], CardSelector.new(project, :search_context => 'number:1').search('card').collect(&:number)
    end
  end

  def test_search_with_short_word
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 1', :card_type => project.card_types.first)
      create_card!(:number => 2, :name => 'haha', :card_type => project.card_types.first)
      create_card!(:number => 3, :name => 'hello world', :card_type => project.card_types.first)
      create_card!(:number => 4, :name => 'card 4', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_equal 0, CardSelector.new(project).search('c').size
    end
  end

  def test_should_be_nothing_when_search_with_empty_string
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 1', :card_type => project.card_types.first)
      create_card!(:number => 2, :name => 'haha', :card_type => project.card_types.first)
      create_card!(:number => 3, :name => 'hello world', :card_type => project.card_types.first)
      create_card!(:number => 4, :name => 'card 4', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_equal [], CardSelector.new(project, :search_context => 'number:1').search('')
    end
  end

  def test_should_be_search_card_number_if_query_included_number
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 4', :card_type => project.card_types.first)
      create_card!(:number => 2, :name => 'haha', :card_type => project.card_types.first)
      create_card!(:number => 3, :name => 'hello world', :card_type => project.card_types.first)
      create_card!(:number => 4, :name => 'card 123', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_equal [1, 4], CardSelector.new(project).search('4').map(&:number).sort
    end
  end

  def test_should_only_return_card_matching_number_in_search_query_when_search_string_is_hash_followed_by_card_number
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 4', :card_type => project.card_types.first)
      create_card!(:number => 2, :name => 'haha', :card_type => project.card_types.first)
      create_card!(:number => 3, :name => 'hello world', :card_type => project.card_types.first)
      create_card!(:number => 4, :name => 'card 123', :card_type => project.card_types.first)
      run_all_search_message_processors

      assert_equal [1, 4], CardSelector.new(project).search('#4').map(&:number).sort
    end
  end

  def test_search_for_hash_number_should_not_return_card_if_card_not_meet_context_condition
    with_new_project do |project|
      type_card = project.card_types.first
      project.cards.create!(:name => 'card 1', :number => 101, :card_type => type_card)
      run_all_search_message_processors

      selector = CardSelector.new(project, :search_context => "number:100202")
      assert_equal [], selector.search("#101")
    end
  end

end
