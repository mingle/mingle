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

module DeliverableImportExport
  module ImportUsers

    def import_users(table, new_user_id_collector=[])
      return if table.imported?

      step("Importing #{table.name}...") do
        table.imported = true

        table.each do |record|
          old_id = record.delete('id')

          if existing_user = find_matching_user_for(record)
            Rails.logger.info("[USER MAPPING] Mapping user #{record['login']} to #{existing_user.login} as they share same email #{record['email']}") if existing_user.login != record['login']

            User.lock_against_delete(existing_user.id)
            table.map_ids(old_id, existing_user.id)
          else
            record.merge!("locked_against_delete" => true)
            record.merge!('jabber_user_name' => nil)

            new_id = import_record(table, record)
            new_user_id_collector << new_id
            create_login_access_for(new_id)
            attach_icon_to_user(old_id, new_id, record)
            sync_user_to_remote(record)
            table.map_ids(old_id, new_id)
          end
        end
      end
    end

    def icon_file_from(record, model, id)
      return if record['icon'] == nil || record['icon'].empty?
      icon = DeliverableImportExport::IconExporter.icon_exported_path(directory, model, id, record['icon'])
      File.exists?(icon) ? File.new(icon) : nil
    end

    def create_login_access_for(user_id)
      connection.execute <<-SQL
          INSERT INTO #{LoginAccess.table_name} (id, user_id)
          VALUES ((#{ActiveRecord::Base.connection.next_id_sql(LoginAccess.table_name)}) ,#{user_id})
        SQL
    end

    def sync_user_to_remote(user_record)
      ProfileServer.sync_user(OpenStruct.new(user_record)) if ProfileServer.configured?
    end

    def attach_icon_to_user(old_id, new_id, record)
      if icon_file = icon_file_from(record, User, old_id)
        User.find(new_id).update_attribute(:icon, icon_file)
      end
    end

    def find_matching_user_for(record)
      User.find_by_login(record['login']) || (!record['email'].blank? && User.find_by_email(record['email']))
    end
  end
end
