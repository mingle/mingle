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

class DependenciesExporter
  include ProgressBar

  SQL_METHOD = :select_by_dependencies_sql

  attr_accessor :projects, :progress, :user, :filename

  def initialize(projects, progress, user)
    @projects = projects
    @progress = progress
    @user = user
    @export_file = SwapDir::DependencyExport.file(progress.deliverable_identifier)
  end

  def self.fromActiveMQMessage(message)
     projects = message[:project_identifiers].split(",").map do |project_identifier|
        Project.find_by_identifier(project_identifier)
     end
     progress = AsynchRequest.find(message[:request_id])
     user = User.find(message[:user_id])
     new(projects, progress, user).tap do |export|
        export.mark_new
     end
  end

  def mark_new
    # self.progress.update_attributes(:total => ProgramExport.models.size)
    # @progress.update_progress_message("Export of #{program.name.bold} has been queued. Please wait here for export to begin.")
    # @progress.mark_queued
  end

  def process!
    with_progress do
      stepped_export(DependenciesExport.models, SQL_METHOD)
    end
    mark_completed_successfully
    @export_file.pathname
  end

  def stepped_export(models, sql_method)
    export_models(models, sql_method)

    step("Exporting attachments.") { export_files_for_projects }
    step("Exporting icons.") {
      exported_users = @tables.table('users', User).select_records(:select_by_dependencies_sql, projects)
      DeliverableImportExport::IconExporter.new(@basedir).export_icons(exported_users)
    }
    step("Preparing exported data for download."){ ExportDownload.new(@temporary_directory, @progress, @export_file).zip_temp_files_and_copy_to_swap_dir }
    self.filename = @export_file.pathname
  end

  private

  def export_models(models, sql_method)
     @temporary_directory = RailsTmpDir::DependenciesExport.new_temporary_directory(self.progress.deliverable_identifier)
     @basedir = @temporary_directory.dirname
     @tables = ImportExport::TableModels.new(@basedir)
     @tables.table('schema_migrations').write("SELECT * FROM #{ActiveRecord::Base.connection.safe_table_name('schema_migrations')}", Dependency.connection)
     models.each do |model|
       table_name = model.table_name
       if table_name =~ /^#{ActiveRecord::Base.table_name_prefix}(.*)/
         table_name = $1
       end
       step("Exporting #{table_name.humanize.downcase} table") do
         begin
           @tables.table(table_name, model).write_pages(sql_method, self.projects)
         rescue Exception => e
           ActiveRecord::Base.logger.error {e.backtrace.join("\n")}
           raise e
         end
       end
     end
  end

  def attached_to_a_dependency?(attachment)
    project_ids = self.projects.map(&:id)
    result = attachment.attachings.map do |attaching|
      return false unless [Dependency.name, Dependency::Version.name].include?(attaching.attachable_type)

      dep = attaching.attachable_type.constantize.find(attaching.attachable_id)
      project_ids.include?(dep.raising_project_id) && project_ids.include?(dep.resolving_project_id)
    end

    result.include?(true)
  end

  def export_files_for_projects
    self.projects.each do |project|
      project.attachments.each do |attachment|

        next unless attached_to_a_dependency?(attachment)

        target = File.join(@basedir, attachment.path, attachment.file_relative_path)
        begin
          attachment.file_copy_to(target)
        rescue => e
          logger.info { "ignore error when copy attachment #{attachment.file_relative_path} to #{target}: #{e.message}. Turn on debug for stacktrace." }
          logger.debug { e.backtrace.join("\n") }
        end
      end
    end
  end
end
