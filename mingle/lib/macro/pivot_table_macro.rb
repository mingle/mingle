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

class PivotTableMacro < Macro
  include MqlSupport

  parameter :columns,       :required => true,                                      :computable => true, :compatible_types => [:string], :example => ''
  parameter :rows,          :required => true,                                      :computable => true, :compatible_types => [:string], :example => ''
  parameter :conditions,                            :default => '',                 :computable => true, :compatible_types => [:string], :example => 'type = card_type', :initially_shown => true
  parameter :aggregation,                           :default => 'COUNT(*)',         :computable => true, :compatible_types => [:string], :example => "COUNT(*)", :initially_shown => true
  parameter :project
  parameter :totals,                                :default => false,              :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ::ParameterRadioButton.new(['true', 'false']), :initial_value => false
  parameter :empty_columns,                         :default => true,               :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ::ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter :empty_rows,                            :default => true,               :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ::ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter :links,                                 :default => true,               :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true

  def initialize(*args)
    super
    @pivot_table = PivotTable.new(project, parameter_values.merge(card_query_options))
  end

  def execute_macro
    "\n\n#{table_html}\n\n"
  end

  def can_be_cached?
    @pivot_table.can_be_cached?
  end

  private

  TEXTILE_TABLE_ROW_END = "|"
  EMPTY_CELL = '&nbsp;'

  def table_html
    builder = ::Builder::XmlMarkup.new(:indent => 2)
    builder.table do
      @pivot_table.table_data.collect do |row|
        builder.tr do
          row.collect do |cell|
            if cell.is_a?(PivotTable::DataCell)
              builder.td { builder << (cell.has_query? ? table_data_with_link_textile(cell) : cell.value || EMPTY_CELL).to_s }
            elsif cell.is_a?(PivotTable::LabelCell)
              builder.th { builder << link_to_query(cell).to_s }
            elsif cell.is_a?(PivotTable::CaptionCell)
              builder.th { builder << cell.to_s }
            end
          end
        end
      end.join("\n")
    end
  end

  def table_data_with_link_textile(cell)
    link_to_query(cell) || EMPTY_CELL
  end

  def link_to_query(cell)
    cell_value = cell.value.try(:escape_html)
    return cell_value unless links?
    if cell_value
      view_params = {:filters => {:mql => CardQuery::MqlGeneration.new(cell.query.conditions).execute}, :style => 'list'}
      unless card_list_view_columns.blank?
        view_params[:columns] = card_list_view_columns.join(",")
      end
      url_params = view_params.merge(:project_id => project.identifier, :controller => 'cards')
      view_helper.link_to_without_user_access(cell_value, url_params)
    end
  end

  def card_list_view_columns
    [rows, columns] - ['name', 'number']
  end
end

Macro.register('pivot-table', PivotTableMacro)
