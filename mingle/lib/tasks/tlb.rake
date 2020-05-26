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
require 'rubygems'
require 'tlb'
require 'tlb/test_unit/test_task'
require 'test/tlb_env'
require "test/tlb_patches"

SCM_TESTS = FileList['test/acceptance/scenarios/scm/*_test.rb']
CURL_INTEGRATION_TESTS = FileList['test/curl_api/*_test.rb']
UPGRADE_EXPORT_TESTS = FileList['test/upgrade_export_test.rb']
API_TESTS = FileList['test/acceptance/scenarios/**/api/*_test.rb']
NON_TRANSACTIONAL_UNITS = FileList['test/acceptance/scenarios/**/non_transactional_units/*_test.rb']
CARD_TESTS = FileList['test/acceptance/**/cards/*_test.rb']
WIKI_TESTS = FileList['test/acceptance/**/wiki/*_test.rb']
TLB_SETUP = [FileList["test/test_unit/tlb_setup.rb"]]

Dir.mkdir("tmp") unless File.exist? "tmp"

ENV['TLB_ERR_FILE'] = File.join(Rails.root,"log", "tlb.err")
ENV['TLB_OUT_FILE'] = File.join(Rails.root,"log", "tlb.log")
if gid = ENV['GO_AGENT_ID']
  if gid.to_i > 0
    puts "Found GO_AGENT_ID: #{gid.inspect}"
    ENV['TLB_BALANCER_PORT'] = (9000 + gid.to_i).to_s
    puts "Update ENV['TLB_BALANCER_PORT'] to #{ENV['TLB_BALANCER_PORT']}"
  end
end

class TlbAcceptanceTestTask < Tlb::TestUnit::TestTask
  module SeleniumRcServer
    def execute(arg)
      puts '[tlb.rake] start tlb local server'
      Tlb.start_server
      puts '[tlb.rake] starting selenium proxy server'
      SeleniumRcHelper.start_server
      sleep 3
      puts '[tlb.rake] started'
      super
    ensure
      puts '[tlb.rake] stopping tlb local server'
      Tlb.stop_server
      puts '[tlb.rake] stopped tlb local server'
    end
  end

  def define
    super
    if task = Rake.application.lookup(@name)
      task.extend(SeleniumRcServer)
    end
  end
end

class TlbUnitsTestTask < Tlb::TestUnit::TestTask
  module TlbServerForUnits
      def execute(arg)
        puts '[tlb.rake] start tlb local server'
        Tlb.start_server
        puts '[tlb.rake] started'
        super.tap do |r|
          puts "[tlb.rake] finished"
        end
      ensure
        puts "[tlb.rake] stopping local server"
        Tlb.stop_server rescue nil
        puts '[tlb.rake] stopped tlb local server'
      end
    end

    def define
      super
      if task = Rake.application.lookup(@name)
        task.extend(TlbServerForUnits)
      end
    end
end

task :get_all_tests do
 test_list = FileList['test/acceptance/**/*_test.rb']
 File.open(File.join(Rails.root,'test','all_tests.txt'), 'w') do |f1|
   test_list.each do |test|
     f1.puts test
   end
 end
end

namespace :tlb do
  TlbAcceptanceTestTask.new(:acceptance) do |t|
    t.libs << "test"
    t.test_files = FileList['test/acceptance/scenarios/**/*_test.rb'] - FileList['test/acceptance/scenarios/non_transactional_units/*_test.rb'] - API_TESTS - SCM_TESTS + TLB_SETUP
    t.verbose = true
  end

  TlbUnitsTestTask.new(:units) do |t|
    t.libs << "test"
    t.test_files = FileList["test/unit/**/*_test.rb"] + TLB_SETUP
    t.verbose = true
  end

  TlbUnitsTestTask.new(:functionals) do |t|
    t.libs << "test"
    t.test_files = FileList["test/functional/**/*_test.rb"] + TLB_SETUP
    t.verbose = true
  end

  TlbUnitsTestTask.new(:uf) do |t|
    t.libs << "test"
    t.test_files = FileList["test/unit/**/*_test.rb"] + FileList["test/functional/**/*_test.rb"] + TLB_SETUP
    t.verbose = true
  end
end
task :uf => ['cruise:prepare', 'tlb:uf']
task :units => ['cruise:prepare', 'tlb:units']
task :functionals => ['cruise:prepare', 'tlb:functionals']
task :acceptance_unix => ['cruise:prepare_with_browser_clean', 'tlb:acceptance']
