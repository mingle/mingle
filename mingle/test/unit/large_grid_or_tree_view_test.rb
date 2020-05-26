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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class LargeGridOrTreeViewTest < ActiveSupport::TestCase
  def setup
    @project = create_project
    @project.activate
    login_as_member
    @type_story = @project.card_types.create!(:name => 'story')
    setup_property_definitions(:priority => ['high', 'low'])
    @project.reload.property_definitions.each {|pd| pd.update_attributes(:card_types => @project.card_types.reload)}
    (1..3).each { |i| @project.cards.create!(:name => "card #{i}", :card_type_name => 'story', :cp_priority => 'low')}
    @project.cards.first.update_attributes(:cp_priority => 'high')
    @project.reload
  end
  
  def test_should_know_when_grid_has_too_many_cards
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:style => :grid})
      with_max_grid_view_size_of(project.cards.count + 1) { assert_false view.too_many_results? }
      
      view = CardListView.find_or_construct(project, {:style => :grid} )
      with_max_grid_view_size_of(project.cards.count - 1) { assert view.too_many_results? }
    end
  end

  def test_should_determine_grid_size_from_visible_cards
    view = CardListView.find_or_construct(@project, :filters => ['[Type][is][story]'], :style => 'grid', :group_by => 'priority', :lanes => 'high')
    with_max_grid_view_size_of(@project.cards.count) { assert !view.too_many_results? }
  end  

  # bug 8518
  def test_should_know_when_no_lanes_are_selected
    view = CardListView.find_or_construct(@project, :filters => ['[Type][is][story]'], :style => 'grid', :group_by => 'priority', :lanes => '')
    with_max_grid_view_size_of(@project.cards.count) { assert !view.too_many_results? }
  end

end
