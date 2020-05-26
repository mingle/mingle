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

class Export < ActiveRecord::Base
  include ExportHelper
  include MetricsHelper

  COMPLETED = 'completed'
  IN_PROGRESS = 'in progress'
  ERROR = 'error'
  default_scope order: 'id ASC'
  file_column :export_file, :root_path => SwapDir::SwapFileProxy.new.pathname, :bucket_name => MingleConfiguration.data_export_bucket_name
  serialize :config, Hash
  belongs_to :user

  after_create :sync_last_exported_date_with_profile_server

  def filename
    "#{dirname}.zip"
  end

  def dirname
    "MingleExport_#{MingleConfiguration.app_namespace || 'mingle'}_#{created_at.strftime("%d%b%Y_%H%M%Z")}"
  end

  def merge_data?
    total == completed + 1
  end

  def error?
    status == ERROR
  end

  def start
    # 1 for merge processor
    options = self.config||= {}
    self.total = 1
    InstanceDataExportPublisher.new.publish_message(
        self,
        {include_users_and_projects_admin: options[:all_users_and_projects_admins], include_user_icons: options[:user_icons]}
    )
    if MingleConfiguration.saas?
      update_running_exports unless Multitenancy.active_tenant.nil?
      if is_slack_integrated?
        IntegrationsExportPublisher.new.publish_message(self, slack_team_url)
      end
    end
    Project.all_selected(selected_deliverable_identifiers(options)).each do |project|
      project.with_active_project do |project|
        ProjectDataExportPublisher.new.publish_message(self, project)
        ProjectHistoryDataExportPublisher.new.publish_message(self, project) if options[:projects][project.identifier][:history]
      end
    end
    if CurrentLicense.registration.enterprise?
      DependencyDataExportPublisher.new.publish_message(self) if export_dependencies?(options)
      Program.all_selected(selected_deliverable_identifiers(options, :programs)).each do |program|
        ProgramDataExportPublisher.new.publish_message(self, program)
      end
    end
    save!
  end

  private
  def export_dependencies?(options)
    Dependency.count > 0 && options[:dependencies]
  end

  def selected_deliverable_identifiers(options, type = :projects)
    return [] if options.nil? || options[type].nil?
    projects = options[type]
    projects.keys.select do |identifier|
      if type == :projects
        projects.key?(identifier) && projects[identifier][:data]
      else
        projects[identifier]
      end
    end
  end

  def update_running_exports
    current_tenant = Multitenancy.active_tenant.name
    running_exports =  MingleConfiguration.global_config['running_exports'] || {}
    MingleConfiguration.global_config_merge('running_exports' => running_exports.merge({current_tenant => DateTime.now.utc.strftime("%d-%b-%Y-%I:%M %p UTC")}))
  end

  def sync_last_exported_date_with_profile_server
    ProfileServer.update_last_data_exported_on(self.created_at) if ProfileServer.configured?
  end
end
