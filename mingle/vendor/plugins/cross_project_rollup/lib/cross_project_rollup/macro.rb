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

# #Copyright 2010 ThoughtWorks, Inc.  All rights reserved.

require File.join(File.dirname(__FILE__), '..', 'mingle', 'property_definition')

module CrossProjectRollup
  class Macro
    def initialize(parameters, projects, current_user)
      @parameters = parameters
      @projects = Array(projects)
      @current_user = current_user
    end
    
    def execute
      raise errors.join(', ') unless valid?

      head_labels = ([rows_params] + columns.map(&:label))
      
      output = HtmlTable.new(@projects.first, :zero_value_rows => zero_value_rows?)
      output.add_table do
        output.add_header_row head_labels
        group_by.get_data.each do |row_head|
          row_data = columns.map { |column| column.cell_value(row_head.normalized_value) }
          output.add_data_row(row_head.display_value, row_data)
        end
        subtotals.each do |subtotal|
          subtotal_data = columns.map { |column| column.subtotal(subtotal.conditions) }
          output.add_subtotal_row subtotal.label, subtotal_data
        end
        if @parameters.keys.include?('total') ? @parameters['total'] : true
          column_totals = columns.map { |column| column.total }
          output.add_data_row 'Total', column_totals
        end
      end
    end
    
    def can_be_cached?
      false  # if appropriate, switch to true once you move your macro to production
    end
    
    def self.supports_project_group?
      true
    end
    
    private
    
    def zero_value_rows?
      @parameters.key?('zero-value-rows') ? @parameters['zero-value-rows'] : true
    end
    
    def rows_conditions
      @parameters['rows-conditions']
    end
    
    def rows_params
      @parameters['rows']
    end
    
    def column_params
      @parameters['columns']
    end
    
    def group_by
      @group_by ||= GroupBy.new(@projects, @parameters)
    end
    
    def columns
      @columns ||= column_params.map { |column_params| Column.new(@projects, @parameters, column_params) }.each(&:get_data)
    end
    
    def subtotals
      @subtotals ||= (@parameters['sub-totals'] || []).map { |subtotal_params| Subtotal.new(subtotal_params) }
    end
    
    def missing_para_error(params)
      %Q(Parameter '#{params}' is required)
    end
    
    def errors
      @errors ||= []
    end
    
    def valid?
      errors << "Cannot generate this chart because no project is specified. Please provide at least one project on the 'project-group' parameter" if @projects.empty?
      errors << missing_para_error('rows') unless rows_params
      errors << missing_para_error('columns') unless column_params
      errors << missing_para_error('column aggregate') if column_params && column_params.any?{ |column| column['aggregate'].nil? }
      errors.empty?
    end
  end
end
