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

class ProgramProjectExporter < BaseDataExporter
  def name
    'Projects'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    program.program_projects.each_with_index do |program_project, index|
      project = Project.find(program_project.project_id)
      done_status_property = program_project.status_property_id? ? EnumeratedPropertyDefinition.find(program_project.status_property_id).name : 'NA'
      done_status_property_value = program_project.done_status_id? ? EnumerationValue.find(program_project.done_status_id).value : 'NA'
      sheet.insert_row(index.next, [project.identifier, project.name,
                                    done_status_property,
                                    done_status_property_value,
                                    program_project.accepts_dependencies ? 'Yes' : 'No'])
      Rails.logger.info("Exported program projects to sheet")
    end
  end

  def exportable?
    program.program_projects.count > 0
  end

  private

  def program
    @program = @program || Program.find(@message[:program_id])
  end

  def headings
    ['Project identifier', 'Project name', 'Done status: Property', 'Done status: Value', 'Accepts dependencies']
  end
end
