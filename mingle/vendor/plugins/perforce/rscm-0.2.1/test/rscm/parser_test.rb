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
require 'stringio'
require 'rscm/parser'

module RSCM
  class ParserTest < Test::Unit::TestCase
  
    class TestParser < Parser
      def initialize
        super(/^-+$/)
        @result = ""
      end
    
    protected

      def parse_line(line)
        @result << line
      end
      
      def next_result
        r = @result
        @result = ""
        r
      end
    end
  
    def test_can_parse_until_line_inclusive
      parser = TestParser.new
      io = StringIO.new(TEST_DATA)
      parser.parse(io) {|line|}
      assert_equal("one\ntwo\n", parser.parse(io))
      assert_equal("three\nfour\n", parser.parse(io))
    end

TEST_DATA = <<EOF
bla bla
--
one
two
--
three
four
--
EOF

  end
end
