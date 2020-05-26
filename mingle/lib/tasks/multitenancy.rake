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

namespace :multitenancy do
  namespace :test do
    task :create_site, [:site_name] => [:environment] do |_, args|
      require 'migrator_client'
      portal = MigratorClient.new('http://localhost:#{MINGLE_PORT}')
      portal.create_site(args.site_name)
    end
    task :sites => [:environment] do
      require 'migrator_client'
      portal = MigratorClient.new('http://localhost:#{MINGLE_PORT}')
      puts portal.sites.join("\n")
    end

    task :create_mingle_connection_user => [:environment] do
      username = 'mng_test_user'
      password = 'mng_test_user'
      privileges = [
                    'CREATE USER',
                    'DROP USER',

                    'ANALYZE ANY', # at least for reading index info

                    'CREATE SESSION',
                    'ALTER SESSION',

                    'SELECT ANY SEQUENCE',
                    'CREATE ANY SEQUENCE',
                    'DROP ANY SEQUENCE',
                    'ALTER ANY SEQUENCE',

                    'CREATE ANY INDEX',
                    'DROP ANY INDEX',
                    'ALTER ANY INDEX',

                    'SELECT ANY TABLE',
                    'INSERT ANY TABLE',
                    'LOCK ANY TABLE',
                    'UPDATE ANY TABLE',
                    'DROP ANY TABLE',
                    'FLASHBACK ANY TABLE',
                    'UNDER ANY TABLE',
                    'ALTER ANY TABLE',
                    'CREATE ANY TABLE',
                    'DELETE ANY TABLE',
                    'COMMENT ANY TABLE'
                   ]
      conn = ActiveRecord::Base.connection
      puts "create user #{username}"
      conn.execute "CREATE USER #{username} IDENTIFIED BY #{password} QUOTA UNLIMITED ON users"

      privileges.each do |privilege|
        puts "grant #{privilege}"
        conn.execute "GRANT #{privilege} TO #{username}"
      end
    end
  end
end
