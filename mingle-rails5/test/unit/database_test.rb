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

class DatabaseTest < ActiveSupport::TestCase

  def test_need_migration_does_not_fail_when_schema_migrations_table_does_not_exist
    for_postgresql do
      ActiveRecord::Base.connection.execute("DROP TABLE #{ActiveRecord::Migrator.schema_migrations_table_name}")
      assert Database.need_migration?
    end
  end

  def test_migrated_database_does_not_need_migration
    for_postgresql do
      assert_false Database.need_migration?
    end
  end

  def test_database_migrates_when_version_not_current
    for_postgresql do
      with_new_migration do
        Database.send(:reset_last_migration_version)

        assert Database.need_migration?

        Database.migrate

        assert_false Database.need_migration?
      end
    end
  ensure
    Database.send(:reset_last_migration_version)
  end

  def with_new_migration(new_migration_version = Database.send(:last_migration_version) + 1)
    new_migration_file = File.join(Rails.root, 'db', 'migrate', "#{new_migration_version}_test_migration.rb")
    begin
      File.open(new_migration_file, 'w') do |file|
        file.write('
          class TestMigration < ActiveRecord::Migration[5.0]
            def self.up
            end

            def self.down
            end
          end
        ')
      end
      yield
    ensure
      File.delete(new_migration_file)
    end
  end

  def test_database_is_newer_than_installer
    for_postgresql do
      last_migration_version = Database.send(:last_migration_version)
      ActiveRecord::Base.connection.execute("INSERT INTO #{ActiveRecord::Migrator.schema_migrations_table_name} (version)  values (#{last_migration_version + 1})")
      assert Database.newer_than_installer?
    end
  end

  def test_need_config_when_database_not_yet_configured
    override_connection '
      OpenStruct.new(:active? => false)
'
    assert Database.need_config?
  ensure
    rollback_override
  end

  def test_need_config_propagates_ConnectionTimeoutError
    override_connection '
      raise ActiveRecord::ConnectionTimeoutError.new("db pool size exceeded[mocked exception - PLEASE IGNORE]")
'

    assert_raise ActiveRecord::ConnectionTimeoutError do
      Database.need_config?
    end
  ensure
    rollback_override
  end

  def test_returns_true_when_database_connection_Exception
    override_connection('
      raise StandardError.new("could not connect to your database, check config[mocked exception - PLEASE IGNORE]")
')
    assert Database.need_config?
  ensure
    rollback_override
  end

  def override_connection(block)
    ActiveRecord::Base.instance_eval do
      alias :old_connection :connection
    end

    ActiveRecord::Base.instance_eval(%Q[
      def connection
         #{block}
      end
])

  end

  def rollback_override
    ActiveRecord::Base.instance_eval do
      alias :connection :old_connection
    end
  end
end
