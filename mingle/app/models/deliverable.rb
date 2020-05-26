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

class Deliverable < ActiveRecord::Base
  include PathSanitizer
  DELIVERABLE_TYPE_PROJECT = 'Project'
  DELIVERABLE_TYPE_PROGRAM = 'Program'

  include HasManyMembers
  named_scope :all_selected, lambda { |identifiers| {:conditions => ["identifier IN (?) ", identifiers]}  }

  def last_activity_for_export
    Event.find(:first, :conditions => { :deliverable_id => self.id}, :order => "created_at DESC").created_at rescue self.updated_at
  end

  def self.all_sorted_based_on_last_activity
    deliverables =   all(
          select: "#{connection.quote_column_name('deliverables.id')}, #{connection.quote_column_name('deliverables.identifier')}, #{connection.quote_column_name('deliverables.name')}, #{connection.quote_column_name('deliverables.hidden')}, CASE WHEN EXISTS(SELECT * FROM #{connection.quote_table_name('events')} WHERE #{connection.quote_column_name('events.deliverable_id')} = #{connection.quote_column_name('deliverables.id')}) THEN MAX(#{connection.quote_column_name('events.created_at')}) ELSE #{connection.quote_column_name('deliverables.updated_at')} END AS last_activity_on",
          joins:"LEFT JOIN #{connection.quote_table_name('events')} ON #{connection.quote_column_name('events.deliverable_id')} = #{connection.quote_column_name('deliverables.id')}",
          group: "#{connection.quote_column_name('deliverables.id')}, #{connection.quote_column_name('deliverables.identifier')}, #{connection.quote_column_name('deliverables.name')}, #{connection.quote_column_name('deliverables.hidden')}, #{connection.quote_column_name('deliverables.id')}, #{connection.quote_column_name('deliverables.updated_at')}",
          order: 'last_activity_on DESC'
      )

    deliverables.reject(&:hidden)
  end

  def export_dir_name
    sanitize name
  end

  memoize  :last_activity_for_export
end
