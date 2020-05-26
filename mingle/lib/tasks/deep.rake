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
begin
  require 'rubygems'
  gem 'deep_test', "> 1.0.2"

  require "deep_test/rake_tasks"
  require "daemons"
  task :dt_cruise => [:dt_cruise_prepare, 'deep_test:test']
  task :dt_cruise_prepare => ['deep_test:server:stop', 'deep_test:workers:stop', 'db:migrate', 'db:test:purge', 'deep_test:db_prepare', 'test:clear_svn_cache', 'test:clear_hg_cache', :verbose_test_log]

namespace :deep_test do
  DT_PROCESSES = ENV['DT_PROCESSES'] || 2
  DEEP_TEST_DIR = '/opt/local/lib/ruby/gems/1.8/gems/deep_test-1.0.2'

  class TestDbDumper
    def initialize
      raise 'Sorry, deep test on Mingle for now only support Postgres' unless config['adapter'] == 'postgresql'
    end

    def database
      config["database"]
    end

    def dump
      FileUtils.rm(dump_file_path) if File.exist?(dump_file_path)
      `pg_dump -U "#{db_user}" -x -O -f #{dump_file_path} #{database}`
      raise "Error dumping database" if $?.exitstatus == 1
      dump_file_path
    end

    def propagate(databases)
      setup_env
      databases.each do |db|
        `dropdb -U "#{db_user}" #{db}`
        `createdb -U "#{db_user}" #{db}`
        `psql -U "#{db_user}" -f #{dump_file_path} #{db}`
        raise "Error import data to #{db}" if $?.exitstatus == 1
      end
    end

    private

    def setup_env
      ENV['PGHOST']     = config["host"] if config["host"]
      ENV['PGPORT']     = config["port"].to_s if config["port"]
      ENV['PGPASSWORD'] = config["password"].to_s if config["password"]
    end

    def db_user
      config["username"]
    end

    def config
      ActiveRecord::Base.configurations['test']
    end

    def dump_file
      File.join(RAILS_TMP_DIR, "test_db_dump.sql")
    end
  end

  desc "cruise build task, run units and functionals in one process, run acceptance in multi-processes"
  task :test => ['checkstyle', 'test:upgrade_export', 'deep_test:server:start', 'deep_test:cruise_uf', 'deep_test:cruise_acc', 'deep_test:server:stop']

  def define_deep_task_run_without_setting_up_server(pattern)
    processes = 2
    pattern = Dir.pwd + "/" + pattern
    begin
      deep_test_lib = "#{DEEP_TEST_DIR}/lib"

      # workers
      starter = "#{DEEP_TEST_DIR}/lib/deep_test/start_workers.rb"
      ruby "-I#{deep_test_lib} #{starter} '#{processes}' '#{pattern}'"

      # loader
      loader = "#{DEEP_TEST_DIR}/lib/deep_test/loader.rb"
      ruby "-I#{deep_test_lib} #{loader} '#{pattern}'"
      Daemons.run("deep_test_worker", :ARGV => ["stop"])
      sleep(5)
    rescue Exception => e
      Daemons.run("deep_test_worker", :ARGV => ["stop"])
      Daemons.run("deep_test_server", :ARGV => ["stop"])
      raise e
    end
  end

  desc "cruise build unit and functional tests"
  task :cruise_uf => :clean_db_locks do
    define_deep_task_run_without_setting_up_server "test/[uf]*/**/*_test.rb"
  end

  desc "cruise build acceptance tests"
  task :cruise_acc => :clean_db_locks do
    define_deep_task_run_without_setting_up_server "test/acceptance/**/*_test.rb"
  end

  desc 'clone the test schema and data to paralleled test databases'
  task :db_prepare =>['clean_db_locks', 'db:test:prepare'] do
    dumper = TestDbDumper.new
    dumper.dump
    databases = (0..DT_PROCESSES.to_i).collect { |i| dumper.database + "_#{i}" }
    dumper.propagate(databases)
  end

  desc "run deep test db prepare and acceptance"
  task :acc => ["deep_test:db_prepare", "deep_test:acceptance"]

  desc "run deep test db prepare and acceptance"
  task :acc2 => ["deep_test:db_prepare", "deep_test:server:start", "deep_test:acceptance"]

  desc "run deep test db prepare and scenarios"
  task :sce => ["deep_test:db_prepare", "deep_test:server:start", "deep_test:scenarios"]

  desc "deep test task to run units"
  DeepTest::TestTask.new(:units) do |t|
    t.pattern = "test/unit/**/*_test.rb"
    t.number_of_workers = DT_PROCESSES.to_i
  end
  Rake::Task[:units].prerequisites << 'deep_test:db_prepare'


  desc "deep test task to run all units and functionals"
  DeepTest::TestTask.new(:units_and_functionals) do |t|
    t.pattern = "test/[uf]*/**/*_test.rb"
    t.number_of_workers = DT_PROCESSES.to_i
  end

  desc "deep test task to run functionals"
  DeepTest::TestTask.new(:functionals) do |t|
    t.pattern = "test/functional/**/*_test.rb"
    t.number_of_workers = DT_PROCESSES.to_i
  end
  Rake::Task[:functionals].prerequisites << 'deep_test:db_prepare'

  desc "deep test task to run all acceptance"
  DeepTest::TestTask.new(:acceptance) do |t|
    t.pattern = "test/acceptance/**/*test.rb"
    t.number_of_workers = DT_PROCESSES.to_i
  end

  DeepTest::TestTask.new(:scenarios) do |t|
    t.pattern = 'test/acceptance/**/scenario*_test.rb'
    t.number_of_workers = DT_PROCESSES.to_i
  end

  desc "clean database locks"
  task :clean_db_locks => :environment do
    FileUtils.rm_rf(File.join(RAILS_TMP_DIR, 'db_locks.pstore'))
  end

  desc 'fast db test prepare, use it if you have the date dump file generated by dt task, and test db have not changed since then'
  task :fast_db_prepare => ['clean_db_locks'] do
    dumper = TestDbDumper.new
    databases = (0..DT_PROCESSES.to_i).collect { |i| dumper.database + "_#{i}" }.unshift(dumper.database)
    dumper.propagate(databases)
  end
end

rescue LoadError => e
end

desc "just a db prepare followed by units"
task :dt_units => ['deep_test:db_prepare', 'deep_test:units']

desc "just a db prepare followed by functionals"
task :dt_functionals => ['deep_test:db_prepare', 'deep_test:functionals']

desc "db prepare followed by units and functionals"
task :dt_units_and_functionals => ['deep_test:db_prepare', 'deep_test:units_and_functionals']

desc "precommit running by deep test"
task :dt  => ['checkstyle', 'test:upgrade_export', 'deep_test:db_prepare', 'deep_test:units_and_functionals']
