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

class UnifiedDiffParser
  class Chunk
    attr_reader :lines
    
    def initialize
      @lines = []
    end
  end
  
  class Line
    attr_reader :old_lineno, :new_lineno, :content
    
    def initialize(old_lineno, new_lineno, content)
      @old_lineno, @new_lineno, @content = old_lineno, new_lineno, content
    end
    
    def removed?
      @new_lineno.nil? && !@old_lineno.nil?
    end

    def added?
      @old_lineno.nil? && !@new_lineno.nil?
    end
  end
  
  def initialize(unified_diff)
    @chunks = []
    @unified_diff = unified_diff
    parse
  end
  
  def chunks
    @chunks
  end
  
  private

  # For we only need to parse diff of one file, 
  # I just keep the parse method simple and it maybe has problem to parse diff of mutli-files.
  def parse
    @unified_diff_io = StringIO.new(@unified_diff)
    while not @unified_diff_io.eof?
      line = @unified_diff_io.readline
      case line
      when /^Index: /
        nil # ignore
      when /^\s*\+\+\+ /
        nil # ignore
      when /^\s*--- /
        nil # ignore
      when /^========/
        nil # ignore
      when /@@ -(\d*),\d* \+(\d*),\d* @@/
        parse_chunk($1.to_i, $2.to_i)
      when /@@ -(\d*) \+(\d*),\d* @@/
        parse_chunk($1.to_i, $2.to_i)
      when /@@ -(\d*),\d* \+(\d*) @@/
        parse_chunk($1.to_i, $2.to_i)
      when /@@ -(\d*) \+(\d*) @@/
        parse_chunk($1.to_i, $2.to_i)
      else
        #maybe is property changes, ignore them
      end
    end
  end
  
  def parse_chunk(old_lineno, new_lineno)
    chunk = Chunk.new
    while not @unified_diff_io.eof?
      line = @unified_diff_io.readline
      chunk.lines << case line
      when /^-(.*)$/
        # from line
        Line.new((old_lineno += 1) - 1, nil, $1)
      when /^\+(.*)$/
        # to line
        Line.new(nil, (new_lineno += 1) - 1, $1)
      when /^([\\].*)$/
        # No newline at end of file
        Line.new(nil, nil, $1)
      when /@@ -(\d*),\d* \+(\d*),\d* @@/
        parse_chunk($1.to_i, $2.to_i)
        break
      when /@@ -(\d*) \+(\d*),\d* @@/
        parse_chunk($1.to_i, $2.to_i)
        break
      when /@@ -(\d*),\d* \+(\d*) @@/
        parse_chunk($1.to_i, $2.to_i)
        break
      when /@@ -(\d*) \+(\d*) @@/
        parse_chunk($1.to_i, $2.to_i)
        break
      else
        # context line
        Line.new((old_lineno += 1) - 1, (new_lineno += 1) - 1, line)
      end
    end
    
    @chunks.unshift chunk
  end
end
