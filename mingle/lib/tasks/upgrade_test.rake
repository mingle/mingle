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
require 'lib/build/database'

namespace :upgrade_test do
  SSH_CON_SPEC = [
    ENV["SSH_SPEC_HOST"] || "bjstdmngdb01.thoughtworks.com",
    ENV["SSH_SPEC_ACCOUNT"] || "mingle_builder",
    ENV["SSH_SPEC_PASSWORD"] || "5MJC%3nvLC"
  ]

  desc 'entry point'
  task :run => [:stop_server, :prepare_dataDir_and_dump,  :recreate_database, :deploy_new_installer, :run_test]
  # task :run => [:run_test]
  # task :run => [:stop_server, :prepare_dataDir_and_dump,  :recreate_database, :deploy_new_installer]
  # desc 'stop service'
  # task :stop do
  #     get_version_number
  #     `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer --mingle.dataDir=#{data_config["test_dataDir"]}/postgres_data/postgres_dataDir/ --instance_#{database}_app1  stop`
  # end

  def get_target_info
    @target_db = ENV['MIGRATE_FROM'].split("_")[0]
    @migrate_from = ENV['MIGRATE_FROM']

  end

  task :prepare_dataDir_and_dump do
    get_target_info
    `rm -rf /tmp/migrate_test`
    `mkdir /tmp/migrate_test`
    `cp -r test/upgrade_test_automation/data/dataDir/#{@migrate_from}_dataDir /tmp/migrate_test/dataDir`
    `mv /tmp/migrate_test/dataDir/public_old /tmp/migrate_test/dataDir/public`

    case @target_db
     when "pg"
       `cp test/upgrade_test_automation/data/dbdump/#{@migrate_from} /tmp/migrate_test/database.dump`;;
       `cp test/upgrade_test_automation/data/database_yml/pg_database.yml /tmp/migrate_test/dataDir/config/database.yml`
     when "ora"
       `cp test/upgrade_test_automation/data/database_yml/ora_database.yml /tmp/migrate_test/dataDir/config/database.yml`
     else
       raise "cannot support #{@target_db} yet!"
    end
  end

  task :stop_server do
    if File.exists? "/tmp/migrate_test/mingle/MingleServer"
      `sh /tmp/migrate_test/mingle/MingleServer --instance=app1 stop`
    end
  end


  task :recreate_database do
    get_target_info
    case @target_db
     when "pg"
         `dropdb mingle_test`
         `createdb mingle_test`
         `psql -d mingle_test -U cruise -f /tmp/migrate_test/database.dump`
     when "ora"
         ssh = Mingle::Ssh.new(*SSH_CON_SPEC)
         ssh.executeCommand ["source set_up_env.sh", "sh restore_#{@migrate_from}.sh"]
         ssh = nil
    end
  end

  def wait_for_server_start
    http = Net::HTTP.new('localhost', 8080)
    while "Starting..." != (http.get('/bootstrap_status').body.strip rescue nil)
        sleep 1
    end
  end

  task :deploy_new_installer do
    `unzip /home/migrate_test/mingle_installer.zip -d /tmp/migrate_test`
    FileUtils.mv(Dir['/tmp/migrate_test/mingle*'][0], "/tmp/migrate_test/mingle")
    `sh /tmp/migrate_test/mingle/MingleServer --instance=app1 stop`
    `sh /tmp/migrate_test/mingle/MingleServer --mingle.dataDir=/tmp/migrate_test/dataDir --instance=app1 start`
    wait_for_server_start
  end


  desc "run all the upgrade test cases"
  task :run_test do
    Rake::TestTask.new('_run_test') do |t|
      t.libs << "test"
      # t.pattern = 'test/upgrade_test_automation/*_test.rb'
      t.test_files = FileList['test/upgrade_test_automation/upgrade_01_initial_steps_test.rb', 'test/upgrade_test_automation/upgrade_02_create_new_elements_test.rb']
      t.verbose = true
    end
    Rake::Task["_run_test"].invoke
  end

  # desc "run all the upgrade test cases"
  # task :run_test do
  #   Rake::TestTask.new('_run_test') do |t|
  #     t.libs << "test"
  #     # t.pattern = 'test/upgrade_test_automation/*_test.rb'
  #     t.test_files = FileList['test/upgrade_test_automation/upgrade_01_initial_steps_test.rb', 'test/upgrade_test_automation/upgrade_02_create_new_elements_test.rb',
  #       'test/upgrade_test_automation/upgrade_04_verify_current_element_test.rb']
  #     t.verbose = true
  #   end
  #   Rake::Task["_run_test"].invoke
  # end

end


