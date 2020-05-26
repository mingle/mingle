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

class AttachmentsController < ProjectApplicationController
  include AttachmentNameUniqueness
  include AttachmentsHelper
  include DependencyAccess

  allow :get_access_for => [:show, :index],
        :put_access_for => [:create]

  skip_before_filter :require_project_membership_or_admin, :only => [:show, :create, :index]
  before_filter :require_dependency_attachment_read_access, :only => [:show]
  before_filter :require_dependency_attachment_write_access, :only => [:create]

  def show
    attachment = @project.attachments.find(params[:id])
    redirect_to attachment.url(params.has_key?("download"))
  end

  def index
    attachable = attachable_from_params(params)
    if attachable
      render :json => attachments_as_json(attachable)
    else
      render :nothing => true, :status => :not_found
    end
  end

  def create
    if params[:upload]
      filename = ensure_unique_filename_in_project(params[:upload].original_filename, @project)
      params[:upload].instance_variable_set("@original_filename", filename)
    end

    success, attachment = create_attachment_and_attaching(@project, attachable_from_params, params[:upload], params[:s3])
    if success
      response = {
        :path => project_attachment_path(@project.identifier, attachment),
        :filename => attachment.file_name,
        :attachment_id => attachment.id
      }.to_json
      if params["CKEditorFuncNum"]
        render :layout => false, :text => %Q{<script>window.parent.CKEDITOR.tools.callFunction(#{params["CKEditorFuncNum"]}, #{response.inspect});</script>}
      else
        render :layout => false, :json => response
      end
    else
      render :nothing => true, :status => 422
    end
  end

  def retrieve_from_external
    url = params[:external]
    # this name should already be unique (generated from the UI), but do this for good measure
    basename = ensure_unique_filename_in_project(params[:basename], @project)

    begin
      Dir.mktmpdir do |dir|
        file = RetrievedFile.retrieve(url, basename, true)

        if file.status >= 400
          render :layout => false, :json => {:error => "response code = #{file.status}"}.to_json, :status => 422
          return
        end

        success, attachment = create_attachment_and_attaching(@project, attachable_from_params, file, params[:s3])
        if success
          response = {
            :path => project_attachment_path(@project.identifier, attachment),
            :filename => attachment.file_name,
            :attachment_id => attachment.id,
            :contentType => file.content_type
          }.to_json
          render :layout => false, :json => response
        else
          render :layout => false, :json => {:error => "failed to persist attachment: #{File.basename(filename)}"}.to_json, :status => 422
        end
      end
    # URI::InvalidURIError floods the log, and it's caused by browser behavior.
    rescue URI::InvalidURIError => e
      render :layout => false, :json => {:error => "exception #{e.class.name}: #{e.message}"}.to_json, :status => 422
    rescue => e
      Rails.logger.error(e)
      render :layout => false, :json => {:error => "exception #{e.class.name}: #{e.message}"}.to_json, :status => 422
    end

  end

  def require_dependency_attachment_write_access
    if dependency = dependency_from_params
      check_dependency_write_access(dependency)
    else
      require_project_membership_or_admin
    end
  end

  def require_dependency_attachment_read_access
    if dependency = dependency_from_params
      check_dependency_read_access(dependency)
    else
      require_project_membership_or_admin
    end
  end

  def dependency_from_params
    if params[:attachable].present? && params[:attachable][:id].present? && params[:attachable][:type].present?
      Dependency.find(params[:attachable][:id]) if (params[:attachable][:type].downcase == Dependency.name.downcase)
    elsif params[:id]
      attachment = @project.attachments.find(params[:id])
      attachment.dependency_attachable
    end
  end

  def check_dependency_write_access(dependency)
    unless authorized_to_edit_dependency(dependency)
      raise UserAccessAuthorizationError, FORBIDDEN_MESSAGE
    end
  end

  def check_dependency_read_access(dependency)
    unless authorized_to_access_dependency(dependency)
      raise UserAccessAuthorizationError, FORBIDDEN_MESSAGE
    end
  end

  class RetrievedFile # loosely mimic multipart uploaded file
    attr_reader :original_filename, :status
    attr_accessor :content_type

    # make this overridable in tests
    def self.wget(url)
      HTTParty.get(url)
    end

    def self.retrieve(url, filename, binary=true)
      response = self.wget(url)
      filename += ".#{response.content_type.split("/").pop}" if File.extname(filename).blank?

      instance = if response.code < 400
        File.open(filename, binary ? "wb" : "w") do |f|
          f.write response.parsed_response
        end
        self.new(filename, response.content_type, binary)
      else
        self.new(nil, response.content_type, binary)
      end

      instance.update_from_response(response)
      instance
    ensure
      FileUtils.rm_rf filename
    end

    def initialize(path, content_type = Mime::TEXT, binary = false)
      return if path.nil?
      raise "#{path} file does not exist" unless File.exist?(path)
      @content_type = content_type
      @original_filename = path.sub(/^.*#{File::SEPARATOR}([^#{File::SEPARATOR}]+)$/) { $1 }
      @tempfile = Tempfile.new(@original_filename)
      @tempfile.set_encoding(Encoding::BINARY) if @tempfile.respond_to?(:set_encoding)
      @tempfile.binmode if binary
      FileUtils.copy_file(path, @tempfile.path)
    end

    def update_from_response(response)
      @status = response.code
      @content_type = response.content_type
    end

    def path #:nodoc:
      @tempfile.path
    end

    alias local_path path

    def method_missing(method_name, *args, &block) #:nodoc:
      @tempfile.__send__(method_name, *args, &block)
    end
  end

  private

  def attachable_from_params(params=params)
    if params[:attachable].present? && params[:attachable][:id].present?
      association = params[:attachable][:type].pluralize.to_sym
      @project.send(association).find(params[:attachable][:id])
    end
  end
end
