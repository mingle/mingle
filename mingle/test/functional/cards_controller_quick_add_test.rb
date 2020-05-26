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

class CardsControllerQuickAddTest < ActionController::TestCase
  
  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_should_show_quick_add_button_on_hierarchy_view
    with_three_level_tree_project do |project|
      get :list, :style => 'hierarchy', :project_id => project.identifier, :tree_name => 'three level tree'
      assert_select '#add_card_with_defaults', :count => 1
      assert_select '.magic_card', :count => 0
    end 
  end
  
  def test_should_show_quick_add_button_on_tree_view
    with_three_level_tree_project do |project|
      get :list, :style => 'tree', :project_id => project.identifier, :tree_name => 'three level tree'
      assert_select '#add_card_with_defaults', :count => 1
      assert_select '.magic_card', :count => 0
    end     
  end
  
  def test_should_show_quick_add_button_and_magic_card_on_grid_view
    get :list, :style => 'grid', :project_id => @project.identifier
    assert_select '#add_card_with_defaults', :count => 1
    assert_select '.magic_card', :count => 1
  end
  
  def test_should_show_quick_add_button_on_list_view
    get :list, :style => 'list', :project_id => @project.identifier
    assert_response :success
    assert_select '#add_card_with_defaults', :count => 1
    assert_select '.magic_card', :count => 0
  end

  def test_should_not_show_quick_add_button_to_anonymous_user
    set_anonymous_access_for(@project, true)
    logout_as_nil
    change_license_to_allow_anonymous_access
    get :list, :project_id => @project.identifier
    assert_select '#add_card_with_defaults', :count => 0
  end
  
  def test_should_not_show_quick_add_button_to_readonly_team_member
    longbob = User.find_by_login('longbob')
    @project.add_member(longbob, :readonly_member)
    login_as_longbob
    
    get :list, :project_id => @project.identifier
    assert_select '#add_card_with_defaults', :count => 0
  end

end
