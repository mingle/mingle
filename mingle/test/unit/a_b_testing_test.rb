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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class ABTestingTest < ActiveSupport::TestCase

  ABTesting.add_experiments("foo1_test", "foo2_test", "foo3_test")


  def test_read_configuration_from_properties
    requires_jruby do
      begin
        java.lang.System.setProperty('mingle.ABTesting.foo1Test', 'group_a')

        assert_equal ABTesting.group_info["foo3_test"], nil
        assert_equal ABTesting.group_info["foo2_test"], nil
        assert_equal ABTesting.group_info["foo1_test"], "group_a"

      ensure
        java.lang.System.clearProperty('mingle.ABTesting.foo1Test')
        java.lang.System.clearProperty('mingle.ABTesting.foo2Test')
      end
    end
  end

  def test_overridden_group_info
    assert_equal ABTesting.group_info["foo3_test"], nil
    assert_equal ABTesting.group_info["foo1_test"], nil

    ABTesting.overridden_group_info('foo1_test' => "group_a") do

      assert_equal ABTesting.group_info["foo3_test"], nil
      assert_equal ABTesting.group_info["foo1_test"], "group_a"

    end

    assert_equal ABTesting.group_info["foo3_test"], nil
    assert_equal ABTesting.group_info["foo1_test"], nil
  end


  def test_generate_assign_groups
    results = []
    100.times do
      ABTesting.overridden_group_info(ABTesting.assign_groups) do
        results << ABTesting.experiment_group("foo1_test")
      end
    end
    assert_equal 2, results.uniq.size
  end

  def test_overridden_group_info_with_undefined_experiment
    ABTesting.overridden_group_info("undefined_exp" => "group_b") do
      assert_false ABTesting.in_experimental_group?("undefined_exp")
    end
  end

end
