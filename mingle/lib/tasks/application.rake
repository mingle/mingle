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
require 'rake/testtask'
require 'fileutils'
require 'code_statistics'

require 'lib/build/hierarchy_test'
require 'lib/build/redefine_task'
require 'lib/ruby_ext'

require 'honeybadger/tasks'

def destroy_browsers
  puts 'Force-killing stray browsers...'
  if windows?
    system('taskkill /F /IM iexplore.exe /T')
    system('taskkill /F /IM firefox.exe /T')
  else
    unless mac?
      system('killall firefox-bin firefox')
      system('killall chrome')
    end
  end
end

STATS_DIRECTORIES.push(['Acceptance tests', 'test/acceptance'])
CodeStatistics::TEST_TYPES.push('Acceptance tests')

desc 'Runs all precommit tests, then performs local svn adds and deletes.'
redefine_task :default => %w(test:precommit svn:add svn:delete svn:st)

desc 'Runs all changed/added tests locally'
task :changed => ['test:changed']

desc 'Updates from subversion, then runs all precommit tests.'
task :precommit => %w(svn:up test:precommit svn:st)

desc 'Runs all tests, including full acceptance suite.'
redefine_task :test => %w(checkstyle test:upgrade_export test:units test:functionals test:acceptance)

desc 'Used by cruise to print errors as they occur. This is so we can diagnose build failures while the build is still running'
task :verbose_test_log do
  ENV['TESTOPTS']='-v'
end

desc 'show all the pending tests'
task :show_pending_tests do
  FileList[File.join(Rails.root, 'test', 'acceptance/**/*_test.rb')].each do |file|
    File.open(file) do |file_content|
      line_number = 0
      while line=file_content.gets
        line_number += 1
        if line =~ /pending "/
          while line = file_content.gets
            test_name = line[/test_.*/]
            break if test_name.present?
          end
          puts file_content.path.gsub(Rails.root,'') + ":#{line_number} ------- " + test_name
        end
      end
    end
  end
end


task :cleanup_tmp do
  FileUtils.rm_rf('tmp')
  FileUtils.rm_rf('log')
  raise 'cannot clean log dir' if File.exist?('./log')
end

desc 'clear out the elastic search indexes under data dir'
task :clean_elastic_search_dir => [:environment] do
  FileUtils.rm_rf File.join(MINGLE_DATA_DIR, 'elastic_search_data')
end

desc 'remove public/attachments'
task :cleanup_attachments do
  Dir.entries('public').select { |f| f=~/^attachments(_\d+)?/ }.each do |f|
    FileUtils.rm_rf("public/#{f}")
  end
end

desc 'clear all tmp, log, attachments'
task :clean_all => %w(cleanup_tmp clean_elastic_search_dir cleanup_attachments)

desc 'Recompiles the card_query and formula_properties grammars'
task :grammar do
  raise 'Please install racc 1.4.5 by running `ruby setup.rb` in vendor/gems/racc-1.4.5.' unless system('which racc')
  system('racc lib/card_query.grammar')
  system('racc lib/mql.grammar')
  system('racc lib/formula_properties.grammar')
end

desc 'Get a list of the features toggles in a toggles.txt file or specify file by env variable TOGGLES_FILE_NAME'
task :list_feature_toggles do
  filename = ENV['TOGGLES_FILE_NAME'] || 'feature_toggles.txt'
  dirname = File.dirname(filename)
  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)

  content = "List of feature toggles in Mingle:\n\n"
  MingleConfiguration::FEATURE_TOGGLES.each {|t| content = content + "* #{t}\n"}

  File.open(filename, 'w') do |file|
    file.write(content)
    puts "####### Feature toggles written to => #{file.path}\n\n#{content}"
  end
end

