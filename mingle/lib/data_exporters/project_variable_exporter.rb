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

class ProjectVariableExporter < BaseDataExporter

  def name
    'Project variables'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.project_variables.order_by_name.each do |project_variable|
      sheet.insert_row(index, [project_variable.name, project_variable.data_type_description,project_variable.property_definition_names.join(',') , project_variable.export_value])
      index = index.next
    end
    Rails.logger.info("Exported project variables to sheet")
  end

  def exportable?
    Project.current.project_variables.count > 0
  end

  private

  def headings
    %w(Name Type Properties Value)
  end

end
