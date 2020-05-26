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

class MetricsHelperTest < ActiveSupport::TestCase
  include MetricsHelper

  def test_metrics_should_not_be_enabled_when_login_as_system_user
    login_as_admin
    User.current.update_attribute('system', true)
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert_false metrics_enabled?
    end
  end

  def test_metrics_enabled_by_api_key_and_existing_user
    login_as_admin
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert metrics_enabled?
    end
  end

  def test_metrics_should_not_be_enabled_when_no_metrics_api_key_present
    MingleConfiguration.with_metrics_api_key_overridden_to("") do
      assert_false metrics_enabled?
    end
  end
end
