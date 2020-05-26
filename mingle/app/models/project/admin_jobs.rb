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

class Project
  module AdminJobs

    REGENERATE_CHANGES_ACTION = "regenerate changes"
    REBUILD_CARD_MURMUR_LINKS = "rebuild card murmur links"
    RECOMPUTE_AGGREGATES = "recompute aggregates"

    def generate_changes_as_admin
      group_sending_message(REGENERATE_CHANGES_ACTION, :generate_changes)
    end

    def rebuild_card_murmur_links_as_admin
      group_sending_message(REBUILD_CARD_MURMUR_LINKS, :rebuild_card_murmur_links)
    end

    def recompute_aggregates_as_admin
      group_sending_message(RECOMPUTE_AGGREGATES, :compute_aggregates)
    end

    def recomputing_aggregates?
      admin_job_in_progress?(RECOMPUTE_AGGREGATES)
    end
    def rebuilding_card_murmur_links?
      admin_job_in_progress?(REBUILD_CARD_MURMUR_LINKS)
    end
    def generating_changes?
      admin_job_in_progress?(REGENERATE_CHANGES_ACTION)
    end

    private
    def admin_job_in_progress?(action)
      MessageGroup.find_by_action(self.id, action)
    end

    def group_sending_message(action, action_method_name)
      raise "should not #{action} when it is working in progress" if MessageGroup.find_by_action(self.id, action)
      group = MessageGroup.create!(:project_id => self.id, :action => action)
      group.activate do
        self.send(action_method_name)
      end
    end
  end
end
