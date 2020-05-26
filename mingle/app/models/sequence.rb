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

class Sequence
  class DatabaseSequence
    def initialize(name)
      @name = name
    end
    
    def reset_to(value)
      raise 'not supported'
    end  

    def next
      Sequence.connection.next_sequence_value(@name)
    end
    
    def current
      Sequence.connection.current_sequence_value(@name)
    end

    def last_generated
      Sequence.connection.last_generated_value(@name)
    end

    def reserve(count)
      raise 'not supported'
    end    
  end
  
  def self.find(name)
    connection.supports_sequences? ? DatabaseSequence.new(name) : find_table_sequence(name)
  end

  def self.find_table_sequence(name)
    ActiveRecord::Base.uncached do
      TableSequence.find_or_create_by_name(name)
    end
  end
  
  def self.connection
    ActiveRecord::Base.connection
  end
  
end
