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

class DeletedOrphanedAttachingsAndAttachments < ActiveRecord::Migration

  def self.up
    MigrationContent::M20090430225248Project.find(:all).each do |project|
      if invalid_attachings_count_for(project) > 0
        cleanup_attachings(project)
      end
    end
    cleanup_attachments
  end

  def self.down
  end
  
  module MigrationContent
    include MigrationHelper
    
    class M20090430225248Project < ActiveRecord::Base
      set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

      def card_table_name
        CardSchema.generate_cards_table_name(self.identifier)
      end

      def card_version_table_name
        CardSchema.generate_card_versions_table_name(self.identifier)
      end
    end
    
    def invalid_attachings_count_for(project)
      select_value(<<-SQL).to_i
        SELECT COUNT(*) 
        FROM (
          #{attachings_to_be_deleted(project)}
        ) attachings_to_be_deleted
      SQL
    end

    def cleanup_attachings(project)
      execute "DELETE FROM #{ActiveRecord::Base.table_name_prefix}attachings WHERE id IN ( #{attachings_to_be_deleted(project)} )"
    end

    def cleanup_attachments
      execute <<-SQL
        DELETE FROM #{Attachment.table_name} 
        WHERE id NOT IN (
          SELECT attachment_id FROM #{Attaching.table_name}
        )
      SQL
    end

    def attachings_to_be_deleted(project)
      <<-SQL
        SELECT all_attachings_for_project.id
        FROM 
            (
              #{all_attaching_ids_for(project)}
            ) all_attachings_for_project
          LEFT OUTER JOIN 
            (
              #{valid_attaching_ids_for(project)}
            ) valid_attachings_for_project
          ON (all_attachings_for_project.id = valid_attachings_for_project.id)
        WHERE valid_attachings_for_project.id IS NULL
      SQL
    end

    def all_attaching_ids_for(project)
      <<-SQL
        SELECT DISTINCT att.id
        FROM #{ActiveRecord::Base.table_name_prefix}attachings att
        JOIN #{ActiveRecord::Base.table_name_prefix}attachments a ON (a.id = att.attachment_id and a.project_id=#{project.id})
      SQL
    end

    def valid_attaching_ids_for(project)
      <<-SQL
        SELECT DISTINCT att.id
        FROM #{ActiveRecord::Base.table_name_prefix}attachings att
        JOIN #{safe_table_name(project.card_table_name)} c ON (c.id = att.attachable_id and att.attachable_type='Card')

        UNION

        SELECT DISTINCT att.id
        FROM #{ActiveRecord::Base.table_name_prefix}attachings att
        JOIN #{safe_table_name(project.card_version_table_name)} cv ON (cv.id = att.attachable_id and att.attachable_type='Card::Version')

        UNION

        SELECT DISTINCT att.id
        FROM #{ActiveRecord::Base.table_name_prefix}attachings att
        JOIN #{ActiveRecord::Base.table_name_prefix}pages p ON (p.id = att.attachable_id and att.attachable_type='Page' and p.project_id=#{project.id})

        UNION

        SELECT DISTINCT att.id
        FROM #{ActiveRecord::Base.table_name_prefix}attachings att
        JOIN #{ActiveRecord::Base.table_name_prefix}page_versions pv ON (pv.id = att.attachable_id and att.attachable_type='Page::Version' and pv.project_id=#{project.id})
      SQL
    end
    
  end
  
  extend MigrationContent
end
