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

class MergeExportDataProcessor < Messaging::Processor
  require 'erb'
  include RunningExportsHelper
  include Zipper
  include MetricsHelper
  QUEUE = 'mingle.merge_data_export'

  def on_message(message)
    Rails.logger.info("DataExportProcessor message: #{message.inspect}")
    export = Export.find_by_id(message[:export_id])
    if export.nil?
      Rails.logger.info("#{self.class.name} message: Cannot find export with id #{message[:export_id]}. Aborting")
      return
    end
    return if export.error?

    base_dir_path = SwapDir::Export.base_directory(message[:export_id])
    data_dir_path =  SwapDir::Export.data_directory(message[:export_id])
    renderer = ERB.new(File.read(File.join(Rails.root, "app/views/sysadmin/readme.erb")))
    result = renderer.result
    File.open("#{data_dir_path}/README.txt", "w+") do |f|
      f.write(result)
    end
    zip_file_path = MingleConfiguration.installer? ? zip(base_dir_path, nil, false) : ZipperCli.zip(base_dir_path)
    final_zip_file_path = File.join(base_dir_path, export.filename)
    FileUtils.mv(zip_file_path, final_zip_file_path)
    export.update_attributes(export_file: File.new(final_zip_file_path), status: Export::COMPLETED, completed: export.total)
    if MingleConfiguration.saas? && export.status != Export::IN_PROGRESS
      add_monitoring_event('export_completed', {site_name: active_tenant.name})
      update_running_exports
    end
    # Clean up directory
    FileUtils.rm_r File.join(base_dir_path, export.dirname) unless MingleConfiguration.skip_export_dir_cleanup?
    Rails.logger.info("MergeDataExportProcessor successfully processed message: #{message.inspect}")
  end

  private
  def active_tenant
    Multitenancy.active_tenant
  end
end
