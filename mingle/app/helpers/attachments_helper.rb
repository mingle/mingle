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

module AttachmentsHelper
  include AttachmentNameUniqueness

  def attachments_data_attrs(renderable)
    renderable_type = renderable.class.name.underscore
    project_identifier = project_identifier_from_attachable(renderable)
    options = {
      :"data-attachments-load-url" => url_for(:controller => "attachments", :action => "index", :project_id => project_identifier, :attachable => { :type => renderable_type, :id => renderable.id }),
      :"data-attachments-upload-url" => project_attachments_path(project_identifier, :attachable => { :type => renderable_type, :id => renderable.id }),
      :"data-attachments-upload-external-url" => attachments_get_external_path(project_identifier, :attachable => { :type => renderable_type, :id => renderable.id }),
      :"data-attachment-maxsize" => (MingleConfiguration.attachment_size_limit || 1024).to_i,
      :"data-attachable-id" => renderable.id
    }

    if MingleConfiguration.use_s3_attachments_storage?
      config = s3_presigned_post(MingleConfiguration.attachments_bucket_name, :ignore => ["content-type"])
      options.merge!({
        :"data-s3-url" => config.url.to_s,
        :"data-s3-fields" => config.fields.to_json,
        :"data-s3-base-key" => random_s3_key,
      })
    end

    options
  end

  def project_identifier_from_attachable(attachable)
    attachable.respond_to?(:raising_project) ? attachable.raising_project.identifier : attachable.project.identifier
  end

  def attachments_as_json(renderable)
    renderable.attachments.map do |attach|
      if attach.id
        {:filename => attach.file_name, :url => project_attachment_path(attach.project.identifier, :id => attach.id), :id => attach.id}
      end
    end.compact.to_json
  end

  def create_attachment_and_attaching(project, attachable, file, s3=nil)
    success, attachment = create_attachment(project, file, s3)

    if success && attachable
      attachable.attachings << attachable.attachings.new(:attachment => attachment)
      success = attachable.save
    end

    [success, attachment]
  end

  def create_attachment(project, file, s3=nil)
    attachment = Attachment.new(:project => project)
    success = if file.nil? && !s3.nil?
                src = AWS::S3.new.buckets[MingleConfiguration.attachments_bucket_name].objects[s3]
                filename = ensure_unique_filename_in_project(File.basename(src.key), project)

                attachment.dyna_path
                attachment.write_attribute(:file, filename)
                attachment.save(false).tap do
                  path = [attachment.path, attachment.file_relative_path].join("/")
                  path = MingleConfiguration.app_namespace ? [MingleConfiguration.app_namespace, path].join("/") : path
                  src.move_to(path)
                end
              else
                attachment.file = file
                attachment.save
              end

    [success, attachment]
  end

end
