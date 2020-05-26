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

class InputConsole
  class Description < Struct.new(:tokens, :desc)
    def composed
      "---- #{tokens.join(', ')} \t #{desc}"
    end
  end
  
  def initialize(&block)
    @last_desc = nil
    @map = {}
    @descriptions = []
    add_default_commands
    yield(self)
    print_help
    start
  end
  
  def desc(description)
    @last_desc = description
  end
  
  def cmd(*tokens, &block)
    @descriptions << Description.new(tokens, @last_desc) if @last_desc
    tokens.each do |token|
      @map[token.to_s] = Proc.new(&block)
    end
    @last_desc = nil
  end
  
  def print_help
    puts "\n******** commands list **************"
    puts "\n"
    @descriptions.each do |d|
      puts d.composed
    end
    puts "\n"
    puts "*************************************\n"
  end
  
  private
  def add_default_commands
    desc 'print this help'
    cmd :help, :h do
      print_help
    end
  end
  
  def start
    Thread.new do
      loop do
        if proc = @map[gets.strip]
          proc.call
        end
      end
    end    
  end
end
