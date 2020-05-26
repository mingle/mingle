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

require 'test/unit'
require 'rscm/mockit'

module MockIt
  class MockTest < Test::Unit::TestCase
    def setup
      @mock = Mock.new
    end

    def test_unmocked_call_fails
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.unmocked_call
      end
    end
    
    def test_call_to_unexpected_call_fails
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.expected_not_called
      end
    end

    def test_expected_call_works
      @mock.__expect(:expected_call)
      @mock.expected_call
    end
    
    def test_sequential_expected_methods_work
      @mock.__expect(:expected_call1)
      @mock.__expect(:expected_call2)
      @mock.expected_call1
      @mock.expected_call2
    end
    
    def test_sequential_expected_methods_in_wrong_order_fails
      @mock.__expect(:expected_call1)
      @mock.__expect(:expected_call2)
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.expected_call2
        @mock.expected_call1
      end
    end
    
    def test_provided_block_can_validate_arguments
      @mock.__expect(:expected_call) {|arg| assert_equal("arg", arg)}
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.expected_call("incorrect arg")
      end
    end

    def DOESNT_WORK_test_provided_block_can_validate_whether_block_was_given
      @mock.__expect(:expect_call_with_block) { assert(block_given?) }
      @mock.expect_call_with_block do end
    end

    def test_provided_block_can_validate_whether_block_was_not_given
      @mock.__expect(:expect_call_without_block) { assert(!block_given?) }
      @mock.expect_call_without_block
    end

    def test_provided_block_can_validate_several_arguments
      @mock.__expect(:expected_call) {|*args| assert_equal(["arg1", "arg2"], args)}
      @mock.expected_call("arg1", "arg2")
    end
    
    def test_verify_fails_if_not_all_expected_methods_were_called
      @mock.__expect(:expected_call)
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.__verify
      end
    end
    
    def test_setup_method_can_always_be_called_and_procs_returns_value
      @mock.__setup(:setup_call) {|| :return_value}
      assert_equal(:return_value, @mock.setup_call)
      assert_equal(:return_value, @mock.setup_call)
      assert_equal(:return_value, @mock.setup_call)
    end
    
    def test_respond_to_gives_true_for_setups_but_not_for_others
      @mock.__setup(:setup_method)
      assert(@mock.respond_to?(:setup_method))
      assert(@mock.respond_to?("setup_method"))
      assert(!@mock.respond_to?(:other_method))
      assert(!@mock.respond_to?("other_method"))
    end
    
    def test_respond_to_gives_true_for_currently_expected_method_but_not_for_others
      @mock.__expect(:expected_method)
      assert(@mock.respond_to?(:expected_method))
      assert(@mock.respond_to?("expected_method"))
      assert(!@mock.respond_to?(:other_method))
      assert(!@mock.respond_to?("other_method"))
    end
    
    def test_can_verify_several_times_with_different_excepts
      @mock.__expect(:expected_method)
      @mock.expected_method
      @mock.__verify
      @mock.__expect(:another_expected_method)
      @mock.another_expected_method
      @mock.__verify
    end
    
    def test_verify_fails_if_got_unexpected_call
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.unexpected_call
      end
      assert_raises(Test::Unit::AssertionFailedError) do
        @mock.__verify
      end
      # should reset state after __verify
      @mock.__verify
    end
    
  end

end
