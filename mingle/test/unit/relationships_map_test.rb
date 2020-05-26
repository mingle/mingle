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
class RelationshipsMapTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = create_project
    @project.activate
    login_as_admin
    configuration = @project.tree_configurations.create!(:name => 'Planning')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    init_planning_tree_with_multi_types_in_levels(configuration)
    @relationship_map = configuration.relationship_map
  end
  
  def test_each_before
    result = []
    @relationship_map.each_before(@type_iteration) { |r| result << r.name}
    assert_equal ['Planning release'], result
    result = []
    @relationship_map.each_before(@type_story) { |r| result << r.name}
    assert_equal ['Planning release', 'Planning iteration'], result
    result = []
    @relationship_map.each_before(@type_release) { |r| result << r.name}
    assert_equal [], result
  end
  
  def test_each_after
    result = []
    @relationship_map.each_after(@type_release) { |r| result << r.name}
    assert_equal ['Planning iteration'], result    
  end
  
  def test_card_type_index
    assert_equal -1, @relationship_map.card_type_index("not exist card type")
    assert_equal -1, @relationship_map.card_type_index(:tree)
  end

    
end
