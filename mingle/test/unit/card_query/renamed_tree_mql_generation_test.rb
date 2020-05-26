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

class RenamedTreeMqlGenerationTest < ActiveSupport::TestCase
  def setup
    @project = three_level_tree_project
    @project.activate
    login_as_member
  end
  
  def test_should_answer_correct_card_types_for_from_tree_condition
    assert_equal "SELECT Number FROM TREE 'tree'", change_value("SELECT Number FROM TREE 'three level tree'", 'three level tree', 'tree')
  end
  
  def test_should_should_not_rename_trees_that_are_not_being_renamed
    assert_equal "SELECT Number FROM TREE 'three level tree'", change_value("SELECT Number FROM TREE 'three level tree'", 'jimmy', 'timmy')
  end
  
  private
  def change_value(query, old_name, new_name)
    card_query = CardQuery.parse(query)
    CardQuery::RenamedTreeMqlGeneration.new(old_name, new_name, card_query).execute
  end
end
