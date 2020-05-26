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

module YamlExporter
  module_function

  def export(project_identifier, templates_directory = ConfigurableTemplate::IN_PROGRESS_DIR)
    project = Project.find_by_identifier(project_identifier)
    raise "No project found by #{project_identifier}" if project.blank?
    yml = project.to_template

    unless File.directory?(templates_directory)
      FileUtils.mkdir_p(templates_directory)
    end

    template_file = File.join(templates_directory, "#{project_identifier}.yml")
    File.open(template_file, 'w') do |file|
      file.write(yml)
    end
    template_file
  end
end
