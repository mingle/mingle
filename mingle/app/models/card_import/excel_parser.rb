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

module CardImport
  class ExcelParser

    LINE = ?\n.ord
    CELL = ?\t.ord
    QUOTE = ?".ord
    SPACE = ?\s.ord
    RETURN = ?\r.ord

    def self.parse(content)
      self.new.read_lines(content)
    end

    def read_lines(contents)
      index = 0
      result = []
      while index < contents.size do
        line, index = readline(contents, index)
        result << line unless line.nil? || line.all?{|cell| cell.nil? || cell.empty?}
        break unless index
      end
      pad(result)
    end

    def readline(contents, index)
      cells = []
      contents = contents.bytes.to_a
      while contents[index] do
        buffer = Buffer.new
        while chr = contents[index] do
          buffer << chr
          index = index.succ
          break if buffer.has_value?
        end
        buffer << nil if chr.nil?
        cell = buffer.value
        if cell and cell[0,1] == "\"" and cell[-1..-1] == "\"" then cell = cell[1..-2] end
        cell.gsub!(/\"\"/,"\"") if cell
        cells << cell
        return cells, index if  chr.nil? || chr == LINE
      end
    end

    def pad(lines)
      lines[0] = trimmed_header(lines)
      lines[1..-1] = lines[1..-1].collect do |line|
        if line.size > lines[0].size
          line[0..(lines[0].size-1)]
        else
          null_padding = [nil] * (lines[0].size - line.size)
          line + null_padding
        end
      end
      lines
    end
  
    def trimmed_header(lines)
      return lines[0] if !lines[0].last.blank?
      last_non_empty_cell_in_header = lines[0].reverse.each_with_index { |header_cell, index| break (index + 1) if !header_cell.blank? }
      lines[0][0..(-last_non_empty_cell_in_header)]
    end  
  
    def trailing_quotes_in_cell?(index, contents)
      return false unless contents[index] == QUOTE
      return false if contents[index - 1] == QUOTE #for the csv style quotes escaping
      i = index.succ
      i += 1 until contents[i] != SPACE
      next_char = contents[i]
      !next_char || [CELL, RETURN, LINE].include?(next_char)
    end
  end
end
