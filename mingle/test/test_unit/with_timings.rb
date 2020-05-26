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

require 'test/unit/ui/console/testrunner'
if (defined?(WITH_TIMINGS) && WITH_TIMINGS) || ENV['WITH_TIMINGS']

  class Test::Unit::UI::Console::TestRunner
    @@timing_info = []

    def finished_with_timing_info(total_time)
      puts "#{Time.now} finishing timing info"
      n = 50
      tests = @@timing_info.sort_by {|test| test.time}.reverse
      total_time = tests.inject(0) { |sum, test| sum + test.time }
      filename = Rails.root.to_s + "/log/slowest_tests_#{Time.now.strftime("%d-%m-%Y_%H%M")}.log"
      testcases = {}
      tests.each do |test|
        testcases[test.class_name] ||= 0
        testcases[test.class_name] += test.time
      end
      testcases = testcases.sort_by {|t| t[1]}.reverse
      open(filename, 'w') do |f|
        f.puts "Top #{n} slowest tests:"
        tests[0..n-1].each do |test|
          f.puts format("%.2fs\t%.1f%%\t%s\t\t%s", test.time, (test.time / total_time) * 100, test.class_name, test.method_name)
        end
        f.puts "# tests = #{tests.size}"
        f.puts format("total time = %.2fs", total_time)
        f.puts "\nTop 10 slowest test classes:"
        testcases[0..9].each do |testcase|
          f.puts format("%.2fs\t%.1f%%\t%s", testcase[1], (testcase[1] / total_time) * 100, testcase[0])
        end
      end
      puts "#{Time.now} finished timing info"
    end

    def start
      setup_mediator
      attach_to_mediator
      @mediator.add_listener(Test::Unit::UI::TestRunnerMediator::FINISHED, &method(:finished_with_timing_info))
      @mediator.add_listener(Test::Unit::TestCase::STARTED, &method(:test_started_with_timing_info))
      @mediator.add_listener(Test::Unit::TestCase::FINISHED, &method(:test_finished_with_timing_info))
      return start_mediator
    end

    def test_started_with_timing_info(name)
      @@start_time = Time.now
    end

    def test_finished_with_timing_info(name)
      if name =~ /(\w+)\((\w+)\)/
        @@timing_info << OpenStruct.new({:class_name => $2, :method_name => $1, :time => (Time.now - @@start_time)})
      end
    end
  end
end
