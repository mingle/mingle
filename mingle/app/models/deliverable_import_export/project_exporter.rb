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

module DeliverableImportExport
  class ProjectExporter
    include ProgressBar, RoutingUrlHelper

    attr_accessor :project, :user, :progress, :filename

    class << self

      def export_with_error_raised(options)
        asynch_request = User.current.asynch_requests.create_project_export_asynch_request(options[:project].identifier)
        message = options.merge(:request_id => asynch_request.id, :user_id => User.current.id, :project_id => options[:project].id)
        exporter = fromActiveMQMessage(message)
        asynch_request.update_attributes(:message => message)
        exporter.progress.reload
        exported_file = exporter.export(options)
        raise "Error during exporting project(#{exporter.project.name.bold}): #{exporter.error_details.join("\n")}" if exporter.failed?
        exported_file
      end

      def export_after_upgrade(project, import_directory)
        upgrade_user = if User.count == 0
          User.create!(:name => 'upgrade user', :login => 'mingle', :email => 'upgradeuser@example.com', :password => 'p', :password_confirmation => 'p')
        else
          User.find(:first)
        end

        models, select_sql = project.template? ? [ImportExport::TEMPLATE_MODELS(), :select_for_template_sql] : [ImportExport::ALL_MODELS(), :select_by_project_sql]

        project.with_active_project do
          temporary_directory = RailsTmpDir::ProjectExport.new_temporary_directory(project)
          basedir = temporary_directory.dirname

          table = ImportExport::TableWithModel.new(basedir, 'schema_migrations', nil)
          table.write("SELECT * FROM #{ActiveRecord::Base.connection.safe_table_name('schema_migrations')}", Project.connection)

          models.each do |model|
            table_name = model.table_name
            if table_name =~ /^#{ActiveRecord::Base.table_name_prefix}(.*)/
              table_name = $1
            end
            table = ImportExport::TableWithModel.new(basedir, table_name, model)
            table.write_pages(select_sql, project)
          end
          ['attachments*', 'user', 'project'].each do |dir|
            Dir.glob(File.join(import_directory, dir)) do |dir|
              FileUtils.mv(dir, basedir)
            end
          end
          basedir
        end
      end

      def fromActiveMQMessage(message)
        project = Project.find message[:project_id]
        progress = AsynchRequest.find(message[:request_id])
        user = User.find(message[:user_id])
        attributes = { :project => project, :progress => progress, :user => user }
        exporter = message[:template] ? ProjectTemplateExporter.new(attributes) : ProjectExporter.new(attributes)
        exporter.mark_new
        exporter
      end

    end

    delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :completed?, :with_progress, :to => :@progress
    delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

    def initialize(attributes={})
      attributes.each { |k,v| self.send("#{k}=", v) }
    end

    def progress
      defined?(@progress) ? @progress : AsynchRequest::NullProgress.new
    end

    def mark_new
      self.progress.update_attributes(:total => ImportExport::ALL_MODELS().size + 2)
      update_progress_message("Export of project #{project.name.bold} has been queued. Please wait here for export to begin.")
      mark_queued
    end

    def process!
      self.project.last_export_date = Time.now
      self.project.save
      export
    rescue => e
      on_fatal_error(e)
    end

    # todo remove unused options
    def export(options = {})
      with_progress do
        stepped_export(ImportExport::ALL_MODELS(), :select_by_project_sql) do
          step("Exporting attachments."){ export_files(project.attachments) }
          step("Exporting icons."){
            exported_users = table('users').select_records(:select_by_project_sql, project)
            icons_to_export = exported_users << project
            DeliverableImportExport::IconExporter.new(@basedir).export_icons(icons_to_export)
          }
        end
      end
    end

    private

    def on_fatal_error(e)
      log_error(e, "Error while processing export") rescue nil
      update_progress_message("Error while processing export, please contact your Mingle administrator.")
    end

    def stepped_export(models, sql_method, &extra_steps)
      export_models(models, sql_method, &extra_steps)
      self.filename = export_file.pathname
    end

    def export_models(models, sql_method, &extra_steps)
      project.with_active_project do
        @tables = {}
        @temporary_directory = RailsTmpDir::ProjectExport.new_temporary_directory(project)
        @basedir = @temporary_directory.dirname

        table('schema_migrations').write("SELECT * FROM #{ActiveRecord::Base.connection.safe_table_name('schema_migrations')}", Project.connection)

        models.each do |model|
          table_name = model.table_name
          step("Exporting #{table_name.humanize.downcase} table") do
            begin
              table(table_name, model).write_pages(sql_method, project)
            rescue Exception => e
              ActiveRecord::Base.logger.error {e.backtrace.join("\n")}
              raise e
            end
          end
        end
        yield if block_given?
        step("Preparing exported data for download."){ ExportDownload.new(@temporary_directory, progress, export_file).zip_temp_files_and_copy_to_swap_dir }
      end
    end

    def export_files(attachments)
      attachments.each do |attachment|
        target = File.join(@basedir, attachment.path, attachment.file_relative_path)
        begin
          attachment.file_copy_to(target)
        rescue => e
          logger.info { "ignore error when copy attachment #{attachment.file_relative_path} to #{target}: #{e.message}. Turn on debug for stacktrace." }
          logger.debug { e.backtrace.join("\n") }
        end
      end
    end

    def table(table_name, model = nil)
      @tables[table_name] ||= ImportExport::TableWithModel.new(@basedir, table_name, model)
    end

    private

    def export_file
      @export_file ||= SwapDir::ProjectExport.file(project)
    end

    def cp_file(source, target)
      FileUtils.mkpath(File.dirname(target))
      FileUtils.cp(source, target)
    rescue Exception => e
      logger.info { "get an error when copy #{source} to #{target}: " }
      logger.info { e }
    end
  end
end
