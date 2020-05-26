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

module DependenciesImportSupport

  def infer_model_from_table_name(table_name)
    DependenciesExport.models.find do |m|
      m.table_name == (ActiveRecord::Base.table_name_prefix + table_name)
    end
  end

  def database_project(project_id)
    Project.find_by_identifier(project_record(project_id)["identifier"])
  end

  def project_record(project_id)
    import_file_projects[project_id]
  end

  def import_file_projects
    import_file_projects = {}
    @tables['deliverables'].each do |record|
      import_file_projects[record['id']] = record if record["type"] == "Project"
    end
    import_file_projects
  end
  memoize :import_file_projects

  def update_progress(message)
    @progress.add_error(message)
    @progress.update_progress_message(message)
  end

end
