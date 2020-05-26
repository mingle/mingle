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

class CardVersionIdSequence
  include SecureRandomHelper
  attr_reader :name, :start_card_version_id
  
  def initialize(card_count)      
    sequence = TableSequence.find_or_create_by_name('card_version_id_sequence')
    @start_card_version_id = sequence.reserve(card_count) 

    @name = generate_unique_sequence_name
    @sequence_handler = SequenceFactory.new(@name)   
    @sequence_handler.create_sequence(@start_card_version_id)        
  end
  
  def destroy
    @sequence_handler.destroy_sequence
  end
  
  def next_value_sql
    ActiveRecord::Base.connection.next_sequence_value_sql(@name)
  end
  
  private
  
  def generate_unique_sequence_name
    "a" + random_32_char_hex[0..28]
  end

  class SequenceFactory

    def initialize(name)
      @name = name
    end

    def create_sequence(starting_id)
      ActiveRecord::Base.connection.create_sequence(@name, starting_id)
    end

    def destroy_sequence
      ActiveRecord::Base.connection.drop_sequence(@name)
    end
  end
end
