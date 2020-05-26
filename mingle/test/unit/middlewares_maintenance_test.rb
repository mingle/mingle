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

class MiddlewaresMaintenanceTest < Test::Unit::TestCase
  include Middlewares
  def test_should_call_the_app_specified
    output = Maintenance.new(lambda { |*_| 'dummy' }).call({})
    assert_equal output, "dummy"
  end

  def test_should_redirect_to_maintenance_page_when_toggle_is_on
    MingleConfiguration.with_maintenance_url_overridden_to('http://getmingle.io/will_return.html') do
      output = Maintenance.new(lambda { |*_| 'dummy' }).call({})
      assert_equal [307, {'Location' => 'http://getmingle.io/will_return.html'}, ''], output
    end
  end

  def test_should_not_redirect_sysadmin_controller_requests
    MingleConfiguration.with_maintenance_url_overridden_to('http://getmingle.io/will_return.html') do
      output = Maintenance.new(lambda { |*_| 'dummy' }).call({'PATH_INFO' => 'sysadmin'})
      assert_equal 'dummy', output
    end
  end
end
