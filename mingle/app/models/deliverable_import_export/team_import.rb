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
  class TeamImport
    attr_reader :project_importer

    def initialize(project_importer)
      @project_importer = project_importer
      @user_memberships = project_importer.table('user_memberships')
    end

    def execute
      import_required_direct_memberships
    end

    def recreated_user_memberships
      @created_user_membership_records
    end

    def responsible_for_importing?(table)
      'user_memberships' == table.name.downcase
    end

    private
    def import_required_direct_memberships
      @user_memberships.imported = true
      @user_memberships.each do |record|
        record.delete('id')
        create_user_membership_record(record)
      end
    end

    def create_user_membership_record(record)
      (@created_user_membership_records ||= []) << record.dup
      project_importer.import_record(@user_memberships, record)
    end

    def new_user_id(old_id)
      project_importer.table('users').get_new_id(old_id)
    end

    def new_group_id(old_id)
      project_importer.table('groups').get_new_id(old_id)
    end

  end
end
