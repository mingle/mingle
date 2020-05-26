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

class PageHistoryExporter < CardHistoryExporter

  def name
    'Page history'
  end

  def version_types
    %w('PageDeletionEvent' 'PageVersionEvent').join(',')
  end

  def conditions
    "deliverable_id = #{Project.current.id} AND type in (#{version_types})"
  end

  def headings
    ['Date',	'Time',	'Modified by',	'Page',	'Event',	'From',	'To', 'Tag', 'Description changes', 'Attachment']
  end

  def history_data_for(event, change)
    Project.find(event.deliverable_id).with_active_project do |_|
      @row_data.cells([
        event.project.format_date(event.created_at), event.project.format_time_without_date(event.created_at),
        event.modified_by_user_login, "#{event.origin.name}",
        change.describe_type_for_export, change.from,
        change.to, event.origin.tags.join(","),
        change.content_changes_for_export, change.attachment_name
      ], unique_key(event, change))
    end
  end

  def creation_history_data_for(event)
    @row_data.cells([
      event.project.format_date(event.created_at), event.project.format_time_without_date(event.created_at),
      event.modified_by_user_login, "#{event.origin.name}",'Page created', '', '','','', ''
    ], unique_key(event, nil))
  end

  def unique_key(event, change)
    change_id = change.blank? ? 'created' : change.id
    "page_history_#{event.origin.export_dir}_#{event.origin.version}_#{change_id}"
  end

  def external_file_data_possible?
    true
  end
end
