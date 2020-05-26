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

require File.expand_path(File.join(File.dirname(__FILE__), 'lib/environment.rb'))

class MingleTools::Export
  def self.export(project)
    project.with_active_project do |active_project|
      user = User.first_admin
      asynch_request = user.asynch_requests.create_project_export_asynch_request(active_project.identifier)
      asynch_request.update_attributes(:message => { 
            :project_id => active_project.id,
            :user_id => user.id,
            :request_id => asynch_request.id,
            :template => false
        }
      )
      DeliverableImportExport::ProjectExporter.new(:project => active_project, :progress => asynch_request, :user => user).export
    end
  end
end

unless Database.need_config?
  User.first_admin.with_current do
    export_files = {}

    all_projects = Project.find(:all, :conditions => ['hidden = ?', false])
    puts "[DEBUG] #{all_projects.count} projects to export"

    all_projects.each do |project|
      puts "Exporting project #{project.identifier}..."
      export_files[project.identifier] = MingleTools::Export.export(project)
    end
  
    base_dir = (ENV['mingleDataDir'] || '.')
    base_dir = base_dir.ends_with?('/') || base_dir.ends_with?("\\") ? base_dir[0..-2] : base_dir
    directory = "#{base_dir}/exported_projects/"
    puts "Congratulations! The export files for projects #{export_files.keys.to_sentence} have been created. We will now move them to #{directory}. You can use the import_projects.rb tool to import #{%w{this file}.plural(export_files.size)} into your Mingle instance."
    FileUtils.mkdir_p directory
    export_files.each do |project_identifier, export_file|
      FileUtils.mv(export_file, "#{directory}/#{project_identifier}.mingle")
    end
  end
end
