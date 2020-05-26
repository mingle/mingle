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

class ImportColumnTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_member
  end
  
  def test_can_tell_whether_it_belongs_to_a_tree
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      assert !CardImport::Column.new(2, 'Name', project).tree_column?
      assert !CardImport::Column.new(3, 'new property', project).tree_column?
      assert CardImport::Column.new(4, 'Planning', project).tree_column?
      assert CardImport::Column.new(5,'Planning release', project).tree_column?
      assert CardImport::Column.new(6, 'Planning iteration', project).tree_column?
    end
  end
  
  
  def test_be_able_to_tell_columns_tree
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      assert_nil CardImport::Column.new(2, 'Name', project).tree_config
      assert_nil CardImport::Column.new(3, 'new property', project).tree_config
      assert_equal configuration, CardImport::Column.new(4, 'Planning', project).tree_config
      assert_equal configuration, CardImport::Column.new(5, 'Planning release', project).tree_config
      assert_equal configuration, CardImport::Column.new(6, 'Planning iteration', project).tree_config
    end
  end
end
