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

require File.expand_path(File.join(File.dirname(__FILE__), '20090430225248_deleted_orphaned_attachings_and_attachments'))

class OrphanedAttachmentsAndTreeBelongings < ActiveRecord::Migration
  extend DeletedOrphanedAttachingsAndAttachments::MigrationContent

  def self.up
    DeletedOrphanedAttachingsAndAttachments.up
    M2010062218541Project.all.each do |project|
      project.clean_tree_belongings
    end
  end

  def self.down
    DeletedOrphanedAttachingsAndAttachments.down
  end
  
  class M2010062218541Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    include MigrationHelper
    
    def card_table_name
      safe_table_name(CardSchema.generate_cards_table_name(self.identifier))
    end
    
    def clean_tree_belongings
      ActiveRecord::Base.connection.execute <<-SQL
        DELETE FROM #{connection.safe_table_name('tree_belongings')} tree_belongings
         WHERE tree_belongings.card_id NOT IN (SELECT id FROM #{self.card_table_name})
           AND tree_belongings.tree_configuration_id IN (SELECT id FROM #{connection.safe_table_name('tree_configurations')} WHERE project_id = #{self.id})
      SQL
    end
  end
  
end
