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

class TreesHelperTest < ActiveSupport::TestCase
  include TreesHelper, UserAccess
  
  def setup
    @member = User.find_by_login("member")
    @project = create_project
    @project.add_member(@member, :readonly_member)
  end
  
  def test_add_children_callback
    login_as_admin
    tree_config, tab_name, view_params = 'tree_config', 'All', {}
    assert_equal 'function(parent, parent_expanded, children, newCards, all_card_count_of_selected_subtree) { remote_function }', add_children_callback(tree_config, tab_name, view_params)
  end
  
  def test_add_children_callback_should_be_null_when_user_has_no_access_to_add_children_into_tree
    login_as_member
    tree_config, tab_name, view_params = 'tree_config', 'All', {}
    assert_equal 'null', add_children_callback(tree_config, tab_name, view_params)
  end
  
  def params
    {}
  end
  
  def remote_function(*args)
    'remote_function'
  end
end
