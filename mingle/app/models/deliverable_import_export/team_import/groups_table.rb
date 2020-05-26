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
    class GroupsTable
      def initialize(project_import, groups)
        @project_importer, @groups = project_import, groups
      end

      def old_id(new_id)
        @groups.get_old_id(new_id)
      end

      def team
        @groups.detect { |group| group['internal'] && group['name'].downcase == 'team' }
      end

      def team_membership?(membership)
        membership['group_id'].to_s == team['id'].to_s
      end
    end
  end
end
