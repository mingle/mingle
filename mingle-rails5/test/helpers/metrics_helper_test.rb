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

require File.expand_path('../../test_helper', __FILE__)

class MetricsHelperTest < ActiveSupport::TestCase
  include MetricsHelper

  def setup
    create(:user, login: :admin, admin: true)
    login_as_admin
  end
  def test_metrics_should_not_be_enabled_when_login_as_system_user
    User.current.update_attribute('system', true)
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert_false metrics_enabled?
    end
  end

  def test_metrics_enabled_by_api_key_and_existing_user
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert metrics_enabled?
    end
  end

  def test_metrics_should_not_be_enabled_when_no_metrics_api_key_present
    MingleConfiguration.with_metrics_api_key_overridden_to("") do
      assert_false metrics_enabled?
    end
  end

  def test_metrics_should_track_event_when_metrics_api_key_present
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      fake_event_tracker = mock()
      EventsTracker.expects(:new).returns(fake_event_tracker)
      # fake_event_tracker.expects(:track).once
      fake_event_tracker.expects(:track).with(':'+User.current.login, 'site_activity', {:site_name => nil, :trialing => false})

      add_monitoring_event('site_activity',{})
    end
  end

  def test_metrics_should_not_track_event_when_no_metrics_api_key_present
    MingleConfiguration.with_metrics_api_key_overridden_to('') do
      fake_event_tracker = mock()
      EventsTracker.expects(:new).never
      # fake_event_tracker.expects(:track).once
      fake_event_tracker.expects(:track).with(':'+User.current.login, 'site_activity', {:site_name => nil, :trialing => false}).never

      add_monitoring_event('site_activity',{})
    end
  end
end
