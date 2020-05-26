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

module RSCM
  class Parser
  
    def initialize(break_regexp)
      @break_regexp = break_regexp
    end
  
    def parse(io, skip_line_parsing=false, &line_proc)
      parse_until_regexp_matches(io, skip_line_parsing, &line_proc)
      if(skip_line_parsing)
        nil
      else
        next_result
      end
    end

  protected

    def parse_line(line)
      raise "Must override parse_line(line)"
    end

    def next_result
      raise "Must override next_result(line)"
    end
    
  private

    def parse_until_regexp_matches(io, skip_line_parsing, &line_proc)
      io.each_line { |line|
        yield line if block_given?
        if line =~ @break_regexp
          return
        end
        parse_line(line) unless skip_line_parsing
      }
    end
  end
end
