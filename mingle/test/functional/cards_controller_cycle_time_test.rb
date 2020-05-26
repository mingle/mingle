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

class CardsControllerCycleTimeTest < ActionController::TestCase
  def setup
    @controller = create_controller CardsController
    login_as_admin
    MingleConfiguration.cycle_time_server_url = "http://fake.cycle.time.server.url"
  end

  def teardown
    MingleConfiguration.cycle_time_server_url = nil
  end

  def test_should_not_show_cta_frame_if_cycle_time_server_url_is_not_definied
    MingleConfiguration.with_cycle_time_server_url_overridden_to("") do
      get :list, :project_id => first_project.identifier, :style => 'grid', :group_by => 'status'
      assert_select "iframe.cta_frame", :count => 0
    end
  end

  def test_should_include_cta_link_in_grid_view_if_enabled
    get :list, :project_id => first_project.identifier, :style => 'grid', :group_by => 'status'
    assert_select "iframe.cta_frame"
    assert_select "div.cta_frame_wrapper"
  end

  def test_should_not_include_cta_link_in_grid_view_if_no_group_by_property_selected
    get :list, :project_id => first_project.identifier, :style => 'grid'
    assert_select "iframe.cta_frame", :count => 0
  end

  def test_include_project_feed_url_as_part_of_cta_url
    get :list, :project_id => first_project.identifier, :style => 'grid', :group_by => 'status'
    expected_url = "/api/v2/projects/#{first_project.identifier}.xml"
    assert_select 'iframe[src=?]', /.*#{CGI::escape(expected_url)}.*/
  end

end
