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
require 'structure_dump'

def redefine_task(*args, &block)
  task_name = Hash === args.first ? args.first.keys[0] : args.first
  existing_task = Rake.application.lookup task_name
  if existing_task
    class << existing_task
      public :instance_variable_set
      attr_reader :actions
    end
    existing_task.instance_variable_set "@prerequisites", FileList[]
    existing_task.actions.shift
    enhancements = existing_task.actions
    existing_task.instance_variable_set "@actions", []
  end
  redefined_task = task(*args, &block)
  enhancements.each {|enhancement| redefined_task.actions << enhancement}
end

def rails_env
  defined?(Rails.env) ? Rails.env : RAILS_ENV
end

def redefine_task(args, &block)
  Rake::Task.redefine_task(args, &block)
end

namespace :db do
  redefine_task :drop => :environment do
    begin
      config = ActiveRecord::Base.configurations[environment_name]
      ActiveRecord::Base.establish_connection(config)
      db = ActiveRecord::Base.connection.database_name
      ActiveRecord::Base.connection.recreate_database(db)
    rescue
    end
  end

  namespace :rds11g do
    desc "recreate dev, test, and upgrade schemata on the dev RDS Oracle 11g instance; MUST run with DB=rds11g"
    task :recreate => :environment do
      require "development/tools/dev_oracle_helper"
      DevOracleHelper.recreate_users([:dev, :test, :upgrade])
    end

    desc "drop dev, test, and upgrade schemata on the dev RDS Oracle 11g instance; MUST run with DB=rds11g"
    task :drop => :environment do
      require "development/tools/dev_oracle_helper"
      DevOracleHelper.drop_users([:dev, :test, :upgrade])
    end
  end

  namespace :structure do
    desc "take a database dump to create db/oracle_structure.sql cache file, should connect to Oracle 11g"
    task :oracle_dump => :environment do
      raise "should connect to oracle database" if ActiveRecord::Base.connection.database_vendor != :oracle
      StructureDump.new('oracle').dump
    end

    task :pg_dump => :environment do
      raise "should connect to postgres database" if ActiveRecord::Base.connection.database_vendor != :postgresql
      StructureDump.new('postgresql').dump
    end

    redefine_task :dump => "db:test:purge" do
      abcs = ActiveRecord::Base.configurations
      ActiveRecord::Base.establish_connection(abcs[Rails.env])
      StructureDump.new(Rails.env).dump
    end
  end

  namespace :test do
    redefine_task :clone_structure => "db:structure:dump" do
      abcs = ActiveRecord::Base.configurations
      ActiveRecord::Base.establish_connection(:test)
      StructureDump.new(Rails.env).load
    end

    redefine_task :purge => :environment do
      abcs = ActiveRecord::Base.configurations
      config = abcs["test"]
      db = if config['url'] =~ /postgres/
        config['url'] =~ /(\w+)$/
        $1
      else
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection.database_name
      end
      ActiveRecord::Base.connection.recreate_database(db)
    end
  end


  task :refresh_oracle_structure_dump => ['db:drop', 'db:migrate', 'db:structure:oracle_dump']
  task :refresh_pg_structure_dump => ['db:drop', 'db:migrate', 'db:structure:pg_dump']
end
