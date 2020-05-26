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
class EmptyTreeTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
     login_as_admin
     @project = three_level_tree_project
     @project.activate
     @configuration = @project.tree_configurations.find_by_name('three level tree')
     @empty_tree = CardTree.empty_tree(@configuration)
  end
  
  def test_tree_name_should_be_tree_configuration_name
    assert_equal @configuration.name, @empty_tree.name
  end
  
  def test_empty_tree_should_be_real_empty
    assert_equal [], @empty_tree.nodes_without_root
  end
  
  def test_empty_tree_should_only_contain_virtual_root
    assert_equal 1, @empty_tree.nodes.size
    assert @empty_tree.nodes[0].root?
  end
  
end
