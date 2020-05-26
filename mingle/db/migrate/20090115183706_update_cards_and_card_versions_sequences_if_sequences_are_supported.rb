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

class UpdateCardsAndCardVersionsSequencesIfSequencesAreSupported < ActiveRecord::Migration
  MIN_SEQ_VALUE = 1 unless defined?(MIN_SEQ_VALUE)
  
  def self.up
    return if ActiveRecord::Base.table_name_prefix.starts_with?('mi_')
    if supports_sequences?
      create_sequence("card_id_sequence", seq_last_value_from_table('cards'))
      create_sequence("card_version_id_sequence", seq_last_value_from_table('card_versions'))
    end
    
    execute("update sequences set name = 'card_id_sequence' where name = 'cards'")
    execute("update sequences set name = 'card_version_id_sequence' where name = 'card_versions'")
    
  end
    
  def self.seq_last_value_from_table(table_name)
    last_value = select_value("select last_value from sequences where name = '#{table_name}'").to_i
    [last_value, MIN_SEQ_VALUE].max
  end

  def self.down
    return if ActiveRecord::Base.table_name_prefix.starts_with?('mi_')
    if supports_sequences?
      drop_sequence("card_id_sequence")
      drop_sequence("card_version_id_sequence")
      
      execute("update sequences set name = 'cards' where name = 'card_id_sequence'")
      execute("update sequences set name = 'card_versions' where name = 'card_version_id_sequence'")
    end
  end
end
