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

class ClearBlankFilePathAttachmentAndRelatedAttaching < ActiveRecord::Migration
  def self.up
    attachments_table_name = safe_table_name('attachments')
    attachings_table_name = safe_table_name('attachings')

    execute "DELETE FROM #{attachings_table_name} WHERE attachment_id IS NULL"
    execute "DELETE FROM #{attachings_table_name} WHERE attachable_id IS NULL"
    
    execute <<-SQL
      DELETE FROM #{attachings_table_name} WHERE 
        attachment_id IN (
          SELECT id FROM #{attachments_table_name} WHERE #{quote_column_name('file')} = '' OR path = '')
    SQL

    execute <<-SQL
      DELETE FROM #{attachments_table_name} WHERE #{quote_column_name('file')} = '' OR path = ''
    SQL
  end

  def self.down
  end
end
