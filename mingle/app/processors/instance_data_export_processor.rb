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

class InstanceDataExportProcessor < DataExportProcessor
  QUEUE = 'mingle.instance_data_export'

  def data_exporters(message)
    exporters =  message[:include_users_and_projects_admin] ? [UserDataExporter, ProjectAdminExporter] : []
    exporters << UserIconExporter if message[:include_user_icons]
    exporters
  end

  def excel_file_name
    'Users and Admins'
  end
end
