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

class DataExportProcessor < Messaging::Processor
  include RunningExportsHelper
  def on_message(message)
    begin
      @message = message
      Rails.logger.info("#{self.class.name} message: #{@message.body_hash.inspect}")

      data_dir_path = SwapDir::Export.data_directory(@message[:export_id])
      @export = Export.find_by_id(@message[:export_id])
      if @export.nil?
        Rails.logger.info("#{self.class.name} message: Cannot find export with id #{@message[:export_id]}. Aborting")
        return
      end
      return if @export.error?

      FileUtils.mkpath(data_dir_path) unless File.exists?(data_dir_path)
      export_data(data_dir_path)

      Rails.logger.info("#{self.class.name} successfully processed message: #{@message.body_hash.inspect}")
    rescue Exception => e
      exception = ExportException.new(e)
      Alarms.notify(exception, {processor: self.class.name, message:  @message.body_hash, export: @export.to_json}.merge(deliverable_details))
      @export.update_attribute(:status, Export::ERROR) unless @export.nil?
      Rails.logger.error "ExportException message: #{e.message}\n original backtrace:  \n#{e.backtrace.join("\n")}"
      update_running_exports
    end
  end

  def export_data(data_dir_path)
    excel_book = ExcelBook.new(excel_file_name)
    create_excel_book = false
    data_exporters(@message).each do |exporter|
      if @export.reload.error?
        Rails.logger.info "Aborting #{exporter.name} due to error status: #{@export.inspect}"
        return
      end
      exporter = exporter.new(data_dir_path, @message)
      unless exporter.exportable?
        update_completion_status(exporter)
        next
      end
      bm = Benchmark.ms do
        exporter.exports_to_sheet? ? exporter.export(excel_book.create_sheet(exporter.name)) : exporter.export
      end
      Rails.logger.info("Benchmark : #{exporter.class.name} for #{self.class.name} took #{bm/(1000)} seconds.")
      update_completion_status(exporter)
      create_excel_book = true
    end
    excel_book.write(data_dir_path) if create_excel_book
  end

  def excel_file_name
    raise 'Please implement in derived class'
  end

  def data_exporters(_)
    raise 'Please implement in derived class'
  end

  def data_export_size(options={})
    data_exporters(options).reduce(0) {|a, exporter| a += exporter.new('').export_count}
  end

  private
  def deliverable_details
    params = {}
    [Project, Program].each do |deliverable_class|
      id_key = "#{deliverable_class.name.downcase}_id".to_sym
      unless @message[id_key].nil?
        deliverable = deliverable_class.find_by_id(@message[id_key])
        params[deliverable_class.name.downcase.to_sym] = deliverable && deliverable.name
      end
    end
    params
  end

  def update_completion_status(exporter)
    Export.transaction do
      # Finding again as the complete status could have been updated in a parallel processor
      export = Export.find(@message[:export_id], lock:true)
      export.update_attribute(:completed, ((export.completed || 0) + exporter.export_count))
      MergeExportDataPublisher.new.publish_message(export) if export.merge_data?
    end
  end

  class ExportException < Exception
    def initialize(e)
      super(e.message)
      set_backtrace e.backtrace
    end
  end
end
