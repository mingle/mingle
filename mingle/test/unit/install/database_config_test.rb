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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class Install::DatabaseConfigTest < ActiveSupport::TestCase

  def setup
    @db_configs = YAML.dump(ActiveRecord::Base.configurations)
  end

  def teardown
    ActiveRecord::Base.configurations = YAML.load(@db_configs)
  end

  def test_postgrep_database_should_be_the_first_config
    assert_equal postgres_config, database_config.first
    assert_not_equal oracle_config, database_config.first
  end

  def test_should_find_postgres_database_type_by_default
    assert_equal postgres_config, find_config_type(nil)
    assert_not_equal oracle_config, find_config_type(nil)
  end

  def test_url_for_oracle_config_includes_default_port_if_user_does_not_specify_port
    oracle_config.port = ''
    assert_equal "jdbc:oracle:thin:@localhost:1521:mingle", oracle_config.to_url

    oracle_config.port = ' '
    assert_equal "jdbc:oracle:thin:@localhost:1521:mingle", oracle_config.to_url
  end

  def test_oracle_config_requires_password
    oracle_config = Install::OracleDatabaseConfig.new
    oracle_config.password = ''
    assert !oracle_config.valid?
    assert_equal ["Password can't be blank"], oracle_config.errors.full_messages
  end

  def test_set_rails_configuration_populates_AR_configuration
    params = {
      :host     => 'host',
      :port     => 'port',
      :username => 'username',
      :password => 'password',
      :database => 'database'
    }
    ActiveRecord::Base.configurations[Rails.env] = nil
    config = Install::PostgresDatabaseConfig.new(params)
    config.set_rails_configuration
    expected_configuration = { "url" => "jdbc:postgresql://host:0/database", "username" => "username", "adapter" => "jdbc", "driver" => "org.postgresql.Driver", "password" => "password", 'pool' => 0}
    assert_equal(expected_configuration, ActiveRecord::Base.configurations[Rails.env])
  end

  def test_write_database_yml
    ActiveRecord::Base.configurations.clear
    params = {
      :host     => 'host',
      :port     => 'port',
      :username => 'username',
      :password => 'password',
      :database => 'database'
    }
    full_path = RailsTmpDir.file_name('database_config_test', 'database.yml')
    FileUtils.rm full_path if File.exists?(full_path)
    config = Install::PostgresDatabaseConfig.new(params)
    assert ActiveRecord::Base.configurations.empty?
    config.set_rails_configuration
    config.write_database_yml(full_path)
    expected = { "url" => "jdbc:postgresql://host:0/database", "username" => "username", "adapter" => "jdbc", "driver" => "org.postgresql.Driver", "password" => "password", "pool" => 0}
    assert_database_yml(expected, full_path)
  end

  def test_take_global_variable_connection_pool_size
    $connection_pool_size = 15
    params = {
      :host     => 'host',
      :port     => 'port',
      :username => 'username',
      :password => 'password',
      :database => 'database'
    }
    full_path = RailsTmpDir.file_name('database_config_test', 'database.yml')
    FileUtils.rm full_path if File.exists?(full_path)
    config = Install::PostgresDatabaseConfig.new(params)
    config.set_rails_configuration
    config.write_database_yml(full_path)
    expected = { "url" => "jdbc:postgresql://host:0/database", "username" => "username", "adapter" => "jdbc", "driver" => "org.postgresql.Driver", "password" => "password", "pool" => 15}
    assert_database_yml(expected, full_path)
  ensure
    $connection_pool_size = nil
  end

  def test_establish_connection_raise_exception_when_connection_verify_char_set_raises
    for_oracle do
      database_config = ActiveRecord::Base.configurations[Rails.env]['database'] || ActiveRecord::Base.configurations[Rails.env]['url'].split("@").last
      host, port, database = database_config.split(/[:\/]/)
      username = ActiveRecord::Base.configurations[Rails.env]['username']
      password = ActiveRecord::Base.configurations[Rails.env]['password']
      # p({:host => host, :port => port, :database => database, :username => username, :password => password})

      begin
        pretend_connection_established

        config = Install::OracleDatabaseConfig.new(:host => host, :port => port, :database => database, :username => username, :password => password)
        config.set_rails_configuration
        stub_connection = Object.new
        def stub_connection.verify_charset!
          raise "this is not valid"
        end
        config.connection = stub_connection
        assert_raise_message(RuntimeError, /this is not valid/) do
          config.establish_connection
        end
      ensure
        reenable_establish_connection
      end
    end
  end

  def test_verify_config_pool_size_should_recreate_db_config_when_no_pool_specified_in_config
    $connection_pool_size = 15
    db_config = {
      "url" => "jdbc:postgresql://host:0/database",
      "username" => "username",
      "adapter" => "jdbc",
      "driver" => "org.postgresql.Driver",
      "password" => "password"
    }
    full_path = RailsTmpDir.file_name('database_config_test', 'database.yml')
    FileUtils.rm full_path if File.exists?(full_path)

    Install::DatabaseConfig.verify_pool_size!(db_config, full_path)

    expected = { "url" => "jdbc:postgresql://host:0/database", "username" => "username", "adapter" => "jdbc", "driver" => "org.postgresql.Driver", "password" => "password", "pool" => 15}
    assert_database_yml(expected, full_path)
  ensure
    $connection_pool_size = nil
  end

  def test_verify_config_pool_size_should_update_given_db_config_when_no_pool_specified_in_config
    $connection_pool_size = 15
    db_config = {
      "url" => "jdbc:postgresql://host:0/database",
      "username" => "username",
      "adapter" => "jdbc",
      "driver" => "org.postgresql.Driver",
      "password" => "password"
    }
    temp_file = RailsTmpDir.file_name('database_config_test', 'database.yml')
    Install::DatabaseConfig.verify_pool_size!(db_config, temp_file)

    assert_equal 15, db_config['pool']
  ensure
    $connection_pool_size = nil
  end

  def test_verify_config_pool_size_should_not_update_db_config_when_no_global_variable_connection_pool_size
    $connection_pool_size = nil
    db_config = {
      "url" => "jdbc:postgresql://host:0/database",
      "username" => "username",
      "adapter" => "jdbc",
      "driver" => "org.postgresql.Driver",
      "password" => "password"
    }
    temp_file = RailsTmpDir.file_name('database_config_test', 'database.yml')
    FileUtils.rm_rf(temp_file)
    Install::DatabaseConfig.verify_pool_size!(db_config, temp_file)

    assert_equal nil, db_config['pool']
    assert !File.exist?(temp_file)
  ensure
    $connection_pool_size = nil
  end

  def test_verify_config_pool_size_should_not_update_given_db_config_when_pool_is_specified_in_config
    $connection_pool_size = 15
    db_config = {
      "url" => "jdbc:postgresql://host:0/database",
      "username" => "username",
      "adapter" => "jdbc",
      "driver" => "org.postgresql.Driver",
      "password" => "password",
      'pool' => 12
    }
    temp_file = RailsTmpDir.file_name('database_config_test', 'database.yml')
    FileUtils.rm_rf(temp_file)
    Install::DatabaseConfig.verify_pool_size!(db_config, temp_file)

    assert_equal 12, db_config['pool']
    assert !File.exist?(temp_file)
  ensure
    $connection_pool_size = nil
  end

  protected

  def pretend_connection_established
    ActiveRecord::Base.class_eval do
      def self.establish_connection_with_connection_established
      end

      class << self
        alias_method_chain :establish_connection, :connection_established
      end
    end
  end

  def reenable_establish_connection
    ActiveRecord::Base.class_eval do
      class << self
        alias_method :establish_connection, :establish_connection_without_connection_established
      end
    end
  end

  def find_config_type(database_type)
    Install::DatabaseConfig.find_database_type(database_type)
  end

  def database_config
    Install::DatabaseConfig::CONFIGS
  end

  def postgres_config
    Install::PostgresDatabaseConfig
  end

  def oracle_config
    Install::OracleDatabaseConfig.new
  end

  def assert_database_yml(expected, full_path)
    db_confs = YAML::load_file(full_path)
    assert_equal([String], db_confs.keys.map(&:class).uniq) # make sure that all keys are strings to solve the bug #14055
    assert_equal(expected, db_confs[Rails.env.to_s])
  end
end
