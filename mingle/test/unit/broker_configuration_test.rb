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

class BrokerConfigurationTest < ActiveSupport::TestCase

  def test_load_should_generate_broker_yml_if_it_does_not_exist
    defaults = Messaging::Adapters::JMS::BrokerConfiguration::DEFAULTS
    FileUtils.rm_rf(config_file = RailsTmpDir.file_name('test_broker_config.yml'))
    expected = { 'username' => defaults[:username], 'password' => defaults[:password], 'uri' => defaults[:uri] }
    assert_equal expected, Messaging::Adapters::JMS::BrokerConfiguration.load(config_file)
    assert File.exist?(config_file)
  ensure
    FileUtils.rm_rf(config_file)
  end

  def test_load_should_add_setting_to_disable_prefetch_when_yaml_does_not_have_it_set
    FileUtils.rm_rf(config_file = RailsTmpDir.file_name('test_broker_config.yml'))
    config_content_for_2_3_1 = { 'username' => 'mingle', 'password' => 'password', 'uri' => 'vm://localhost?create=false' }
    File.open(config_file, "w") { |file| file.write(config_content_for_2_3_1.to_yaml) }
    Messaging::Adapters::JMS::BrokerConfiguration.load(config_file)
    assert File.exist?(config_file)
    assert_equal 'vm://localhost?create=false&jms.prefetchPolicy.all=0', YAML::load_file(config_file)['uri']

    uri = "failover:(tcp://localhost:61616?create=false,tcp://remotehost:1234)?something=foo&jms.prefetchPolicy.all=0"
    config_content_for_2_3_1 = { 'username' => 'mingle', 'password' => 'password', 'uri' => uri }
    File.open(config_file, "w") { |file| file.write(config_content_for_2_3_1.to_yaml) }
    Messaging::Adapters::JMS::BrokerConfiguration.load(config_file)
    assert File.exist?(config_file)
    assert_equal uri, YAML::load_file(config_file)['uri']

  ensure
    FileUtils.rm_rf(config_file)
  end

  def test_load_should_not_modify_prefetch_setting_when_yaml_already_has_it_set
    FileUtils.rm_rf(config_file = RailsTmpDir.file_name('test_broker_config.yml'))
    config_content_for_2_3_1 = { 'username' => 'mingle', 'password' => 'password', 'uri' => 'vm://localhost?create=false&jms.prefetchPolicy.all=FUBAR' }
    File.open(config_file, "w") { |file| file.write(config_content_for_2_3_1.to_yaml) }
    Messaging::Adapters::JMS::BrokerConfiguration.load(config_file)
    assert File.exist?(config_file)
    assert_equal 'vm://localhost?create=false&jms.prefetchPolicy.all=FUBAR', YAML::load_file(config_file)['uri']
  ensure
    FileUtils.rm_rf(config_file)
  end

end
