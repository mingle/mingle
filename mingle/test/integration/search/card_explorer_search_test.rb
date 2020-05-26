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

class CardExplorerSearchTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  fixtures :users, :login_access

  def setup
    login_as_admin
    ElasticSearch.delete_index
  end

  def test_should_not_find_cards_type_of_which_is_not_in_the_tree
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      type_card = project.card_types.find_by_name('card')
      create_card!(:name => 'my story release 1', :card_type => type_card)
      run_all_search_message_processors
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => 'my story')
      assert_equal [], card_explorer.cards.collect(&:name)
    end
  end

  def test_cards_that_are_attached_to_the_tree_should_be_at_the_end_of_results
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      type_story = project.card_types.find_by_name('story')
      story_1 = create_card!(:name => 'my story 1', :card_type => type_story)
      story_2 = create_card!(:name => 'my story 2', :card_type => type_story)
      story_3 = create_card!(:name => 'my story 3', :card_type => type_story)
      story_4 = create_card!(:name => 'my story 4', :card_type => type_story)
      story_5 = create_card!(:name => 'my story 5', :card_type => type_story)
      story_6 = create_card!(:name => 'my story 6', :card_type => type_story)
      run_all_search_message_processors

      iteration_1 = project.cards.find_by_name('iteration1')

      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => 'my story')
      def card_explorer.page_size; 4 end

      assert_equal ['my story 6', 'my story 5', 'my story 4', 'my story 3'], card_explorer.cards.collect(&:name)
      configuration.add_child(story_6, :to => iteration_1)
      configuration.add_child(story_5, :to => iteration_1)
      run_all_search_message_processors
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => 'my story')
      def card_explorer.page_size; 4 end
      assert_equal ['my story 4', 'my story 3', 'my story 2', 'my story 1'], card_explorer.cards.collect(&:name)
    end
  end

  def test_should_be_able_to_find_cards_with_hashes_in_their_names
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      type_story = project.card_types.find_by_name('story')
      some_card = create_card!(:name => '#12345', :card_type => type_story)
      run_all_search_message_processors

      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => '#12345')
      assert_equal ["#12345"], card_explorer.cards.collect(&:name)
    end
  end

  def test_should_return_card_that_can_be_added_into_the_tree_when_searching_with_term_in_card_name
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      project.cards.create!(:name => 'another story1', :card_type => project.card_types.find_by_name("story"))
      project.cards.create!(:name => 'another story1 is card type', :card_type => project.card_types.find_by_name("Card"))

      run_all_search_message_processors
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => 'story1')

      assert_equal ['another story1', 'story1'], card_explorer.cards.collect(&:name)
    end
  end

  def test_should_return_cards_order_by_number_desc
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      project.cards.create!(:number => 1001, :name => 'another story1', :card_type => project.card_types.find_by_name("story"))
      project.cards.create!(:number => 1002, :name => 'another story1 again', :card_type => project.card_types.find_by_name("story"))

      run_all_search_message_processors
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => 'story1')

      assert_equal ['another story1 again', 'another story1', 'story1'], card_explorer.cards.collect(&:name)
    end
  end

  def test_should_return_only_card_id_when_searching_for_hash_id
    with_new_project do |project|
      configuration = create_three_level_tree.configuration
      story1 = project.cards.find_by_name('story1')
      run_all_search_message_processors
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, configuration, :q => "##{story1.number}")

      assert_sort_equal ['story1'], card_explorer.cards.collect(&:name)
    end
  end

end
