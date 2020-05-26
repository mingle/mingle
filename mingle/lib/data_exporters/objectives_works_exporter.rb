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

class ObjectivesWorksExporter < BaseDataExporter
  def name
    'Objectives Added Work'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    program.objectives.order_by_number.each do |objective|
      objective.works.each do |work|
        project = Project.find(work.project_id)
        sheet.insert_row(index, ["##{objective.number}", objective.name, project.name, "##{work.card_number}", work.name, filter(objective, work.project_id), work.completed ? 'Yes': 'No'])
        index = index + 1
      end
    end
    Rails.logger.info("Exported objectives works to sheet")
  end

  def exportable?
      program.objectives.any? { |objective| !objective.works.empty? }
  end

  private
  def program
    @program = @program || Program.find(@message[:program_id])
  end

  def headings
    ['Objective number', 'Objective title', 'Project', 'Card number', 'Card name', 'Filter', 'Done']
  end

  def filter(objective, project_id)
    filters = ''
    if auto_sync = objective.filters.find_by_project_id(project_id)
      filters = auto_sync.params[:filters].join(' AND ').gsub('][', " ").gsub(/[\]\[]/, "")
    end
    filters
  end
end
