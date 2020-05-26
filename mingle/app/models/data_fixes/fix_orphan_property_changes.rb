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
  class FixOrphanPropertyChanges < Base

    def self.description
      "This data fix is for fixing orphan property changes. Mingle used to have a bug which causes change records without valid field name left during property deletion or property rename. The garbage data is harmful, can cause 500 error on certain atom feeds pages."
    end

    def self.required?
      Event.count(problem_conditions) > 0
    end

    def self.apply(project_ids=[])
      Event.find_each(problem_conditions.merge(:select => 'events.*')) do |event|
        event.update_attributes(:history_generated => false)
        MingleEventPublisher.publish_for_event(event)
      end
    end

    private
    def self.problem_conditions
      { :joins => :changes,
        :conditions => ["changes.type = ? AND NOT EXISTS (SELECT 1 FROM property_definitions WHERE name = changes.field AND project_id = events.deliverable_id)", 'PropertyChange']}
    end
  end
end
