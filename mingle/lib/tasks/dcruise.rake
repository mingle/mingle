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
require 'rake/testtask'

class CruiseDistributeTestTask < Rake::TestTask
  attr_writer :test_queue_servers
  
  def define
    super #call super to make @name can still be used as task name
    lib_path = @libs.join(File::PATH_SEPARATOR)
    ruby_opts = @ruby_opts.dup
    ruby_opts.unshift( "-I#{lib_path}" )
    ruby_opts.unshift( "-w" ) if @warning
    namespace(@name) do
      define_collector_task(ruby_opts)
      define_runner_task(ruby_opts)
    end
    self
  end
  
  private
  
  def define_collector_task(ruby_opts)
    desc "collect test cases for #{@name} and publish to test queue"
    task "collect" do
      RakeFileUtils.verbose(@verbose) do
        ruby ruby_opts.join(" ") +
          " \"#{collector_sccript}\" " +
          " #{test_queue_name} " +
          " #{test_queue_servers.join(",")} " + 
          file_list.collect { |fn| "\"#{fn}\"" }.join(' ') +
          " #{option_list}"
      end
    end    
  end
  
  def define_runner_task(ruby_opts)
    desc "fetch test cases from #{@name} and run till test queue empty"
    task "run" do
      RakeFileUtils.verbose(@verbose) do
        ruby ruby_opts.join(" ") +
          " \"#{runner_script}\" " +
          " #{test_queue_name} " +
          " #{test_queue_servers.join(",")} " + 
          file_list.collect { |fn| "\"#{fn}\"" }.join(' ') +
          " #{option_list}"
      end
    end
  end
  
  def test_queue_name
    "#{@name}_#{ENV['CRUISE_PIPELINE_NAME']}_#{ENV['CRUISE_PIPELINE_LABEL']}"
  end
  
  def test_queue_servers
    @test_queue_servers || [ENV["CRUISE_SERVER"] + ":22122"]
  end
  
  def collector_sccript
    File.dirname(__FILE__) + '/../build/dcruise_test_collector.rb'
  end
  
  def runner_script
    File.dirname(__FILE__) + '/../build/dcruise_test_runner.rb'
  end
end


namespace :cruise do
  CruiseDistributeTestTask.new(:unit_and_functional_tests) do |t|
    t.libs << "test"
    t.test_files = FileList['test/unit/**/*test.rb', 'test/functional/**/*test.rb']
    t.verbose = false    
  end  
  task :run_unit_and_functional_tests => ['prepare', 'unit_and_functional_tests:run']
end