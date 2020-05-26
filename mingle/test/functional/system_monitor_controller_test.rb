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

class SystemMonitorControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller SystemMonitorController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_render_actions_success
    [:caching].each do |action|
      get action
      assert_response :success
    end
  end

  def test_render_thread_dump
    does_not_work_without_jruby do
      get :thread_dump
      assert_response :success
    end
  end

  def test_cache_stats_include_project_cache
    get :caching
    assert_select 'div#project_cache_stat'
  end
end
