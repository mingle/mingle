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

class CardsControllerHierarchyViewTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
    @project = three_level_tree_project
    @project.activate

    @release1 = @project.cards.find_by_name('release1')
    @iteration1 = @project.cards.find_by_name('iteration1')
    @iteration2 = @project.cards.find_by_name('iteration2')
    @story1 = @project.cards.find_by_name('story1')
  end

  def test_hierarchy_view_should_only_load_first_level_of_the_tree_as_default
    get :list, :project_id => @project.identifier, :style => 'hierarchy', :tree_name => 'three level tree'
    assert_select "##{@release1.html_id}"
    assert_select "##{@iteration1.html_id}", false
    assert_select "##{@story1.html_id}", false
  end

  def test_hierarchy_view_should_only_load_first_level_and_expaned_children
    get :list, :project_id => @project.identifier, :style => 'hierarchy', :tree_name => 'three level tree', :expands => @release1.number
    assert_select "##{@release1.html_id}"
    assert_select "##{@iteration1.html_id}", true
    assert_select "##{@iteration2.html_id}", true
    assert_select "##{@story1.html_id}", false
  end
end