namespace :svn do
  task :st do
    puts %x[svn st]
  end

  task :up do
    puts %x[svn up]
  end

  task :add do
    %x[svn st].split(/\n/).each do |line|
      trimmed_line = line.delete('?').lstrip
      if line[0,1] =~ /\?/
        %x[svn add #{trimmed_line}]
        puts %[added #{trimmed_line}]
      end
    end
  end

  task :clean do
    %x[svn st].split(/\n/).each do |line|
      trimmed_line = line.delete('?').lstrip
      if line[0,1] =~ /\?/
        FileUtils.rm_rf(trimmed_line)
        puts %[removed #{trimmed_line}]
      end
    end
  end

  task :delete do
    %x[svn st].split(/\n/).each do |line|
      trimmed_line = line.delete('!').lstrip
      if line[0,1] =~ /\!/
        %x[svn rm #{trimmed_line}]
        puts %[removed #{trimmed_line}]
      end
    end
  end
end

namespace :db do
  redefine_task :migrate => :environment do
    ActiveRecord::Migrator.migrate('db/migrate/', ENV['VERSION'] ? ENV['VERSION'].to_i : nil)
    Install::PluginMigrations.new.do_migration
    Rake::Task['db:schema:dump'].invoke if ActiveRecord::Base.schema_format == :ruby
    puts '
!!!!!!!!!     Please remember to update oracle and postgres sql dumps     !!!!!!!!!
!!!!                                                                           !!!!
!!!!  ** Please run this against a CLEAN Oracle database!! **                  !!!!
!!!!     Run: DB=rds11g rake db:rds11g:recreate                                !!!!
!!!!     Run: DB=rds11g rake db:migrate db:refresh_oracle_structure_dump       !!!!
!!!!                                                                           !!!!
!!!!   ** Please run this against a CLEAN Postgres database!! **               !!!!
!!!!     Run: dropdb multitenancy; createdb multitenancy                       !!!!
!!!!     Run: DB=multi-pg rake db:migrate db:refresh_pg_structure_dump         !!!!
!!!!                                                                           !!!!
!!!! view diff of db/oracle_structure.sql and db/postgresql_structure.sql,     !!!!
!!!! make sure there are only the changes you expected                         !!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

'
  end

  namespace :structure do
    desc 'drop the database'
    task :drop => :environment do
      abcs = ActiveRecord::Base.configurations
      case abcs[Rails.env]['adapter']
      when 'postgresql'
        ActiveRecord::Base.clear_active_connections!
        drop_database(abcs[Rails.env])
        create_database(abcs[Rails.env])
      when 'oci', 'oracle'
        ActiveRecord::Base.establish_connection(Rails.env)
        ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      else
        raise "Task not supported by '#{abcs[Rails.env]['adapter']}'"
      end
    end
  end


  namespace :test do
    redefine_task :prepare => :environment do
      require 'memcache_stub'
      MemcacheStub.load

      if defined?(ActiveRecord::Base) && !ActiveRecord::Base.configurations.blank?
        fast_prepare = ENV['FAST_PREPARE'] == 'true'
        Rake::Task['db:test:clone_structure'].invoke unless fast_prepare
        ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
        require File.expand_path(File.dirname(__FILE__) + '/../../test/mocks/project')
        Install::PluginMigrations.new.plugins_need_migration.each do |plugin|
          ActiveRecord::Base.connection.update %{
            UPDATE #{Engines::Plugin::Migrator.schema_info_table_name}
            SET version = #{plugin.latest_migration}
            WHERE plugin_name = '#{plugin.name}'
          }
        end
        require File.expand_path(File.dirname(__FILE__) + '/../../test/unit/unit_test_data_loader')
        UnitTestDataLoader.new.run()
      end
    end

    task :prepare_without_projects => 'db:test:clone_structure' do
      require File.expand_path(File.dirname(__FILE__) + '/../../test/mocks/project')
      Install::PluginMigrations.new.plugins_need_migration.each do |plugin|
        ActiveRecord::Base.connection.update %{
          UPDATE #{Engines::Plugin::Migrator.schema_info_table_name}
          SET version = #{plugin.latest_migration}
          WHERE plugin_name = '#{plugin.name}'
        }
      end
      License.eula_accepted
      require File.expand_path(File.dirname(__FILE__) + '/../../test/unit/unit_test_data_loader')
      UnitTestDataLoader.new.send(:load_users)
    end

    namespace :prepare do
      task :clear_loader_timestamps do
        File.rm_f(File.join(Rails.root, 'test', 'unit', 'loaders', 'timestamps.yml'))
      end
    end
  end
end


namespace :test do |ns|
  Rake::TestTask.new(:run_tests_by_file_name_pattern) do |t|
    t.libs << 'test'
    t.pattern = "test/**/#{ENV['TEST_PATTERN']}*.rb"
    t.verbose = true
  end

  desc 'Runs all tests that can run without a GUI.'
  task :headless => %w(checkstyle db:migrate db:test:prepare test:upgrade_export test:units test:functionals)

  desc 'Runs checkstyle, units, functionals, javascripts.'
  task :precommit => %w(test:headless test:javascripts)

  task :clear_browsers => ['environment'] do
    destroy_browsers
  end

  Rake::TestTask.new(:helpers) do |t|
    t.libs << 'test'
    t.pattern = 'test/unit/**/*_helper_test.rb'
    t.verbose = true
  end

  task :benchmark_all_unit_tests do
    test_files = Dir['test/unit/**/*_test.rb']
    results = test_files.map do |test_file|
      Benchmark.measure{ system "ruby #{test_file}" }
    end
    results.each_with_index do |result, index|
      puts result.to_s + " ***** FROM FILE: #{test_files[index]}"
    end
  end

  def ensure_all_test_files_are_being_executed(expected_files, actual_files, kind_of_tests)
    puts "expected: #{expected_files.size}, actual: #{actual_files.size}"
    root = File.expand_path '../..', File.dirname(__FILE__)
    File.open(File.join(root, 'log', "expected_#{kind_of_tests}.log"), 'w') {|f| f << expected_files.join("\n")}
    File.open(File.join(root, 'log', "actual_#{kind_of_tests}.log"), 'w') {|f| f << actual_files.join("\n")}

    files_not_run = expected_files - actual_files
    File.open(File.join(root, 'log', "not_run_#{kind_of_tests}.log"), 'w') {|f| f << files_not_run.join("\n")}

    raise "You are missing #{files_not_run.join(',')} file(s) in your pattern for test #{kind_of_tests}" if !(files_not_run).empty?
    files_run_more_than_once = actual_files.duplicates
    raise "You are running #{files_run_more_than_once.join(',')} file(s) more then once for test #{kind_of_tests}" if(!files_run_more_than_once.empty?)
  end

  def build_test_groups(glob_patterns, num_jobs)
    all_tests = []

    glob_patterns.each do |pattern|
      all_tests += Dir.glob(pattern)
    end

    all_tests.sort!

    job_groups = ('a'..'z').to_a.map(&:to_sym)[0..(num_jobs - 1)]

    # round-robin distribution
    all_tests.inject({}) do |acc, t|
      key = job_groups.shift
      job_groups << key

      acc[key] ||= []
      acc[key] << t
      acc
    end
  end

  unit_test_file_groupings = build_test_groups(%w(test/unit/**/*_test.rb test/threadsafe/**/*_test.rb), 13)

  unit_test_file_groupings.each do |unit_name, unit_file_group|
    Rake::TestTask.new("units_#{unit_name}" => :verify_all_unit_tests_are_being_run) do |t|
      t.libs << 'test'
      t.libs << 'test/unit'
      t.test_files = unit_file_group.sort
      t.verbose = true
    end
  end

  desc 'run all import-export tests. does not run upgrade tests'
  Rake::TestTask.new('import_export') do |t|
    t.libs << 'test'
    t.test_files = Dir['test/unit/import_export*']
    t.verbose = true
  end

  desc 'verifies all unit tests are being run'
  task :verify_all_unit_tests_are_being_run do
    ensure_all_test_files_are_being_executed(Dir['test/unit/**/*_test.rb'], unit_test_file_groupings.values.flatten, 'units')
  end

  functional_test_file_groupings = build_test_groups(%w(test/functional/**/*_test.rb), 4)

  functional_test_file_groupings.each do |functional_name, functional_file_grouping|
    Rake::TestTask.new("functionals_#{functional_name}" => :verify_all_functional_tests_are_being_run) do |t|
      t.libs << 'test'
      t.test_files = functional_file_grouping
      t.verbose = true
    end
  end

  desc 'verifies all functional tests are being run'
  task :verify_all_functional_tests_are_being_run do
    ensure_all_test_files_are_being_executed(Dir['test/functional/**/*_test.rb'], functional_test_file_groupings.values.flatten, 'functionals')
  end

  Rake::TestTask.new(:google_maps) do |t|
    t.libs << 'test'
    t.libs << File.join(Rails.root, 'vendor', 'rails', 'activesupport', 'lib')
    t.libs << File.join(Rails.root, 'vendor', 'gems', 'rack-1.0.1', 'lib')
    t.pattern = 'vendor/plugins/google_maps_macro/test/**/*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:google_calendar) do |t|
    t.libs << 'test'
    t.libs << File.join(Rails.root, 'vendor', 'rails', 'activesupport', 'lib')
    t.pattern = 'vendor/plugins/google_calendar_macro/test/**/*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:subversion) do |t|
    t.libs << 'test'
    t.pattern = 'vendor/plugins/subversion/test/**/*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:perforce) do |t|
    t.libs << 'test'
    t.pattern = 'vendor/plugins/perforce/test/**/*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:performance_httperf) do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/httperf/**/*test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:memorytest) do |t|
    t.libs << 'test'
    t.pattern = 'test/memory/**/*test.rb'
    t.verbose = true
  end

  task :prep_load_data => :environment do
    abcs = ActiveRecord::Base.configurations
    current_user_name = `whoami`.strip
    if abcs['perf']['adapter'] == 'postgresql'
      ENV['PGHOST']     = abcs['perf']['host'] if abcs['perf']['host']
      ENV['PGPORT']     = abcs['perf']['port'].to_s if abcs['perf']['port']
      ENV['PGPASSWORD'] = abcs['perf']['password'].to_s if abcs['perf']['password']
      enc_option = "-E #{abcs['perf']['encoding']}" if abcs['perf']['encoding']
      ActiveRecord::Base.clear_active_connections!
      `dropdb -U "#{abcs['perf']['username']}" #{abcs['perf']['database']}`
      `createdb #{enc_option} -U "#{abcs['perf']['username']}" #{abcs['perf']['database']}`
      `gunzip test/performance/mingle10.db.dump.gz`
      `test/performance/change_user #{current_user_name} >> test/performance/mingle10.db.dump.current_user`
      `psql -U "#{abcs['perf']['username']}" -d #{abcs['perf']['database']} -f test/performance/mingle10.db.dump.current_user`
      `rm test/performance/mingle10.db.dump.current_user`
      `gzip test/performance/mingle10.db.dump`
    else
      raise "Task not supported by '#{abcs['perf']['adapter']}'"
    end

  end

  task :load_gen => :environment do
    Dir.glob('test/performance/*load*').each do |slush_test|
      `RAILS_ENV=perf ruby #{File.expand_path(slush_test)} >& log/perf.log`
    end
  end

  Rake::TestTask.new(:upgrade_export) do |t|
    t.libs << 'test'
    t.pattern = 'test/upgrade_export_test.rb'
    t.verbose = true
  end

  task :jmeter do
    system('cd test/performance/tools/jakarta-jmeter-2.2/bin && java -jar ApacheJMeter.jar')
  end

  desc 'Set up the database to be in a state like after the initial install wizard'
  task :install => 'db:migrate' do
    License.eula_accepted
    User.create!(:name => 'Arne Admin', :login => 'admin', :email => 'admin@example.com', :password => 'admin1-', :password_confirmation => 'admin1-')
  end

  task :clear_svn_cache do
    FileUtils.rm_rf("#{Rails.root}/tmp/test/cached_svn")
  end

  task :clear_hg_cache do
    FileUtils.rm_rf("#{Rails.root}/tmp/test/cached_hg")
  end

  Rake::TestTask.new(:apis => ['db:test:prepare']) do |t|
    t.libs << 'test'
    t.pattern = 'test/acceptance/**/api*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:scenarios => ['db:test:prepare']) do |t|
    t.libs << 'test'
    t.pattern = 'test/acceptance/**/scenario*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:cards => ['db:test:prepare']) do |t|
    t.libs << 'test'
    t.pattern = 'test/acceptance/**/*card*_test.rb'
    t.verbose = true
  end

  task :changed do
    # move task define inner, because we cannot afford 'svn st' everytime rake loading
    Rake::TestTask.new('_changed') do |t|
      t.libs << 'test'
      tests = FileList.new
      %x[git st].split(/\n/).each do |line|
        if line =~ /deleted:/
          next
        end
        if line =~ /(test\/.*\/.*test.rb)/
          tests.add $1
        end
      end

      t.test_files = tests
      t.verbose = true
    end
    Rake::Task['_changed'].invoke
  end

  Rake::TestTask.new(:pql) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/unit/planner/query/*_test.rb', 'test/unit/ast/**/*_test.rb', 'test/unit/mql_test.rb']
    t.verbose = true
  end

  Rake::TestTask.new(:single_test) do |t|
    t.libs << 'test'
    t.pattern = 'test/unit/smtp_configuration_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:source_plugins) do |t|
    t.libs << 'test'
    t.test_files = FileList['vendor/plugins/subversion/test/**/*_test.rb', 'vendor/plugins/perforce/test/**/*_test.rb']
    t.verbose = true
  end

  Rake::TestTask.new(:curl) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/curl_api/**/*_test.rb']
    t.verbose = true
  end

  Rake::TestTask.new(:non_transactional_units) do |t|
    t.libs << 'test'
    t.pattern = 'test/acceptance/**/non_transactional_units/*_test.rb'
    t.verbose = true
  end


  namespace :installers do
    task :macos => :environment do
      # TODO this does NOT work yet!
      MINGLE_DATA_DIR = File.join(Rails.root, '/tmp/installertest/data')
      FileUtils.mkdir_p(MINGLE_DATA_DIR + '/db')
      # run ant
      # unpack Mingle.app (in .tgz) to tmp/installertest
      # cd tmp/installertest
      # mkdir tmp/installertest/data
      # modify Mingle.app/Content/Info.plist set Java/VMOptions = -Xmx512m -Dmingle.dataDir=/Users/tirsen/Studios/ice/tmp/installertest/data -Dmingle.port=8081
      # open ./Mingle.app
      ENV['BASEURL'] = 'http://localhost:8081'
      ActiveRecord::Base.configurations['test']['url'] = "jdbc:derby:#{MINGLE_DATA_DIR}/db;create=true"
      Rake::Task['test:acceptance'].invoke
    end
  end
end

desc 'Prepare database property file for java tests'
namespace :java do
  task :prepare => :environment do
    file_path = File.expand_path(File.dirname(__FILE__) + '/../../config/database.yml')
    test_environment = YAML.render_file_and_load(file_path)['test']
    properties = {:driver => test_environment['driver'], :username => test_environment['username'], :password => test_environment['password'], :url => test_environment['url']}
    database_properties_file_path = File.expand_path(File.dirname(__FILE__) + '/../../test/data/database.properties')

    File.delete(database_properties_file_path) if File.exists?(database_properties_file_path)
    File.open(database_properties_file_path, 'w') do |file|
      properties.each{ |key, value| file.write "#{key}=#{value}\n"}
    end
  end
end
