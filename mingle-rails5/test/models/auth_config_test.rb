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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AuthConfigTest < ActiveSupport::TestCase

  def test_do_not_check_in_basic_auth_turned_on_yaml_file
    yaml_content = YAML::load_file(File.join(Rails.root, 'config', 'auth_config.yml'))
    assert_nil yaml_content['basic_authentication_enabled']
  end

  def test_load_erb_config_file
    AuthConfiguration.load(File.join(Rails.root, 'test/data/test_config/auth_config.yml.erb'))
    assert_equal 'strict', Authenticator.password_format
  end
end
