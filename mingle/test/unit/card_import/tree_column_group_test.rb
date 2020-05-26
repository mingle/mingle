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

class ImportTreeColumnGroupTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_member
  end
  
  def test_can_tell_whether_its_columns_are_completed_to_the_tree_or_not
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      assert !CardImport::TreeColumnGroup.new(configuration, [col('Planning'), col('Planning release')]).completed?
      assert !CardImport::TreeColumnGroup.new(configuration, [col('Planning release'), col('Planning iteration')]).completed?
      assert CardImport::TreeColumnGroup.new(configuration, [col('Planning'), col('Planning release'), col('Planning iteration')]).completed?
    end
  end
  
  
  def test_to_json
    configuration = OpenStruct.new(:name => 'Planning')
    def configuration.id
      123
    end
    group = CardImport::TreeColumnGroup.new(configuration, [col('Planning'), col('Planning release'), col('Planning iteration')])
    assert_equal({:id => 123, :name => 'Planning',  :columns=> ['planning', 'planning_release', 'planning_iteration']}, group.to_json.json_to_hash )
  end
  
  def test_show_incompete_warning_base_on_completed_status
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      assert_equal nil, CardImport::TreeColumnGroup.new(configuration, [col('Planning'), col('Planning release'), col('Planning iteration')]).incomplete_warning
      assert_equal nil, CardImport::TreeColumnGroup.new(configuration, [col('planning'), col('PLANNING release'), col('Planning ITERATION')]).incomplete_warning # bug 6173
      assert_equal "Properties for tree 'Planning' will not be imported because column 'Planning' was not included in the pasted data.", 
          CardImport::TreeColumnGroup.new(configuration, [col('Planning release'), col('Planning iteration')]).incomplete_warning
      assert_equal "Properties for tree 'Planning' will not be imported because column 'Planning', 'Planning release' were not included in the pasted data.", 
          CardImport::TreeColumnGroup.new(configuration, [col('Planning iteration')]).incomplete_warning
    end
  end
  
  def col(name)
    OpenStruct.new(:name => name)
  end
  
end
