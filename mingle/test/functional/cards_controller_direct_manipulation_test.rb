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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class CardsControllerDirectManipulationTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_admin
    @project = first_project
    @project.activate
  end

  def test_add_column_button_appears_when_group_by_enum_property
    get :list, :project_id => @project.identifier, :group_by => { :lane => 'Status' }, :style => 'grid', :lanes => ' ,new'
    assert_select 'th.add_dimension'
  end

  def test_add_column_button_appears_when_only_the_not_set_lane_is_visible
    get :list, :project_id => @project.identifier, :group_by => { :lane => 'Status' }, :style => 'grid', :lanes => ' '
    assert_select 'th.add_dimension'
  end

  def test_with_no_cards_and_no_lanes_specified_the_not_set_lane_and_the_add_column_button_appears
    with_project_without_cards do |project|
      get :list, :project_id => project.identifier, :group_by => { :lane => 'Status' }, :style => 'grid'
      assert_select '.header-title', :text => '(not set)'
      assert_select 'th.add_dimension'
    end
  end

  def test_with_two_visible_lanes_hide_lane_button_is_available_for_both
    with_project_without_cards do |project|
      get :list, :project_id => project.identifier, :group_by => { :lane => 'Status' }, :style => 'grid', :lanes => 'limbo,closed'
      assert_select '.hide-lane', :count => 2
    end
  end

  def test_with_one_visible_lane_hide_lane_button_is_not_available
    with_project_without_cards do |project|
      get :list, :project_id => project.identifier, :group_by => { :lane => 'Status' }, :style => 'grid', :lanes => 'limbo'
      assert_select '.hide-lane', :count => 0
    end
  end

end
