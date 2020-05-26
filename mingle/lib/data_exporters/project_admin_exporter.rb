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

class ProjectAdminExporter < BaseDataExporter

  def name
    'Project admins'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    index = 1
    Project.order_by_name.each do |project|
      project.admins.order_by_name.each_with_index do |admin|
        sheet.insert_row(index, [project.name, admin.name, admin.email])
        index = index.next
      end
    end
    Rails.logger.info("Exported project admins to sheet")
  end

  def position
    1
  end

  def exportable?
    Project.has_projects_admin?
  end

  private
  def headings
    ['Project name', 'Admin name', 'Admin email address']
  end

end
