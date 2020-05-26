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

class StyleTest < ActiveSupport::TestCase

  def test_support_columns
    assert CardView::Style::support_columns?(CardView::Style::LIST)
    assert CardView::Style::support_columns?(CardView::Style::HIERARCHY)
    assert !CardView::Style::support_columns?(CardView::Style::Grid)
    assert !CardView::Style::support_columns?(CardView::Style::Tree)
  end

  def test_normal_filters_are_show_in_non_tree_workspace
    with_filtering_tree_project do |project|
      view = CardListView.find_or_construct(project)
      assert_equal 'shared/filters', view.style.filter_tabs(view)
    end
  end

  def test_filter_tabs_shows_tree_filters_in_tree_workspace
    with_filtering_tree_project do |project|
      view = CardListView.find_or_construct(project, :tree_name => 'filtering tree')
      assert_equal 'cards/tree_filters', view.style.filter_tabs(view)
    end
  end

  def test_filter_tabs_shows_tree_filters_for_tree_in_tree_workspace_with_tree_view
    with_filtering_tree_project do |project|
      view = CardListView.find_or_construct(project, :tree_name => 'filtering tree', :style => 'tree')
      assert_equal 'cards/tree_filters_for_tree', view.style.filter_tabs(view)
    end
  end

end
