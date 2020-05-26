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

require 'lib/build/transport'

module Mingle
  class OracleDriver
    SSH_CON_SPEC = [
      ENV["SSH_SPEC_HOST"] || "oracle-database-host-not-configured",
      ENV["SSH_SPEC_ACCOUNT"] || "db-user-to-connect-database-not-configured",
      ENV["SSH_SPEC_PASSWORD"] || "db-password-to-connect-database-not-configured"
    ]

    def setup_env
    end

    def self.adapter_name
      'oracle'
    end

    def initialize(database)
      @database = database
    end

    def import(dump_file)
      `/usr/local/bin/mingle_cruise_utils.sh import #{ENV['DATABASE_USERNAME']} #{ENV['DATABASE_PASSWORD']} #{@database.username} #{dump_file} #{@database.name} #{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'}`
    end

    def import_with_ssh(dump_file)
      setup_env
      remote_db_dump_basedir = ENV["DUMP_DB_ROOT_PATH"].blank? ? "/var/lib/cruise-agent/dbdump" : ENV["DUMP_DB_ROOT_PATH"]
      ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
      ssh.executeCommand("/usr/local/bin/mingle_cruise_utils.sh import #{@database.username} #{@database.username} #{@database.username} #{remote_db_dump_basedir}/#{dump_file} #{@database.username} #{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'}")
      ssh = nil
    end

    def recreate_with_ssh
      setup_env
      remote_db_dump_basedir = ENV["DUMP_DB_ROOT_PATH"].blank? ? "/var/lib/cruise-agent/dbdump" : ENV["DUMP_DB_ROOT_PATH"]
      ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
      ssh.executeCommand("/usr/local/bin/mingle_cruise_utils.sh recreate #{ENV['DATABASE_USERNAME']} #{ENV['DATABASE_PASSWORD']} #{@database.username} #{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'}")
      ssh = nil
    end

    def recreate
      setup_env
      `/usr/local/bin/mingle_cruise_utils.sh recreate #{ENV['DATABASE_USERNAME']} #{ENV['DATABASE_PASSWORD']} #{@database.username} #{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'}`
      raise "Error recreating #{@database.name}" if $?.exitstatus == 1
    end

    def dump(file)
      setup_env
      `exp #{@database.username}/#{@database.username}@#{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'} FILE=#{file}`
      `imp #{@database.username}/#{@database.username}@#{ENV['CRUISE_ORACLE_INSTANCE'] || 'oracle-instance-on-continuous-integration-server-not-configured'} FILE=#{file} indexfile=#{file}.ind full=y`
      outfile = File.new("#{file}.ind.sh", File::RDWR|File::TRUNC|File::CREAT, 0755)
      outfile.puts "#!/bin/sh"
      outfile.puts "sqlplus $1/$1@$2 << EOF > /dev/null"
      indfile = "#{file}.ind"
      File.open("#{file}.ind",'r') do |infile|
        while line=infile.gets
                line = line.sub(/"#{@database.username.upcase}"\./,"")
                line = line.sub(/"#{@database.username.upcase}"/,"$1")
                if (!line.match(/^REM  /).nil?)
                        line = line.sub(/^REM  /,'')
                end
		if (line.match(/^CONNECT/).nil? && line.match(/^\.\.\./).nil?)
			outfile.puts line
		end
        end
      end
      outfile.puts "EOF"
      outfile.close
      raise "Error dumping database" if $?.exitstatus == 1
    end

  end

  class PostgresDriver
    SSH_CON_SPEC = [
        ENV["SSH_SPEC_HOST"] || "postgres-database-host-not-configured",
        ENV["SSH_SPEC_ACCOUNT"] || "db-user-to-connect-database-not-configured",
        ENV["SSH_SPEC_PASSWORD"] || "db-password-to-connect-database-not-configured"
    ]

    def self.adapter_name
      'postgresql'
    end

    def initialize(database)
      @database = database
    end

    def import(dump_file)
      setup_env
      if File.extname(dump_file) == ".gz"
        `gunzip -c #{dump_file} | psql #{for_user_and_db_name}`
      else
        `psql -f #{dump_file} #{for_user_and_db_name}`
      end
      raise "Error import data to #{@database.name}" if $?.exitstatus == 1
    end

    def import_with_ssh(dump_file)
      puts "SSH Host (import with ssh) : #{SSH_CON_SPEC[0]}"
      if ( SSH_CON_SPEC[0] == "localhost")

        import(ENV["DUMP_DB_ROOT_PATH"].blank? ? "/var/lib/cruise-agent/dbdump" : ENV["DUMP_DB_ROOT_PATH"] + "/" + dump_file)
      else
        setup_env
        remote_db_dump_basedir = ENV["DUMP_DB_ROOT_PATH"].blank? ? "/var/lib/cruise-agent/dbdump" : ENV["DUMP_DB_ROOT_PATH"]
        ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
        ssh.executeCommand("/usr/local/bin/mingle_cruise_utils.sh importdb #{@database.name} #{remote_db_dump_basedir}/#{dump_file}")
        ssh = nil
      end
    end

    def recreate_with_ssh
      puts "SSH Host (recreate with ssh) : #{SSH_CON_SPEC[0]}"
      if ( SSH_CON_SPEC[0] == "localhost")
        recreate
      else
        setup_env
        ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
        ssh.executeCommand("/usr/local/bin/mingle_cruise_utils.sh recreatedb #{@database.name}") rescue nil #db may not exist
        ssh = nil
        #ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
        #ssh.executeCommand("/usr/local/bin/mingle_cruise_utils.sh createdb #{@database.name}" )
        #ssh = nil
      end
    end

    def recreate
      setup_env
      `dropdb #{for_user_and_db_name}`
      `createdb #{for_user_and_db_name}`
      raise "Error recreating #{@database.name}" if $?.exitstatus == 1
    end

    def dump(file)
      setup_env
      `pg_dump -x -O -f #{file} #{for_user_and_db_name}`
      raise "Error dumping database" if $?.exitstatus == 1
    end

    private

    def for_user_and_db_name
      %{-U "#{@database.username}" -h #{@database.host} #{@database.name}}
    end

    def setup_env
      ENV['PGHOST']     = @database.host if @database.host
      ENV['PGPORT']     = @database.port.to_s if @database.port
      ENV['PGPASSWORD'] = @database.password if @database.password
    end
  end

  class Database < Struct.new(:name, :adapter, :host, :port, :username, :password)
    SUPPORTED_DRIVERS = [PostgresDriver, OracleDriver]

    class << self
      def create_from_env(env)
        create_from_config(ActiveRecord::Base.configurations[env])
      end

      def create_from_config(config)
        new do |db|
          db.adapter, db.host, db.port, db.name = config['url'] ?
                          split_jdbc_url(config['url']) :
                          [config['adapter'], config['host'], config['port'], config['database']]
          db.username = config['username']
          db.password = config['password']
        end
      end

      def split_jdbc_url(jdbc_url)
        leading, adapter, host_port_and_database = jdbc_url.split(/:/, 3)
        host = ''
        port = ''
        database = ''
        if (adapter == 'oracle')
            host_port_and_database.gsub!(/\@/,'')
            notused, host, port, database = host_port_and_database.split(/:/,4)
        else
            host_port_and_database.gsub!(/\/\//, '')
            host_and_port, database = host_port_and_database.split(/\//, 2)
            host, port = host_and_port.split(/:/, 2)
        end
        [adapter, host, port, database]
      end
    end

    def initialize(&block)
      yield(self)
      raise 'you must assign an adapter' unless adapter
      raise 'you must give a name' unless name
    end

    def connection_spec
      {:database => name, :adapter => adapter, :host => host, :port => port, :username => username, :password => password}
    end

    def adapter=(adapter_name)
      super(adapter_name)
      driver_class = SUPPORTED_DRIVERS.detect { |driver| driver.adapter_name == adapter_name }
      raise "Adapter #{adapter_name} is not supported" unless driver_class
      @driver = driver_class.new(self)
    end

    def propagate_to(databases)
      tmp_dump_file = RailsTmpDir::Database.file.basename
      dump_to(tmp_dump_file)
      databases.each do |db_name|
        create_db_with_same_setting_and_new(db_name).restore_from(tmp_dump_file)
      end
    end

    def restore_from(dump_file)
      recreate
      @driver.import(dump_file)
    end

    def restore_from_with_ssh(dump_file)
      recreate_with_ssh
      @driver.import_with_ssh(dump_file)
    end

    def recreate_with_ssh
      @driver.recreate_with_ssh
    end

    def recreate
      @driver.recreate
    end

    def dropdb
      @driver.dropdb
    end

    def dump_to(file)
      FileUtils.rm(file) if File.exist?(file)
      FileUtils.mkdir_p(File.dirname(file))
      puts "Dumping database #{name} to #{file}"
      @driver.dump(file)
    end

    private
    def create_db_with_same_setting_and_new(db_name)
      self.class.new do |db|
        db.name = db_name
        db.adapter, db.host, db.port, db.username, db.password = [adapter, host, port, username, password]
      end
    end
  end
end
