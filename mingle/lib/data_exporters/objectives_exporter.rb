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

class ObjectivesExporter < BaseDataExporter

  def name
    'Objectives'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    size_id = prop_def_id_for('Size')
    value_id = prop_def_id_for('Value')
    program.objectives.order_by_number.each_with_index do |obj, index|
      obj_prop_values = {}
      prop_value_records = prop_value_ids_for(obj)
      prop_value_records.each do |prop_value_record|
        obj_prop_values[:value] = prop_value_for(prop_value_record, value_id) if obj_prop_values[:value].nil?
        obj_prop_values[:size] = prop_value_for(prop_value_record, size_id) if obj_prop_values[:size].nil?
      end
      row = ["##{obj.number}", obj.name, plain_text(obj.value_statement), obj.value_statement, obj_prop_values[:value], obj_prop_values[:size], dbY_format_with_timestamp_for(obj.created_at), modified_by(obj.modified_by_user_id), dbY_format_with_timestamp_for(obj.updated_at), obj.status, dbY_format_without_timestamp_for(obj.start_at), dbY_format_without_timestamp_for(obj.end_at)]
      sheet.insert_row(index.next, @row_data.cells(row, unique_key(obj)))
    end
    Rails.logger.info("Exported program objectives to sheet")
  end

  def exportable?
    program.objectives.count > 0
  end

  def external_file_data_possible?
    true
  end

  private
  def unique_key(obj)
    "objective_#{obj.number}"
  end

  def program
    @program = @program || Program.find(@message[:program_id])
  end

  def plain_text(value_statement)
    value_statement ? Nokogiri.HTML(value_statement).text : ''
  end

  def prop_value_ids_for(obj)
    ActiveRecord::Base.connection.execute(SqlHelper.sanitize_sql("SELECT #{c('obj_prop_value_id')} FROM #{t('obj_prop_value_mappings')}
                          WHERE #{c('objective_id')} = ?", obj.id))
  end

  def prop_def_id_for(prop_def)
    ActiveRecord::Base.connection.execute(SqlHelper.sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_defs')}
                          WHERE #{c('program_id')} = ? AND #{c('name')} = ?", program.id, prop_def
    )).first['id']
  end

  def prop_value_for(prop_value_record, prop_def_id)
    query = ActiveRecord::Base.connection.execute(SqlHelper.sanitize_sql("SELECT #{c('value')} FROM #{t('obj_prop_values')}
                          WHERE #{c('id')} = ? AND #{c('obj_prop_def_id')} = ? ", prop_value_record['obj_prop_value_id'], prop_def_id))
    query.first['value'] unless query.empty?
  end

  def modified_by(user_id)
    User.find(user_id).login unless user_id.nil?
  end

  def dbY_format_with_timestamp_for(time)
    time.strftime('%d %b %Y  %H:%M') unless time.nil?
  end

  def dbY_format_without_timestamp_for(time)
    time.strftime('%d %b %Y') unless time.nil?
  end

  def headings
    ['Number', 'Title', 'Value Statement(Plain Text)', 'Value Statement(HTML)', 'Value', 'Size', 'Created on(UTC)', 'Last modified by', 'Last modified on(UTC)', 'Status', 'Planned start date', 'Planned end date']
  end

  def t(table_name)
    ActiveRecord::Base.connection.safe_table_name(table_name)
  end

  def c(column_name)
    ActiveRecord::Base.connection.quote_column_name(column_name)
  end
end
