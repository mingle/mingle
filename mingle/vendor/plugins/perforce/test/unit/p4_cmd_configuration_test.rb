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

class P4CmdConfigurationTest < ActiveSupport::TestCase
  
  def setup
    P4CmdConfiguration.destroy
  end
  
  def teardown
    P4CmdConfiguration.destroy
  end
  
  def test_should_create_default_p4_cmd_configuration_file_if_it_does_not_exist
    assert_equal 'p4', P4CmdConfiguration.new.load
    assert P4CmdConfiguration.exist?
  end
  
  def test_load_configuration_from_file
    P4CmdConfiguration.new.create('p4_cmd' => '/usr/local/bin/p4')
    assert P4CmdConfiguration.exist?
    assert_equal '/usr/local/bin/p4', P4CmdConfiguration.new.load
    assert P4CmdConfiguration.exist?
  end
  
  def test_should_expand_path_including_unix_home_char
    P4CmdConfiguration.new.create('p4_cmd' => '~/p4')
    assert_equal File.expand_path('~/p4'), P4CmdConfiguration.configured_p4_cmd
  end
  
  def test_perforce_client_configured_p4_cmd
    P4CmdConfiguration.new.create('p4_cmd' => '/usr/local/bin/p4')
    assert_equal '/usr/local/bin/p4', P4CmdConfiguration.configured_p4_cmd
  end
end