# old method that ready to be removed
  # desc 'restore postgres dump to mingle_test'
  # task :restore_postgres  => 'environment' do
  #     get_version_number
  #     test_db = Mingle::Database.create_from_env('test')
  #     dump_file = get_dump_file_name(POSTGRES, @version_from)
  #     test_db.restore_from(dump_file)
  # end

  # desc 'start service with Postgres'
  # task :start_with_postgres do
  #     get_version_number
  #     `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer --mingle.dataDir=#{data_config["test_dataDir"]}/postgres_data/postgres_dataDir/ --instance=postgres_app1  start`
  # end

  # desc 'stop service with Postgres'
  # task :stop_with_postgres do
  #     get_version_number
  #     `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer --mingle.dataDir=#{data_config["test_dataDir"]}/postgres_data/postgres_dataDir/ --instance=postgres_app1  stop`
  # end

  # desc 'clear mysql dataDir'
  # task :clear_mysql_dataDir do
  #     get_version_number
  #     `rm #{data_config["test_dataDir"]}/upgrade_test.sh VERSION_FROM=#{@version_from} VERSION_TO=#{@version_to} db=#{MYSQL} -prepare`
  # end
  #
  #
  # desc 'restore mysql dataDir'
  # task :restore_mysql_dataDir do
  #     get_version_number
  #     `sh #{data_config["test_dataDir"]}/upgrade_test.sh VERSION_FROM=#{@version_from} VERSION_TO=#{@version_to} db=#{MYSQL} -prepare`
  # end

  # def start_service(db_type)
  #   get_version_number
  #   case db_type
  #   when MYSQL
  #     # p "sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer -dataDir=#{data_config["test_dataDir"]}/mysql_data/mysql_dataDir"
  #     `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer -dataDir=#{data_config["test_dataDir"]}/mysql_data/mysql_dataDir --instance=mysql_app1 start`
  #   when POSTGRES
  #     # p "sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer -dataDir=#{data_config["test_dataDir"]}/mysql_data/mysql_dataDir"
  #     `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer -dataDir=#{data_config["test_dataDir"]}/mysql_data/mysql_dataDir --instance=mysql_app1 start`
  #   end
  #
  # end

  # desc "go through the upgrade installation steps"
  # task :initialize do
  #   Rake::TestTask.new(:upgrade_initial_intall) do |t|
  #     t.libs << "test"
  #     t.pattern = 'test/upgrade_test_automation/upgrade_initial_steps_test.rb'
  #     t.verbose = true
  #   end
  #   Rake::Task["upgrade_initial_intall"].invoke
  # end
  #
  # desc "run all the upgrade test cases"
  # task :run do
  #   Rake::TestTask.new(:run_the_upgrade_test_cases) do |t|
  #     t.libs << "test"
  #     t.pattern = 'test/upgrade_test_automation/upgrade_test.rb'
  #     t.verbose = true
  #   end
  #   Rake::Task["run_the_upgrade_test_cases"].invoke
  # end


  # data_config["test_dataDir"] = `echo $UPGRADE_DATA`.strip
  #
  # POSTGRES="postgres"
  # ORACLE="oracle"
  # CONFIG_FILE = "test/upgrade_test_automation/config/target_db.yml"
  #
  #   def data_config
  #     @data_config ||= YAML.load(File.open(CONFIG_FILE))
  #   end
  #
  #   def database
  #     data_config["test"]["database"]
  #   end
  #
  #   def get_version_number
  #     # raise ">>>>>>VERSION_FROM required!<<<<<<" if ARGV[1].nil?
  #     # raise ">>>>>>VERSION_TO required!<<<<<<" if ARGV[2].nil?
  #     # # @version_from = ARGV[1].tr("VERSION_FROM=", '')
  #     # vf = ARGV[1].tr("VERSION_FROM=", '')
  #     # vt = ARGV[2].tr("VERSION_TO=", '')
  #     vf = data_config["test"]["version_from"]
  #     vt = data_config["test"]["version_to"]
  #     if vf >= vt
  #       p  "cannot excute the upgrade from #{vf} to #{vt}!"
  #       exit
  #     end
  #     @version_from = vf.gsub(/\./, "_")
  #     @version_to = vt.gsub(/\./, "_")
  #   end
  #
  #   def get_dump_file_name
  #     case database
  #     when POSTGRES
  #       return File.join("#{data_config["test_dataDir"]}", "postgres_data", "postgres_dump", "pg_#{@version_from}.dump")
  #     when ORACLE
  #       return File.join("#{data_config["test_dataDir"]}", "oracle_data", "oracle_dump", "oracle_#{@version_from}.dmp")
  #     else
  #       puts "something wrong within your file name"
  #     end
  #   end
  #
  #   # desc 'restore mysql dump to mingle_test'
  #   # task :restore_mysql  => 'environment' do
  #   #     get_version_number
  #   #     test_db = Mingle::Database.create_from_env('test')
  #   #     dump_file = get_dump_file_name(MYSQL, @version_from)
  #   #     test_db.restore_from(dump_file)
  #   # end
  #
  #   desc 'restore db dump'
  #   task :prepare  => 'environment' do
  #       get_version_number
  #       case database
  #         when POSTGRES
  #          test_db = Mingle::Database.create_from_env('test')
  #          dump_file = get_dump_file_name
  #          test_db.restore_from(dump_file)
  #         when ORACLE
  #          puts "<<<<<<< Please logon the db server and retore oracle_#{@version_from}.dmp manually!  >>>>>>>"
  #         else
  #          puts "something error!"
  #       end
  #   end
  #
  #   desc 'start service'
  #   task :start do
  #       get_version_number
  #       case database
  #       when POSTGRES
  #       `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer --mingle.dataDir=#{data_config["test_dataDir"]}/postgres_data/postgres_dataDir/ --instance_#{database}_app1  start`
  #       when ORACLE
  #       `sh #{data_config["test_dataDir"]}/mingle_#{@version_to}/MingleServer --mingle.dataDir=#{data_config["test_dataDir"]}/oracle_data/oracle_dataDir/ --instance_#{database}_app1  start`
  #       else
  #        p "cannot connect to the database"
  #       end
  #   end


  #end of Migrate from 2.2 on Postgres
  # desc 'clean database'
  # task :cleanDB do
  #   case database
  #   when POSTGRES
  #     `dropdb mingle_test`
  #     `createdb mingle_test`
  #   when ORACLE
  #     puts "<<<<<<< Please logon the db server and delete the database manually!  >>>>>>>"
  #    else
  #     puts "something wrong within your file name"
  #   end
  # end
