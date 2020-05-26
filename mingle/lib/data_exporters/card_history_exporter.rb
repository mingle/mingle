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

class CardHistoryExporter < BaseDataExporter
  include ExportFailOverSupport

  def name
    'Card history'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Event.find_each_with_order(
        batch_size: 1000, order_by_column: :created_at, order_by: 'DESC', start: Clock.now,
        conditions: conditions
    ) do |event|
      next if event.origin.nil? || processed?(event)
      return if abort_on_export_error?(@message[:export_id]) do
        event.changes.desc_order_by_id.each do |change|
          sheet.insert_row(index, history_data_for(event, change))
          index = index.next
        end
        if event.origin && event.origin.first?
          sheet.insert_row(index, creation_history_data_for(event))
          index = index.next
        end
     end
    end
    Rails.logger.info("Exported #{name} data to sheet")
  end

  def exportable?
    Event.count(conditions: conditions) > 0
  end

  def export_count
    10
  end

  def external_file_data_possible?
    true
  end

  protected
  def processed?(e)
    false
  end

  def creation_history_data_for(event)
    @row_data.cells([
        event.project.format_date(event.created_at), event.project.format_time_without_date(event.created_at),
        event.modified_by_user_login, "##{event.origin.number}", event.origin.card_type.name, 'Card created',
        '', '', '', '', '', '', ''
    ], unique_key(event, nil))
  end

  def history_data_for(event, change)
    @row_data.cells([
        event.project.format_date(event.created_at), event.project.format_time_without_date(event.created_at),
        event.modified_by_user_login, "##{event.origin.number}", event.origin.card_type.name, change.describe_type_for_export,
        change.property_name, change.from, change.to, change.description_changes_for_export, change.tag.try(:name), change.attachment_name, change.murmur
    ], unique_key(event, change))
  end

  def unique_key(event, change)
    change_id = change.blank? ? 'created' : change.id
    "card_history_#{event.origin.number}_#{event.origin.version}_#{change_id}"
  end

  def conditions
    "deliverable_id = #{Project.current.id} AND type in (#{version_types})"
  end

  def version_types
    %w('CardDeletionEvent' 'CardVersionEvent').join(',')
  end

  def headings
    ['Date', 'Time', 'Modified by', 'Card', 'Card type', 'Event', 'Property', 'From', 'To', 'Description changes', 'Tag', 'Attachment name', 'Murmur']
  end
end
