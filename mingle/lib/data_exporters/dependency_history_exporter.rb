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

class DependencyHistoryExporter < CardHistoryExporter
  def initialize(base_dir, message = {})
    super(base_dir, message)
    @processed_events = {}
  end

  def name
    'History'
  end

  def version_types
    %w('DependencyDeletionEvent' 'DependencyVersionEvent').join(',')
  end

  def conditions
    "type in (#{version_types})"
  end

  def headings
    ['Date',	'Time (UTC)',	'Modified by',	'Dependency',	'Event',	'Property',	'From',	'To', 'Description changes', 'Attachment name']
  end

  def external_file_data_possible?
    true
  end

  def history_data_for(event, change)
    @processed_events[event_key(event)] = true
    Project.find(event.deliverable_id).with_active_project do |_|
      @row_data.cells([
        event.created_at.strftime('%d-%b-%Y'), event.created_at.strftime('%H:%M'),
        event.modified_by_user_login, "#D#{event.origin.number}", change.describe_type_for_export,
        change.field, change.from, change.to, change.description_changes_for_export, change.attachment_name
      ], unique_key(event, change))
    end
  end

  def creation_history_data_for(event)
    @row_data.cells([
        event.created_at.strftime('%d-%b-%Y'), event.created_at.strftime('%H:%M'), event.modified_by_user_login,
        "#D#{event.origin.number}", 'Dependency created', '', '', '', '', ''
    ], unique_key(event, nil))
  end

  def unique_key(event, change)
    change_id = change.blank? ? 'created' : change.id
    "dependency_history_#{event.origin.number}_#{event.origin.version}_#{change_id}"
  end

  def processed?(event)
    @processed_events[event_key(event)] == true
  end

  private
  def event_key(event)
    "#{event.origin.number}/#{event.origin.version}"
  end

end
