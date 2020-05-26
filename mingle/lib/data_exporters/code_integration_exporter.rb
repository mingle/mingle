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

class CodeIntegrationExporter < BaseDataExporter
  def name
    'Code integration'
  end

  def export(sheet)
    if repository_configuration
      sheet.add_headings(sheet_headings)
      is_tfs_config? ? export_tfs_config(sheet, repository_configuration.plugin) : export_repo_config(sheet, repository_configuration.plugin)
      Rails.logger.info("Exported code integration to sheet")
    end
  end

  def exportable?
    !Project.current.repository_configuration.nil?
  end

  private

  def is_tfs_config?
    repository_configuration && repository_configuration.plugin && repository_configuration.plugin.is_a?(TfsscmConfiguration)
  end

  def repository_configuration
    Project.current.repository_configuration
  end

  def headings
    is_tfs_config? ? tfs_scm_headings : ['Username', 'Repository Type', 'Repository Path']
  end

  def tfs_scm_headings
    ['Username', 'Repository Type', 'Server URL', 'Domain', 'Collection', 'Project']
  end

  def export_tfs_config(sheet, plugin)
    server_url = plugin.server_url
    sheet.insert_row(1, [plugin.username, plugin.class.display_name, server_url, plugin.domain, plugin.collection, plugin.tfs_project], {link: {index: 2, url: server_url}})
  end

  def export_repo_config(sheet, plugin)
    repository_path = plugin.repository_path
    sheet.insert_row(1, [plugin.username, plugin.class.display_name, repository_path], {link: {index: 2, url: repository_path}})
  end
end
