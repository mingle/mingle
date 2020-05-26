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
require 'rake'
require 'fileutils'
require File.expand_path('../../test/server_starter', File.dirname(__FILE__))

namespace :gauge do

  desc 'start a mingle server for twist test running inside twist IDE'
  task :mingle_server do
    ServerStarter.start
  end

  def ready?(url)
    request = Net::HTTP::Get.new(url.path)
    Net::HTTP.start(url.host, url.port) do |http|
      puts "querying server status... #{http.request(request).body}"
      http.request(request).body.chomp =~ /(Rails|Mingle)\sis\s(ready|installed)/
    end
  rescue
    nil
  end

  desc 'clean gauge & sahi test env'
  task :clean do
    %w(sahi logs tmp).each do |dir|
      rm_rf("test/gauge/smokeTests/#{dir}".tap {|d| puts "removing #{d}"})
    end
    puts 'recreate sahi test dir'
    cp_r('test/gauge/sahi', 'test/gauge/smokeTests/sahi')    
  end

  desc 'run all gauge test, including start a mingle server, use trailing square brackets i.e. gauge:test[SpecName.spec] to specify a single spec'
  task :test, [:spec_name] => :clean do |task, args|
    ServerStarter.with_mingle_server do
      begin
        chdir('test/gauge/smokeTests') do
          if args[:spec_name]
            files_to_run = FileList["specs/#{args[:spec_name]}"]
            raise "Cannot find #{args[:spec_name]}" if files_to_run.empty?
            puts "running #{files_to_run.inspect}"
            sh "gauge --tags '#{(ENV['TAG_GROUP'] || '!in-progress' || '!skip_this_spec')}' #{files_to_run.join(',')}"
          else
            sh "gauge --tags '#{(ENV['TAG_GROUP'] || '!in-progress' || '!skip_this_spec')}' specs"
          end
        end
      ensure
        report_html = html_report_path
        puts %x[open #{report_html}] if mac?
      end
    end
  end

  desc 'clean logs'
  task :clean_logs do
    %w(sahi logs tmp).each do |dir|
      rm_rf("test/gauge/plannerTests/#{dir}".tap {|d| puts "removing #{d}"})
    end
  end

  desc 'run all gauge tests running on webdriver use trailing square brackets i.e. gauge:test[SpecName.spec] to run single spec'
  task :webdriver_test, [:spec_name] => :clean_logs do |task, args|
    ServerStarter.with_mingle_server(:port => 8080) do
      begin
        chdir('test/gauge/plannerTests') do
          sh "gauge -v"
          sh "./gradlew clean test"
          if args[:spec_name]
            files_to_run = FileList["specs/#{args[:spec_name]}"]
            raise "Cannot find #{args[:spec_name]}" if files_to_run.empty?
            puts "running #{files_to_run.inspect}"
            sh "./gradlew gauge -Ptags='#{(ENV['TAG_GROUP'])}' -PspecsDir=#{files_to_run.join(',')}"
          else
            sh "./gradlew gauge -Ptags='#{(ENV['TAG_GROUP'])}' -PspecsDir=specs"
          end
        end
      ensure

      end
    end
  end

  task :report do
    report_html = html_report_path
    puts %x[open #{report_html}] if mac?
  end

  desc 'copy over gauge ie properties as twist.properties'
  task :ie do
    cp 'test/gauge/smokeTests/src/test/java/twist.go_ie.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
  end

  desc 'copy over gauge mac properties as twist.properties'
  task :mac do
    cp 'test/gauge/smokeTests/src/test/java/twist.mac.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
    rm_rf 'test/gauge/smokeTests/sahi'
    cp_r 'test/gauge/sahi', 'test/gauge/smokeTests/'
  end

  desc 'copy over gauge mac_chrome properties as twist.properties'
  task :mac_chrome do
    cp 'test/gauge/smokeTests/src/test/java/twist.mac_chrome.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
    rm_rf 'test/gauge/smokeTests/sahi'
    cp_r 'test/gauge/sahi', 'test/gauge/smokeTests/'
  end

  desc 'copy over gauge centos/firefox properties as twist.properties'
  task :centos do
    cp 'test/gauge/smokeTests/src/test/java/twist.go_ff.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
  end

  desc 'copy over gauge ff properties as twist.properties'
  task :win_ff do
    cp 'test/gauge/smokeTests/src/test/java/twist.go_win_ff.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
  end

  desc 'copy over gauge chrome properties as twist.properties'
  task :centos_chrome do
    cp 'test/gauge/smokeTests/src/test/java/twist.go_chrome.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
  end


  desc 'copy over gauge google chrome properties as twist.properties'
  task :win_chrome do
    cp 'test/gauge/smokeTests/src/test/java/twist.go_win_chrome.properties', 'test/gauge/smokeTests/src/test/java/twist.properties'
  end

  desc 'same with run: gauge:ie gauge:test'
  task :test_ie, [:spec_name] => %w(assets ie test)

  desc 'same with run: gauge:win_ff gauge:test'
  task :test_win_ff, [:spec_name] => %w(assets win_ff test)

  desc 'same with run:'
  task :test_win_chrome, [:spec_name] => %w(assets win_chrome test)

  desc 'same with run: gauge:mac gauge:test'
  task :test_mac, [:spec_name] => %w(assets mac test)

  desc 'same with run: gauge:mac_chrome gauge:test'
  task :test_mac_chrome, [:spec_name] => %w(assets mac_chrome test)

  desc 'same with run: gauge:centos gauge:test'
  task :test_centos => %w(assets centos test)

  desc 'same with run: gauge:centos gauge:test'
  task :test_centos_chrome => %w(assets centos_chrome test)

  def html_report_path
    File.join(File.dirname(__FILE__), '..', '..', 'test', 'gauge', 'smokeTests', 'reports', 'html-report', 'index.html')
  end

end
