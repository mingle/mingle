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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class MaintenanceTest < ActiveSupport::TestCase

  def setup
    @app = lambda {}
  end

  def test_should_invoke_call_on_app_with_env
    @app.expects(:call).with('env').once

    maintenance = Middlewares::Maintenance.new(@app)
    maintenance.call('env')
  end

  def test_should_redirect_to_maintenance_url
    expected = [307, {'Location' => 'some_url'}, '']
    MingleConfiguration.expects(:maintenance_url).returns('some_url').twice

    maintenance = Middlewares::Maintenance.new(@app)
    assert_equal(expected, maintenance.call('env'))
  end

  def test_should_redirect_to_maintenance_url_and_env_path_is_sysadmin
    env = {'PATH_INFO' => 'sysadmin'}

    @app.expects(:call).with(env).once
    MingleConfiguration.expects(:maintenance_url).returns('some_url')

    maintenance = Middlewares::Maintenance.new(@app)
    maintenance.call(env)
  end
end
