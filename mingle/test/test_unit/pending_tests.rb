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

require 'test/unit/testresult'

module PendingTests
  def self.included(test_case_class)
    test_case_class.extend(ClassMethods)
    test_case_class.class_eval do
      def run_with_pending_marked(result, &block)
        if self.class.pending_tests && self.class.pending_tests.keys.include?(@method_name.to_sym)
          print "!"
        else
          run_without_pending_marked(result, &block)
        end
      end
      safe_alias_method_chain :run, :pending_marked
    end
  end

  module ClassMethods
    attr_reader :pending_tests

    def pending(message)
      @next_test_is_pending_message = message

      if called_for_first_time?
        @pending_tests = {}
        pending_tests_closure = @pending_tests
        new_test_result_to_s = Proc.new do
          original_to_s = "#{run_count} tests, #{assertion_count} assertions, #{failure_count} failures, #{error_count} errors"
          if pending_tests_closure.any?
            original_to_s << <<-EOS


  Pending tests:
  #{pending_tests_closure.map { |test_name, pending_message| "  #{test_name} - #{pending_message}\n" }}
            EOS
          end
        end

        Test::Unit::TestResult.class_eval do
          define_method(:to_s, new_test_result_to_s)
        end
      end
    end

    def method_added(method_name)
      if @next_test_is_pending_message
        @pending_tests[method_name] = @next_test_is_pending_message
        @next_test_is_pending_message = false
      end
    end

    protected

    def called_for_first_time?
      @pending_tests.nil?
    end
  end
end
ActiveSupport::TestCase.send :include, PendingTests
