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

module DatabaseTestHelpers
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.instance_eval do
      cattr_accessor :database_vendor, :test_schema_name, :original_schema
    end
  end

  TEST_SCHEMA_NAME = { oracle:  'ORACLE_ENHANCED_ADAPTER_TEST', postgresql: 'POSTGRE_ADAPTER_TEST' }

  module ClassMethods
    def use_db(vendor, schema = TEST_SCHEMA_NAME[vendor])
      self.database_vendor = vendor
      self.test_schema_name = schema || "#{vendor}_test"
      self.instance_eval do
        prepend DatabaseTestHelpers::Helpers
      end
    end

    def method_added(method)
      undef_method(method) if method.to_s =~ /\Atest_/ and ActiveRecord::Base.connection.database_vendor != self.database_vendor
    end
  end


  module Helpers
    ORACLE_PRIVILEGES = ['SELECT ANY SEQUENCE', 'CREATE ANY SEQUENCE', 'DROP ANY SEQUENCE', 'ALTER ANY SEQUENCE',
                         'CREATE ANY INDEX', 'DROP ANY INDEX', 'ALTER ANY INDEX', 'SELECT ANY TABLE', 'LOCK ANY TABLE',
                         'INSERT ANY TABLE', 'UPDATE ANY TABLE', 'DROP ANY TABLE', 'UNDER ANY TABLE', 'ALTER ANY TABLE',
                         'FLASHBACK ANY TABLE', 'CREATE ANY TABLE', 'DELETE ANY TABLE', 'COMMENT ANY TABLE']

    def connection
      ActiveRecord::Base.connection
    end

    def before_setup
      super
      self.class.original_schema = connection.current_schema
      self.send("create_#{self.database_vendor}_schema".to_sym)
      connection.switch_schema(self.class.test_schema_name)
    end

    def after_teardown
      connection.switch_schema(self.class.original_schema)
    ensure
      self.send("drop_#{self.database_vendor}_schema".to_sym)
      super
    end

    private

    def create_oracle_schema
      connection.execute("CREATE USER #{self.class.test_schema_name} IDENTIFIED BY mingle DEFAULT TABLESPACE users QUOTA UNLIMITED ON users TEMPORARY TABLESPACE temp") rescue nil
      connection.execute("GRANT #{ORACLE_PRIVILEGES.join(', ')} TO #{self.class.test_schema_name}")
    end

    def drop_oracle_schema
      connection.execute("DROP USER #{self.class.test_schema_name} CASCADE")
    end

    def create_postgresql_schema
      connection.execute("CREATE SCHEMA IF NOT EXISTS #{self.class.test_schema_name}")
    end

    def drop_postgresql_schema
      connection.execute("DROP SCHEMA IF EXISTS #{self.class.test_schema_name} CASCADE")
    end
  end
end
