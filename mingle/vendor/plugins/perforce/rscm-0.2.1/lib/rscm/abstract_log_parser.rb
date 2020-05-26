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
  
  # NOTE: It is recommended to use the Parser class in parser.rb
  # as a basis for new SCM parsers
  #
  # Some utilities for log-parsers
  # TODO: make this a module and remove the attr_reader
  class AbstractLogParser
  
    attr_reader :io
  
    def initialize(io)
      @io = io
      @current_line_number = 0
      @had_error = false
    end
  
    def read_until_matching_line(regexp)
      return nil if io.eof?
      result = ""
      io.each_line do |line|
        @current_line_number += 1
        line.gsub!(/\r\n$/, "\n")
        break if line=~regexp
        result<<line
      end
      if result.strip == ""
        read_until_matching_line(regexp) 
      else
        result
      end
    end
    
    def convert_all_slashes_to_forward_slashes(file)
      file.gsub(/\\/, "/")
    end
    
    def error(msg)
      @had_error=true
      $stderr.puts(msg + "\ncurrent line: #{@current_line}\nstack trace:\n")
      $stderr.puts(caller.backtrace.join('\n\t'))
    end
    
    def had_error?
      @had_error
    end
  end

end
