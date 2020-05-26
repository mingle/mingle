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

class SiteActivityMonitorTest < ActionController::TestCase
  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @member = login_as_member
  end

  def test_site_activity_monitor
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      # use redirect action, so that we can capture the session states
      get :index, :project_id => 'first_project'
      assert_response 302
      assert @controller.events_tracker.sent_event?('site_activity')

      assert @controller.events_tracker.clear
      get :index, :project_id => 'first_project'
      assert_response 302
      assert !@controller.events_tracker.sent_event?('site_activity')

      Cache.flush_all
      get :index, :project_id => 'first_project'
      assert_response 302
      assert @controller.events_tracker.sent_event?('site_activity')
    end
  end
end
