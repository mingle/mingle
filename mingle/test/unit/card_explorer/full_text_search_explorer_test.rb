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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class FullTextSearchExplorerTest < ActiveSupport::TestCase

  def setup
    login_as_member
  end

  def test_describe_results_depend_on_total_matched_result_size_and_page_size
    with_first_project do |project|
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, nil, :q => 'my story')
      def card_explorer.matched_cards
        Result::ResultSet.new(page_size, 1).concat([1])
      end
      assert_equal 'Showing 1 result.', card_explorer.describe_results
      def card_explorer.matched_cards
        Result::ResultSet.new(page_size, 100).concat(Array.new(page_size))
      end
      assert_match /Showing first 50 results of 100/, card_explorer.describe_results
      assert card_explorer.describe_results.html_safe?
    end
  end

  def test_full_text_explorer_no_results_message_when_no_cards_exist_in_project
    project_without_cards.with_active_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'a tree')
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, tree_config, :q => 'my story')
      assert_equal "There are no cards in this project.", card_explorer.no_result_message
    end
  end

  def test_full_text_explorer_no_results_message_when_cards_exist_in_project
    project_without_cards.with_active_project do |project|
      project.cards.create!(:name => 'a card', :card_type => project.card_types.first)
      tree_config = project.tree_configurations.create(:name => 'a tree')
      card_explorer = CardExplorer::FullTextSearchExplorer.new(project, tree_config, :q => 'my story')
      assert_equal "Your search #{'my story'.bold} did not match any cards for the current tree.",  card_explorer.no_result_message
    end
  end

end
