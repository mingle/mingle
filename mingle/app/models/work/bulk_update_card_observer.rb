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

class Work < ActiveRecord::Base
  class BulkUpdateCardObserver < ActiveRecord::Observer
    observe Bulk::BulkUpdateProperties

    def update(project, card_id_criteria, name_values)
      updater = BulkUpdater.new(project, card_id_criteria)
      Program.associated_with(project).each do |program|
        program.with_done_status_definition(project) do |done_status_definition|
          updated_done_status = name_values[done_status_definition.status_name]
          if updated_done_status
            completed = done_status_definition.includes?(updated_done_status)
            updater.update_attribute(program.plan.id, 'completed', completed)
          end
        end
      end
    end

    BulkUpdateCardObserver.instance
  end

  class BulkDestroyObserver < ActiveRecord::Observer
    observe Bulk::BulkDestroy

    def update(project, card_id_criteria)
      updater = BulkUpdater.new(project, card_id_criteria)
      updater.destroy_works
    end
    BulkDestroyObserver.instance
  end

end
