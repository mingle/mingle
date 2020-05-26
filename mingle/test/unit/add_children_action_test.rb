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

class AddChildrenActionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def test_should_report_children_that_are_added_but_filtered_out_of_view
    login_as_proj_admin
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      release1 = project.cards.find_by_name('release1')
      params = { :tf_release => ["[Planning - Release][is][#{release1.number}]"], :tree => configuration.id }
      action = AddChildrenAction.new(project, configuration, params, CardContext.new(project, {}))
      new_story = create_card!(:name => 'new card', :card_type => 'story')
      action.execute(:root, [new_story])
      assert_equal ["1 card was added to #{'Planning'.bold}, but is not shown because it does not match the current filter."], action.warning_messages_for_hidden_nodes
    end
  end
  
  # Bug 7815
  def test_should_report_children_that_are_moved_but_filtered_out_of_view
    login_as_proj_admin
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      release1, story2 = %w{release1 story2}.map { |card_name| project.cards.find_by_name(card_name) }
      params = { :tf_release => ["[Planning - Release][is][#{release1.number}]"], :tree => configuration.id }
      action = AddChildrenAction.new(project, configuration, params, CardContext.new(project, {}))
      action.execute(:root, [story2])
      assert_equal ["1 card was updated in #{'Planning'.bold}, but is not shown because it does not match the current filter."], action.warning_messages_for_hidden_nodes
    end
  end
end
