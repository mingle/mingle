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

class GlobalConfigManagementTest < ActiveSupport::TestCase

  def setup
    @app  = lambda {}
  end

  def test_should_invoke_call_with_env
    @app.expects(:call).with('env').once

    global_config_management = Middlewares::GlobalConfigManagement.new(@app)
    global_config_management.call('env')

  end

  def test_should_override_global_config_with_given_config
    config = {key1: :val1, key2: :val2}
    MingleConfiguration.expects(:global_config).returns(config).once
    MingleConfiguration.expects(:overridden_to).with(config).once

    global_config_management = Middlewares::GlobalConfigManagement.new(@app)
    global_config_management.call('env')
  end
end
