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
require 'rscm/tempdir'
require 'rscm/path_converter'

module Test
  module Unit
    class TestCase
      # assertion method that reports differences as diff.
      # useful when comparing big strings
      def assert_equal_with_diff(expected, actual)
        dir = RSCM.new_temp_dir("diff")
        
        expected_file = "#{dir}/expected"
        actual_file = "#{dir}/actual"
        File.open(expected_file, "w") {|io| io.write(expected)}
        File.open(actual_file, "w") {|io| io.write(actual)}

        difftool = WINDOWS ? File.dirname(__FILE__) + "/../../bin/diff.exe" : "diff"
        IO.popen("#{difftool} #{RSCM::PathConverter.filepath_to_nativepath(expected_file, false)} #{RSCM::PathConverter.filepath_to_nativepath(actual_file, false)}") do |io|
          diff = io.read
          assert_equal("", diff, diff)
        end
      end
    end
  end
end

module RSCM
  class DiffPersisterTest < Test::Unit::TestCase
    def test_diffing_fails_with_diff_when_different
      assert_raises(Test::Unit::AssertionFailedError) {
        assert_equal_with_diff("This is a\nmessage with\nsome text", "This is a\nmessage without\nsome text")
      }
    end

    def test_diffing_passes_with_diff_when_equal
      assert_equal_with_diff("This is a\nmessage with\nsome text", "This is a\nmessage with\nsome text")
    end
  end
end
