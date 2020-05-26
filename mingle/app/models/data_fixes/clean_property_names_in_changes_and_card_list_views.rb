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

module DataFixes
  class CleanPropertyNamesInChangesAndCardListViews < Base

    class << self
      def description
        %Q{
          Cleans up whitespace in property names in changes and saved card_list_views
          so that one can rename properties and retain card histories and card_list_views.
        }
      end

      def apply(project_ids=[])
        clean_changes_table
        clean_card_list_views
      end

      private

      def clean_changes_table
        execute %Q{
          update #{t("changes")}
             set #{c("field")}=trim(#{c("field")})
           where #{c("field")} like '% '
        }
      end

      def clean_card_list_views
        User.first_admin.with_current do
          each_project do |project_id, identifier, cards_table, card_versions_table|
            Project.find(project_id).with_active_project do |project|
              project.card_list_views.each do |clv|
                # clean up column names, save() will reserialize params and canonical_string for us
                clv.columns.map(&:strip!)
                clv.save!
              end
            end
          end
        end
      end

    end

  end
end
