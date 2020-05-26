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
require 'fileutils'
require 'ci/reporter/rake/test_unit'
require 'lib/build/process_ids'
require 'lib/build/transport'

namespace :cruise do
  task :oracle_database_yml do
    FileUtils.cp 'config/database.yml.cruise-oracle', 'config/database.yml'
  end
  task :postgres_database_yml do
    FileUtils.cp 'config/database.yml.cruise-pgsql', 'config/database.yml'
  end

  def prepare_dependencies
    %w(clean_all log_pid ci:setup:testunit test:clear_svn_cache).tap do |dependencies|
      unless mac?
        insert_before_this = dependencies.index("ci:setup:testunit")
        dependencies.insert(insert_before_this, "db:test:fast_prepare_with_ssh")
      end
    end
  end

  def prepare_acceptance_dependencies
    %w(clean_all log_pid ci:setup:testunit test:clear_svn_cache test:clear_hg_cache).tap do |dependencies|
      unless mac?
        insert_before_this = dependencies.index("ci:setup:testunit")
        dependencies.insert(insert_before_this, "db:test:fast_prepare_with_ssh")
        dependencies.insert(insert_before_this, "test:clear_browsers")
      end
    end
  end

  task :prepare => prepare_dependencies

  task :prepare_with_browser_clean => prepare_acceptance_dependencies do
    if windows?
      puts "Clearing IE cache..."
      system("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255")
    end
  end

  desc "publish mingle installers"
  task :publish_installers do
    installer_ver = ENV["INSTALLER_VERSION"] || "0"
    dist = ENV["INSTALLER_PATH"] || "/tmp"
    installer_path = File.join(dist, installer_ver)
    FileUtils.mkdir_p(installer_path)
    MINGLE_REVISION = Mingle::Revision::CURRENT
    FileUtils.cp("dist/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz", "#{installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz")
    FileUtils.cp("dist/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz.md5sum", "#{installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz.md5sum")
    FileUtils.cp("dist/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe", "#{installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe")
    FileUtils.cp("dist/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe.md5sum", "#{installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe.md5sum")

    if File.exists?("tmp/installers_link.html")
      File.delete("tmp/installers_link.html")
    end
    export_installer_links(installer_ver)
  end

  desc "Update release installers"
  task :update_release_installer do
    raise 'INSTALLER_VERSION needs to be set to the version being released. Example 18_1' if ENV['INSTALLER_VERSION'].blank? || ENV['INSTALLER_VERSION'] == 'dev'
    installer_ver = ENV['INSTALLER_VERSION']
    dist = ENV["INSTALLER_PATH"] || "/tmp"
    release_installer_path = File.join(dist, installer_ver)
    dev_installer_path = File.join(dist, 'dev')
    MINGLE_REVISION = Mingle::Revision::CURRENT
    FileUtils.cp("#{dev_installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz", "#{release_installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz")
    FileUtils.cp("#{dev_installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz.md5sum", "#{release_installer_path}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz.md5sum")
    FileUtils.cp("#{dev_installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe", "#{release_installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe")
    FileUtils.cp("#{dev_installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe.md5sum", "#{release_installer_path}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe.md5sum")
    export_installer_links(installer_ver)
  end

  def export_installer_links(installer_ver)
    dlserver = ENV["INSTALLER_DOWNLOAD_SERVER"] || "https://fremont-mingle-installer.thoughtworks.com"
    unix_url = "#{dlserver}/#{installer_ver}/mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz"
    win32_url = "#{dlserver}/#{installer_ver}/mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe"
    dlhtml = File.new("tmp/installers_link.html", "w")
    dlhtml.print "<h2> Mingle Installers (VERSION #{installer_ver}) (REV #{MINGLE_REVISION}) </h2>\n"
    dlhtml.print "<p> If you are not authorized to download the installer, please check with Scott Turnquest.<br/>They will need to add you to the <b>MingleCIBuildDownloadGroup</b> in Corporate Active Directory<br/>before you can access the installer download site </p>\n"
    dlhtml.print "<p> <a href=\"#{unix_url}\">mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz</a> </p>\n"
    dlhtml.print "<p> <a href=\"#{win32_url}\">mingle_windows-x64_#{installer_ver}_#{MINGLE_REVISION}.exe</a> </p>\n"
    dlhtml.close
    metadata = File.new("tmp/installer_links.txt", "w")
    metadata.print "#{unix_url}\n"
    metadata.print win32_url
    metadata.close
  end

  task :publish_installer_with_svn_update => ['publish_installers'] do
    installer_ver = ENV["INSTALLER_VERSION"] || "0"
    dist = ENV["INSTALLER_PATH"] || "/tmp"
    MINGLE_REVISION = Mingle::Revision::CURRENT
    local_mingle_install_version_readme = ENV['INSTALLER_LOCAL_SVN_README'] || "/home/cruise/mingle-installer-performance-test/README"
    `svn up #{local_mingle_install_version_readme}`
    `echo \"mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz\" > #{local_mingle_install_version_readme}`
    `svn ci -m \"mingle_unix_#{installer_ver}_#{MINGLE_REVISION}.tar.gz\" #{local_mingle_install_version_readme}`
  end

  task :code_analysis => ["check_unguarded_actions", "check_copy_paste_detection", "metrics:ccn_treemap"]

  task :java_prepare => ['prepare', 'java:prepare']
  task :java_tests => ['prepare', 'run_java_tests']

  ('a'..'m').each do |suffix|
    task_name = "units_#{suffix}"
    task task_name => ['prepare', "test:#{task_name}"]
  end
  task :units => ['prepare', 'test:units']

  ('a'..'d').each do |suffix|
    task_name = "functionals_#{suffix}"
    task task_name => ['prepare', "test:#{task_name.to_s}"]
  end
  task :functionals => ['prepare', 'test:functionals']
  task :functional_planner => ['prepare', 'test:functional:planner']

   [ :subversion,
     :perforce,
     :curl ].each do | task_name |
    task task_name => ['prepare', "test:#{task_name.to_s}"]
  end

  task :google_maps => ['test:google_maps']
  task :google_calendar => ['test:google_calendar']

  task :macro_toolkit_tests => ['macro_toolkit:run_all_tests']

  task :javascripts => ["test:javascripts"]

  [ :acceptance_scm,
    :acceptance_murmurs,
    :acceptance_api_version_2,
    :acceptance_attachment,
    :acceptance_aggregate_properties,
    :acceptance_bulk,
    :acceptance_cardlist,
    :acceptance_cards,
    :acceptance_cardtype,
    :acceptance_card_properties,
    :acceptance_card_page_history,
    :acceptance_chart,
    :acceptance_defaults,
    :acceptance_defaults_2,
    :acceptance_dateproperty,
    :acceptance_enumproperty,
    :acceptance_filters,
    :acceptance_formula,
    :acceptance_freetextproperty,
    :acceptance_gridview,
    :acceptance_history,
    :acceptance_excel,
    :acceptance_excel_import,
    :acceptance_excel_export,
    :acceptance_import_export,
    :acceptance_macro,
    :acceptance_table_view,
    :acceptance_table_query,
    :acceptance_value_query,
    :acceptance_average_query,
    :acceptance_pivot_table,
    :acceptance_mingle_admin,
    :acceptance_navigation,
    :acceptance_new_user_role,
    :acceptance_other,
    :acceptance_profile,
    :acceptance_project,
    :acceptance_project_variable,
    :acceptance_project_variable_usage,
    :acceptance_properties,
    :acceptance_ranking,
    :acceptance_relationship_properties,
    :acceptance_search,
    :acceptance_svn,
    :acceptance_tabs,
    :acceptance_tagging,
    :acceptance_template,
    :acceptance_transitions,
    :acceptance_transition_crud,
    :acceptance_tree_configuration,
    :acceptance_tree_filters,
    :acceptance_tree_usage,
    :acceptance_tree_view,
    :acceptance_group,
    :acceptance_user,
    :acceptance_wiki,
    :acceptance_wiki_2,
    :acceptance_userproperty,
    :acceptance_maximized_view,
    :acceptance_help,
    :acceptance_cross_project,
    :acceptance_license,
    :acceptance_non_transactional_units,
    :acceptance_numeric_properties].each do | task_name |
      task task_name => ['prepare_with_browser_clean', 'assets',
                         "test:#{task_name.to_s}"]
  end

  task :non_transactional_units => ['prepare_with_browser_clean', 'test:non_transactional_units']

  task :messaging => ['prepare_with_browser_clean', 'test:messaging']
  task :messaging_and_search => [:messaging, 'test:integration:search']

  task :upgrade_export => ['prepare_with_browser_clean', 'db:recreate_upgrade_export_db_with_ssh', 'test:upgrade_export']

  task :create_test_db_dump_and_publish => ['db:recreate_development', 'db:test:create_test_db_dump_and_publish']
  task :create_local_ac_test_db_dump => ['db:recreate_development', 'db:test:create_local_ac_test_db_dump']

  task :create_local_test_db_dump => [:environment] do
    unless db_already_dumped?
      [ 'db:recreate_development', 'db:test:create_local_test_db_dump' ].each do |t|
        Rake::Task[t].invoke
      end
    end
  end


  def db_already_dumped?
    revision = Mingle::Revision::CURRENT
    raise 'you must has svn info available' if revision == 'unsupported'
    database = Mingle::Database.create_from_env('test')
    basedir = ENV["DUMP_DB_ROOT_PATH"].blank? ? "tmp" : ENV["DUMP_DB_ROOT_PATH"]
    file_name = File.join(basedir, "#{database.adapter}_test_database_dump_for_revision_#{revision}.sql")
    file_exists = File.exists?(file_name)
    if(file_exists)
      puts "#{file_name} already dumped so skip dumping"
    else
      puts "Need to dump #{file_name}"
    end
    file_exists
  end

  task :kill_build do
    Mingle::ProcessIds.kill_all_registered_pids
    if windows?
      # this is an awful heuristic to get the Mingle server process and filter our GoAgent...
      pids = `tasklist /FO CSV /NH /FI "IMAGENAME java.exe" /FI "MEMUSAGE ge 250000"`.strip.split("\n").map do |line|
        line.split(",")[1].gsub(/"/, "")
      end
      pids.each do |pid|
        puts "killing java pid: #{pid}"
        system("taskkill /F /T /PID #{pid}") rescue nil
      end
    end
  end

  task :log_pid do
    Mingle::ProcessIds.register('cruise_rake')
  end
  task :generate_help_text  => ['installers:build_help']
end
