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

class CardSelectionSearchTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_admin
    ElasticSearch.delete_index
  end

  def test_remove_tag_by_card_selection_should_update_search_index
    with_new_project do |project|
      card_1 = project.cards.create!(:name => 'first', :card_type => project.card_types.first)
      card_2 = project.cards.create!(:name => 'second', :card_type => project.card_types.first)
      card_3 = project.cards.create!(:name => 'third', :card_type => project.card_types.first)

      card_1.tag_with(['ratchet']).save!
      card_2.tag_with(['ratchet']).save!
      card_3.tag_with(['ratchet']).save!
      FullTextSearch.run_once

      found_card_names = Search::Client.new.find('ratchet').map(&:name)

      assert found_card_names.include?(card_1.name)
      assert found_card_names.include?(card_2.name)
      assert found_card_names.include?(card_3.name)

      card_selection = CardSelection.new(project, [card_1, card_2])
      card_selection.remove_tag('ratchet')

      FullTextSearch.run_once
      found_card_names = Search::Client.new.find('ratchet').map(&:name)

      assert_equal [card_3.name], found_card_names
    end
  end

  def test_tag_with_should_update_search_index
    with_new_project do |project|
      card_1 = project.cards.create!(:name => 'first', :card_type => project.card_types.first)
      card_2 = project.cards.create!(:name => 'second', :card_type => project.card_types.first)
      project.cards.create!(:name => 'third', :card_type => project.card_types.first)

      card_selection = CardSelection.new(project, [card_1, card_2])
      card_selection.tag_with('Timmy')
      project.cards.collect(&:reload)

      FullTextSearch.run_once
      found_card_names = Search::Client.new.find('Timmy').map(&:name)

      assert_equal [card_1.name, card_2.name].sort, found_card_names.sort
    end
  end

end
