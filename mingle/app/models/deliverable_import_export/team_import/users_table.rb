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
    class UsersTable < SimpleDelegator
      include Enumerable

      def initialize(project_import, users)
        super(users)
        @project_importer = project_import
      end

      def records_by_ids(ids)
        ids.map { |id| detect {|ur| ur['id'].to_s == id.to_s} }
      end

      def ids_by_logins(logins)
        logins.map { |login| id_by_login(login) }
      end

      def id_by_login(login)
        detect { |u| u['login'] == login }['id'].to_s
      end

      def login_by_id(id)
        detect { |u| u['id'].to_s == id.to_s }['login']
      end

      def each(&block)
        __getobj__.each do |record|
          yield(UserRecord.new(record, self))
        end
      end

      class UserRecord < DelegateClass(Hash)
        def initialize(data, table)
          super(data)
          @table = table
        end

        def type
          'User'
        end

        def id
          self['id'].to_s
        end

        def ancestors(membership_structure)
          membership_structure.ancestors_of_user(self['login'])
        end

        def current_ancestor_ids(membership_structure)
          membership_structure.current_ancestors_of_user(self['login'])
        end

        def restricted_to_readonly_in_destination?(membership_structure)
          membership_structure.user_restricted_to_readonly_in_destination?(@table.get_new_id(self['id']))
        end
      end
    end
  end
end
