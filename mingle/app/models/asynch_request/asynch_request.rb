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

class AsynchRequest < ActiveRecord::Base
  belongs_to :user
  serialize :message

  before_save :truncate_progress_message, :set_default_deliverable_identifier

  file_column :tmp_file, :root_path => SwapDir::SwapFileProxy.new.pathname, :fix_file_extensions => false

  #This feels like such a hack. Have to call this
  #as Rails does very very silly things with serialized
  #attributes, if they are not deserialized before save again.
  #Essentially, Rails will YAML encode an already serialized
  #attribute a second time on save, if nothing ever deserialized it
  #via a magical access such as this. That would result in the
  #serialized attribute changing from a serialzed object to a
  #YAML encoded serialized string. This after find just references
  #the message object, thereby forcing a deserialization, thereby making this problem go away.
  def after_find
    self.message
  end

  def validate_tmp_file_size
    return true if tmp_file.nil?
    file_size_limit = MingleConfiguration.asynch_request_tmp_file_size_limit
    return true if file_size_limit.nil?
    file_size_limit = file_size_limit.to_i

    file_size = File.size(tmp_file)/1024/1024
    if file_size >= file_size_limit
      self.errors.add_to_base("File cannot be larger than #{file_size_limit}MB.")
    end
  end

  class NullProgress < self
    def status; end
    def progress_message; end
    def error_count; 0; end
    def warning_count; 0; end
    def total; 0; end
    def completed; 0; end
    def type; end
    def message; end
    def deliverable_identifier; end

    attr_writer :status, :progress_message, :error_count, :warning_count, :total, :completed, :type, :message, :deliverable_identifier

    def update_attribute(name, value); end
    def update_attributes(values); end
  end

  class << self

    def create_program_import_asynch_request(program_identifier, import_file)
      ProgramImportAsynchRequest.create(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => program_identifier, :tmp_file => import_file))
    end

    def create_program_export_asynch_request(program_identifier)
      DeliverableImportExport::ProgramExportAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => program_identifier))
    end

    def create_dependencies_export_asynch_request(identifier)
      DeliverableImportExport::DependenciesExportAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => identifier))
    end

    def create_dependencies_import_preview_asynch_request(identifier, import_file)
      DeliverableImportExport::DependenciesImportPreviewAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => identifier, :tmp_file => import_file))
    end

    def create_dependencies_import_asynch_request(identifier)
      DeliverableImportExport::DependenciesImportAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => identifier))
    end

    def create_project_export_asynch_request(project_identifier)
      ProjectExportAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => project_identifier))
    end

    def create_project_import_asynch_request(project_identifier, import_file)
      ProjectImportAsynchRequest.create(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => project_identifier, :tmp_file => import_file))
    end

    def create_card_import_asynch_request(project_identifier)
      CardImportAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => project_identifier))
    end

    def create_card_import_preview_asynch_request(project_identifier, import_file)
      CardImportingPreviewAsynchRequest.create!(current_scoped_methods[:create].merge(:status => "queued", :deliverable_identifier => project_identifier, :tmp_file => import_file))
    end
  end

  def localize_tmp_file
    tmp_fname = [SecureRandomHelper.random_32_char_hex, 'tmp'].join('.')
    File.join(root_dir, tmp_fname).tap do |local_tmp_file|
      FileUtils.mkdir_p(File.dirname(local_tmp_file))
      tmp_file_copy_to(local_tmp_file)
    end
  end

  def root_dir
    File.join(RAILS_TMP_DIR, 'asynch_request', self.id.to_s)
  end

  def progress
    self.reload
  end

  def complete_url(controller, params)
    url_to_build = failed? ? :failed_url : :success_url
    self.send(url_to_build, controller, params)
  end

  def info_type
    return :error if failed?
    completed? ? :notice : :info
  end

  def in_progress_proc
    @in_progress_proc ||= Proc.new do |progress_message, total, completed|
      update_progress_message(progress_message)
      if progress_percent < completed * 1.0 / total
        self.total = total
        self.completed = completed
      end
      save!
    end
  end

  def with_progress
    SwapDir::ProgressBar.error_file(self).delete
    SwapDir::ProgressBar.warning_file(self).delete

    in_progress_proc.call(nil, 100, 0)
    mark_in_progress
    yield in_progress_proc
  rescue => e
    logger.error("Error during #{self.class.name.titleize.downcase} #{e}:\n#{e.backtrace.join("\n")}") if defined?(logger)
    add_error(e.message)
  ensure
    self.completed = self.total
    mark_completed(success?)
    self.save
  end

  def step(description, &block)
    SimpleBench.bench description do
      update_progress_message(description)
      block.call if block_given?
      self.update_attribute :completed, completed + 1 if completed < total
    end
  end

  def update_progress_message(msg)
    return if msg.blank?
    progress_messages << msg
    self.progress_message = msg
    save!
  end

  def progress_messages
    @progress_messages ||= []
  end

  #TODO: private?
  def completed?
    self.total == self.completed && self.completed_status?
  end

  #TODO: private?
  def failed?
    error_count > 0
  end

  def progress_percent
    return 0 if self.total.nil? || self.total <= 0
    self.completed * 1.0 / self.total
  end

  def success?
    !failed?
  end

  def error_details
    return [] if error_count == 0
    message[:errors]
  end

  def warning_details
    return [] if warning_count == 0
    message[:warnings]
  end

  def add_error(error_message)
    add_message(:errors, error_message)
    update_attribute(:error_count, error_count + 1)
  end

  def add_warning(warning_message)
    add_message(:warnings, warning_message)
    update_attribute(:warning_count, warning_count + 1)
  end

  def add_message(type, value)
    self.message ||= {}
    self.message[type] ||= []
    self.message[type] << value.to_s.strip
  end

  def in_progress?
    self.status == 'in progress'
  end

  def completed_status?
    self.status =~ /^completed/ ? true : false
  end

  def mark_queued
    self.status = 'queued'
  end

  def mark_completed_successfully
    update_attribute(:status, "completed successfully")
  end

  def mark_completed_failed
    update_attribute(:status, "completed failed")
  end

  def mark_in_progress
    update_attribute(:status, 'in progress')
  end

  def mark_completed(success)
    if success
      mark_completed_successfully
    else
      mark_completed_failed
    end
  end

  def tmp_file_name
    File.basename(tmp_file_relative_path)
  end

  private

  def truncate_progress_message
    # 1300 is about how many chars Oracle can store in a 4000 byte string field
    self.progress_message = self.progress_message.slice(0..(1300-1)) if self.progress_message
  end

  def set_default_deliverable_identifier
    if self.deliverable_identifier.blank?
      self.deliverable_identifier = "unassigned"
    end
  end
end
