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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class GridTest < ActiveSupport::TestCase
  
  def setup
    login_as_member
  end
  
  def test_displaying_cards_returns_cards_sorted_by_card_project_rank_by_default
    with_project_without_cards do |project|
      card_one, card_two = (1..2).map { |index| create_card! :name => index.to_s}
      view = CardListView.find_or_construct(project, {:style => :grid})
      assert_equal ['1', '2'], view.style.displaying_cards(view).map(&:name)
      card_two.insert_before(card_one)
      assert_equal ['2', '1'], view.style.displaying_cards(view).map(&:name)
    end
  end
  
  def test_displaying_cards_returns_cards_sorted_by_card_number_descending
    with_project_without_cards do |project|
      card_one, card_two = (1..2).map { |index| create_card! :name => index.to_s}
      view = CardListView.find_or_construct(project, {:style => :grid, :grid_sort_by => 'number'})
      assert_equal ['2', '1'], view.style.displaying_cards(view).map(&:name)
    end
  end
  
  # bug 6866
  def test_displaying_cards_returns_correct_cards_when_grouping_by_tree_relationship_property
    with_three_level_tree_project do |project|
      project.cards.create!(:name => 'non-tree iteration', :card_type_name => 'Iteration')
      r1 = project.cards.find_by_name('release1')
      view = CardListView.find_or_construct(project, { :style => :grid, :group_by => "Planning release", :lanes => " ,#{r1.number}", :filters => ["[Type][is][Iteration]"] })
      assert_equal ['iteration1', 'iteration2', 'non-tree iteration'], view.style.displaying_cards(view).collect(&:name).sort
    end
  end
  
  
  def test_should_know_when_grid_has_too_many_cards
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:style => :grid})
      with_max_grid_view_size_of(project.cards.count + 1) { assert !view.too_many_results? }

      view = CardListView.find_or_construct(project, {:style => :grid} )
      with_max_grid_view_size_of(project.cards.count) { assert !view.too_many_results? }

      view = CardListView.find_or_construct(project, {:style => :grid} )
      with_max_grid_view_size_of(project.cards.count - 1) { assert view.too_many_results? }
    end
  end
  
end
