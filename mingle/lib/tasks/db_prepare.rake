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

namespace :db do
  desc "recreate development database."
  task :recreate_development => :environment do
    having_alive_connection = ActiveRecord::Base.connected?
    ActiveRecord::Base.connection.disconnect! if having_alive_connection
    Mingle::Database.create_from_env('development').recreate
    ActiveRecord::Base.establish_connection if having_alive_connection
  end

  desc "remotely drop and create upgrade export test database"
  task :recreate_upgrade_export_db_with_ssh => :environment do
    db = Mingle::Database.create_from_env('test')
    db.name = 'mingle_test_upgrade_export' #same with UpgradeExportTest::DB_NAME
    db.recreate_with_ssh
  end

  desc "migrate and prep with first_project"
  task :quick do
    original = ENV["LP"]
    begin
      ENV["LP"] = "first_project, simple_program"
      Rake::Task["db:test:migrate_and_prepare"].invoke
    ensure
      ENV["LP"] = original
    end
  end

  namespace :test do
    DUMP_PUBLISHING_FTP_SPEC = {
      :host => ENV["DUMP_PUBLISHING_FTP_SPEC_HOST"] || "ftp-host-to-dump-backup-not-configured",
      :user => ENV["DUMP_PUBLISHING_FTP_SPEC_ACCOUNT"] || "account-for-ftp-host-backup-dumps-not-configured",
      :password => ENV["DUMP_PUBLISHING_FTP_SPEC_PASSWORD"] || "password-for-ftp-host-backup-dumps-not-configured",
      :path => ENV["DUMP_PUBLISHING_FTP_SPEC_PATH"] || "test_db_dump"
    }

    DUMP_SSH_SPEC = {
      :remote_dbdump_path => ENV["DUMP_DB_ROOT_PATH"] || "/var/lib/cruise-agent/dbdump"
    }


    def db_dump_file_name_include_adapter_name_and_revision_info(database)
      raise 'you must has svn info available' if MINGLE_REVISION == 'unsupported'
      basedir = ENV["DUMP_DB_ROOT_PATH"].blank? ? "tmp" : ENV["DUMP_DB_ROOT_PATH"]
      File.join(basedir, "#{database.adapter}_test_database_dump_for_revision_#{MINGLE_REVISION}.sql")
    end

    desc "dump database to DB Server."
    task :create_local_test_db_dump => ['db:test:recreate_local_db','db:migrate', 'db:test:prepare'] do
      test_db = Mingle::Database.create_from_env('test')
      dump_file = db_dump_file_name_include_adapter_name_and_revision_info(test_db)
      test_db.dump_to(dump_file)
    end

    task :create_local_ac_test_db_dump => ['db:test:recreate_local_db','db:migrate', 'db:test:prepare_without_projects'] do
      test_db = Mingle::Database.create_from_env('test')
      dump_file = db_dump_file_name_include_adapter_name_and_revision_info(test_db)
      test_db.dump_to(dump_file)
    end

    task :recreate_local_db => 'environment' do
      test_db = Mingle::Database.create_from_env('test')
      test_db.recreate
    end

    task :create_test_db_dump_and_publish => ['db:migrate', 'db:test:prepare'] do
      test_db = Mingle::Database.create_from_env('test')
      dump_file = db_dump_file_name_include_adapter_name_and_revision_info(test_db)
      test_db.dump_to(dump_file)
      Mingle::Ftp.new(DUMP_PUBLISHING_FTP_SPEC).upload(dump_file)
    end

    desc 'restore test database from database dump published previously, and if it failed falling back to normal db:test:prepare'
    task :fast_prepare => 'environment' do
      begin
        test_db = Mingle::Database.create_from_env('test')
        dump_file = db_dump_file_name_include_adapter_name_and_revision_info(test_db)
        ftp = Mingle::Ftp.new(DUMP_PUBLISHING_FTP_SPEC)
        ftp.download(File.basename(dump_file), dump_file)
        test_db.restore_from(dump_file)
      rescue Exception => e
        puts e.message
        puts "Fail to grab test database dump from #{DUMP_PUBLISHING_FTP_SPEC[:host]} with ftp, fall back to normal migrate and prepare. \n"
        Rake::Task["db:test:migrate_and_prepare"].invoke
      end
    end

    desc 'restore test database from database dump published previously, and if it failed falling back to normal db:test:prepare'
    task :fast_prepare_with_ssh => 'environment' do
      begin
        test_db = Mingle::Database.create_from_env('test')
        raise 'you must has svn info available' if MINGLE_REVISION == 'unsupported'
        test_db.restore_from_with_ssh("#{test_db.adapter}_test_database_dump_for_revision_#{MINGLE_REVISION}.sql")
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
        if test_db
          puts "Fail to grab test database dump using #{test_db.host} with ssh, fall back to normal migrate and prepare. \n"
        else
          puts "Was unable to create test_db"
        end
        Rake::Task["db:test:migrate_and_prepare"].invoke
      end
    end

    desc 'migrate and prepare'
    task :migrate_and_prepare => ["db:migrate", "db:test:prepare"]

  end
end

namespace :paralleled do
  P = ENV['P'] || 8

  desc 'clone the test schema and data to paralleled test databases'
  task :db_prepare => ['clean_db_locks', 'db:test:prepare', 'dump_and_propagate']

  desc "dump_and_propagate test database"
  task :dump_and_propagate => :environment do
    db = Mingle::Database.create_from_env('test')
    databases = (0..P.to_i).collect { |i| db.name + "_#{i}" }
    db.propagate_to(databases)
  end

  desc "clean database locks"
  task :clean_db_locks => :environment do
    FileUtils.rm_rf(File.join(RAILS_TMP_DIR, 'db_locks.pstore'))
  end
end
