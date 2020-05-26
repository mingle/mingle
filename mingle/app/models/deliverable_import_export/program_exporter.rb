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

require 'deliverable_import_export/program_export'

class ProgramExporter
  include ProgressBar

  attr_accessor :program, :progress, :user, :filename

  def initialize(program, progress, user)
    @program = program
    @progress = progress
    @user = user
    @export_file = SwapDir::ProgramExport.file(@program)
  end

  def self.export_after_upgrade(program_identifier)
    user = User.first || User.create!(:name => 'planner', :login => 'planner', :email => 'planner@thoughtworks-studios.com', :password => 'p', :password_confirmation => 'p')
    asynch_request = user.asynch_requests.create_program_export_asynch_request(program_identifier)
    message = {:program_identifier => program_identifier, :user_id => user.id, :request_id => asynch_request.id}
    export = fromActiveMQMessage(message)
    asynch_request.update_attributes(:message => message)
    export.progress.reload
    exported_file = export.process!
    raise export.error_details.join(', ') if export.failed?
    exported_file
  end

  def self.fromActiveMQMessage(message)
    program = Program.find_by_identifier message[:program_identifier]
    progress = AsynchRequest.find(message[:request_id])
    user = User.find(message[:user_id])
    new(program, progress, user).tap do |export|
      export.mark_new
    end
  end

  def mark_new
    self.progress.update_attributes(:total => ProgramExport.models.size)
    @progress.update_progress_message("Export of #{program.name.bold} has been queued. Please wait here for export to begin.")
    @progress.mark_queued
  end

  def process!
    with_progress do
      stepped_export(ProgramExport.models, :select_by_program_sql)
    end
    mark_completed_successfully
    @export_file.pathname
  end

  def stepped_export(models, sql_method)
    export_models(models, sql_method)
    step("Exporting icons."){
      exported_users = @tables.table('users', User).select_records(:select_by_program_sql, self.program)
      DeliverableImportExport::IconExporter.new(@basedir).export_icons(exported_users)
    }

    step("Preparing exported data for download."){ ExportDownload.new(@temporary_directory, @progress, @export_file).zip_temp_files_and_copy_to_swap_dir }
    self.filename = @export_file.pathname
  end

  private

  def export_models(models, sql_method)
    @temporary_directory = RailsTmpDir::ProjectExport.new_temporary_directory(self.program)
    @basedir = @temporary_directory.dirname
    @tables = ImportExport::TableModels.new(@basedir)
    @tables.table('schema_migrations').write("SELECT * FROM #{ActiveRecord::Base.connection.safe_table_name('schema_migrations')}", Program.connection)
    models.each do |model|
      table_name = model.table_name
      if table_name =~ /^#{ActiveRecord::Base.table_name_prefix}(.*)/
        table_name = $1
      end
      step("Exporting #{table_name.humanize.downcase} table") do
        begin
          @tables.table(table_name, model).write_pages(sql_method, self.program)
        rescue Exception => e
          ActiveRecord::Base.logger.error {e.backtrace.join("\n")}
          raise e
        end
      end
    end
  end
  
end
