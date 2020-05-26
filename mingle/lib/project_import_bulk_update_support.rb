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

module ProjectImportMySqlBulkUpdate
  def update_statements_for_card_property_definition(property_definition, card_ids_session_id)
    old_card_id_column = 'id_1'
    new_card_id_column = 'id_2'
    
    [%{
      UPDATE #{Card.quoted_table_name}, #{TemporaryIdStorage.table_name} 
      SET #{Card.quoted_table_name}.#{property_definition.quoted_column_name} = #{TemporaryIdStorage.table_name}.#{new_card_id_column} 
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{Card.quoted_table_name}.#{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}'
    },  %{
      UPDATE #{Card::Version.quoted_table_name}, #{TemporaryIdStorage.table_name} 
      SET #{Card::Version.quoted_table_name}.#{property_definition.quoted_column_name} = #{TemporaryIdStorage.table_name}.#{new_card_id_column}
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}'
    }
    ]
  end  
end  

module ProjectImportPostgresBulkUpdate
  def update_statements_for_card_property_definition(property_definition, card_ids_session_id)
    old_card_id_column = 'id_1'
    new_card_id_column = 'id_2'
    
    [%{
      UPDATE #{Card.quoted_table_name} 
      SET #{property_definition.quoted_column_name} = #{TemporaryIdStorage.table_name}.#{new_card_id_column} 
      FROM #{TemporaryIdStorage.table_name}
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}'
    },  %{
      UPDATE #{Card::Version.quoted_table_name} 
      SET #{property_definition.quoted_column_name} = #{TemporaryIdStorage.table_name}.#{new_card_id_column} 
      FROM #{TemporaryIdStorage.table_name}
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}'
    }
    ]
  end  
end

module ProjectImportOracleBulkUpdate
  def update_statements_for_card_property_definition(property_definition, card_ids_session_id)
    old_card_id_column = 'id_1'
    new_card_id_column = 'id_2'
    
    [%{
      UPDATE #{Card.quoted_table_name} 
      SET #{property_definition.quoted_column_name} = (SELECT #{TemporaryIdStorage.table_name}.#{new_card_id_column} 
      FROM #{TemporaryIdStorage.table_name}
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{Card.quoted_table_name}.#{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}')
    },  %{
      UPDATE #{Card.quoted_versioned_table_name} 
      SET #{property_definition.quoted_column_name} = (SELECT #{TemporaryIdStorage.table_name}.#{new_card_id_column} 
      FROM #{TemporaryIdStorage.table_name}
      WHERE #{TemporaryIdStorage.table_name}.#{old_card_id_column} = #{Card.quoted_versioned_table_name}.#{property_definition.quoted_column_name} AND
            #{TemporaryIdStorage.table_name}.session_id = '#{card_ids_session_id}')
    }
    ]
  end  
end
