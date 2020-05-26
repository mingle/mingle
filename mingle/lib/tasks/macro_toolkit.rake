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
namespace :macro_toolkit do

  MACRO_DEV_TOOLKIT_PATH = File.expand_path File.join(Rails.root, '..', 'macro_dev_toolkit')

  task :run_all_tests => ['environment', 'unit_tests', 'data_setup', 'start_mingle_server', 'enable_basic_auth', 'integration_tests', 'stop_mingle_server']

  task :data_setup do
    Project.all.each(&:destroy)
    User.delete_all
    LoginAccess.delete_all
    UserDisplayPreference.delete_all
    User.create!(:name => 'bjanakir', :login => 'bjanakir', :email => 'bjanakir@email.com', :password => 'pass1.', :password_confirmation => 'pass1.', :activated => true, :admin => true).with_current do
      DeliverableImportExport::ProjectImporter.fromActiveMQMessage(
        ProjectImportPublisher.new(User.current, "#{MACRO_DEV_TOOLKIT_PATH}/test/project_data/macro_toolkit_test_template.mingle", "macro_toolkit_test", "macro_toolkit_test").publish_message
      ).import
    end
  end

  task :start_mingle_server do
    require File.expand_path(File.dirname(__FILE__) + "/../../vendor/plugins/inbrowsertest/lib/selenium_rails")
    ServerStarter::RailsEnvironment.start(:port => 8080)
  end

  task :stop_mingle_server do
    require File.expand_path(File.dirname(__FILE__) + "/../../vendor/plugins/inbrowsertest/lib/selenium_rails")
    ServerStarter::RailsEnvironment.stop
  end

  task :enable_basic_auth do
    Net::HTTP.get URI.parse("http://admin:test123.@localhost:8080/_class_method_call?class=AuthConfiguration&method=enable_basic_authentication&basic_auth_enabled=true")
  end

  Rake::TestTask.new(:integration_tests) do |t|
    t.libs << Dir.glob("#{MACRO_DEV_TOOLKIT_PATH}/vendor/gems/**/lib") + ["#{MACRO_DEV_TOOLKIT_PATH}/test/integration", "#{MACRO_DEV_TOOLKIT_PATH}/lib"]
    t.pattern = "#{MACRO_DEV_TOOLKIT_PATH}/test/integration/**/*_test.rb"
    t.verbose = true
  end

  Rake::TestTask.new(:unit_tests) do |t|
    t.libs << Dir.glob("#{MACRO_DEV_TOOLKIT_PATH}/vendor/gems/**/lib") + ["#{MACRO_DEV_TOOLKIT_PATH}/test/integration", "#{MACRO_DEV_TOOLKIT_PATH}/lib"]
    t.pattern = "#{MACRO_DEV_TOOLKIT_PATH}/test/unit/**/*_test.rb"
    t.verbose = true
  end

  Rake::TestTask.new(:google_calendar_unit_tests) do |t|
    t.libs << Dir.glob("#{MACRO_DEV_TOOLKIT_PATH}/vendor/gems/**/lib") + ["#{MACRO_DEV_TOOLKIT_PATH}/test/integration", "#{MACRO_DEV_TOOLKIT_PATH}/lib"]
    t.pattern = "./vendor/plugins/google_calendar_macro/test/unit/**/*_test.rb"
    t.verbose = true
  end

end