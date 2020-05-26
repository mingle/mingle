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

class DatabaseHelperTest < ActiveSupport::TestCase

  def setup
    @test_config = File.join(Rails.root, 'test', 'config')
    @config_dir = File.join(@test_config, 'tmp')
    FileUtils.makedirs(@config_dir)
  end

  def teardown
    ActiveRecord::Base.unstub(:connection)
    FileUtils.rm_rf(@config_dir)
  end

  def test_db_config_file_should_return_database_yml_from_rails_root_config_dir

    assert_equal(File.join(Rails.root, 'config',DatabaseHelper::DATABASE_YML), DatabaseHelper.new(@config_dir).db_config_file)
  end

  def test_db_config_file_should_return_db_config_file_for_correct_pg_config_file
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), pg_config_yml)

    assert_equal(File.join(@config_dir, DatabaseHelper::DATABASE_YML), DatabaseHelper.new(@config_dir).db_config_file)
    assert_equal(pg_config_yml, File.read(File.join(@config_dir, DatabaseHelper::DATABASE_YML)))
  end

  def test_db_config_file_should_return_db_config_file_for_correct_oracle_config_file
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), oracle_config_yml)

    assert_equal(File.join(@config_dir, DatabaseHelper::DATABASE_YML), DatabaseHelper.new(@config_dir).db_config_file)
    assert_equal(oracle_config_yml, File.read(File.join(@config_dir, DatabaseHelper::DATABASE_YML)))
  end


  def test_db_config_file_should_return_new_db_config_file_for_in_correct_pg_config_file
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), old_pg_config_yml)

    assert_equal(File.join(@config_dir, DatabaseHelper::NEW_RAILS_DATABASE_YML), DatabaseHelper.new(@config_dir).db_config_file)
    assert_equal(pg_config_yml, File.read(File.join(@config_dir, DatabaseHelper::NEW_RAILS_DATABASE_YML)))
  end

  def test_db_config_file_should_return_new_db_config_file_for_in_correct_oracle_config_file
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), old_oracle_config_yml)

    assert_equal(File.join(@config_dir, DatabaseHelper::NEW_RAILS_DATABASE_YML), DatabaseHelper.new(@config_dir).db_config_file)
    assert_equal(oracle_config_yml, File.read(File.join(@config_dir, DatabaseHelper::NEW_RAILS_DATABASE_YML)))
  end

  def test_db_config_file_should_handle_erb_file
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), pg_config_erb)

    assert_equal(pg_config_yml, File.read(DatabaseHelper.new(@config_dir).db_config_file))
  end

  def test_should_not_setup_db_when_database_yml_does_not_exist

    assert_false DatabaseHelper.new(@config_dir).setup
  end

  def test_should_setup_db_when_database_yml_exists
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), old_pg_config_yml)
    ActiveRecord::Base.expects(:establish_connection).with({
                                                               'adapter'=> 'postgresql',
                                                               'url' => 'jdbc:postgresql://localhost:5432/test_db'
                                                           })
    ActiveRecord::Base.expects(:connection).returns(OpenStruct.new(active?: true))
    assert DatabaseHelper.new(@config_dir).setup
  end

  def test_setup_db_should_throw_exception_when_db_config_is_not_correct
    File.write(File.join(@config_dir, DatabaseHelper::DATABASE_YML), old_pg_config_yml)
    ActiveRecord::Base.expects(:establish_connection).with({
                                                               'adapter'=> 'postgresql',
                                                               'url' => 'jdbc:postgresql://localhost:5432/test_db'
                                                           })
    connection_obj = OpenStruct.new(active?: true)
    connection_obj.expects(:active?).raises(Exception.new("Incorrect config"))
    ActiveRecord::Base.expects(:connection).returns(connection_obj)
    exception = assert_raises Exception do
      DatabaseHelper.new(@config_dir).setup
    end
    assert_equal "Incorrect config", exception.message
  end

  private

  def pg_config_yml
    config = {
        test: {
            adapter: 'postgresql',
            url: 'jdbc:postgresql://localhost:5432/test_db'
        }
    }.deep_stringify_keys
    config.to_yaml
  end

  def pg_config_erb
    config = {
        test: {
            adapter: 'jdbc',
            url: '<%= "jdbc:postgresql://localhost:5432/#{Rails.env}_db" %>'
        }
    }.deep_stringify_keys
    config.to_yaml
  end

  def old_pg_config_yml
    config = {
        test: {
            adapter: 'jdbc',
            url: 'jdbc:postgresql://localhost:5432/test_db'
        }
    }.deep_stringify_keys
    config.to_yaml
  end

  def oracle_config_yml
    config = {
        test: {
            adapter: 'oracle_enhanced',
            url: 'jdbc:oracle:thin:@database.com:1521:DB_NAME'
        }
    }.deep_stringify_keys
    config.to_yaml
  end

  def old_oracle_config_yml
    config = {
        test: {
            adapter: 'jdbc',
            url: 'jdbc:oracle:thin:@database.com:1521:DB_NAME'
        }
    }.deep_stringify_keys
    config.to_yaml
  end
end
