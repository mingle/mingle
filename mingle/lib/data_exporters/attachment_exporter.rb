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

class AttachmentExporter

  def initialize(data_dir)
    @basedir = FileUtils.mkpath(File.join(data_dir, 'Attachments')).first
  end

  def export_for(attachable)
    attachment_paths = []
    attachable.attachments.each do |attachment|
      target = File.join(@basedir, attachable.export_dir, attachment.file_name)
      begin
        attachment.file_copy_to(target) unless MingleConfiguration.skip_export_attachments?
        attachment_paths << File.join('Attachments', attachable.export_dir, attachment.file_name)
      rescue => e
        Rails.logger.info "ignore error when exporting attachment #{attachment.file_relative_path} to #{target}: #{e.message}"
      end
    end
    attachment_paths
  end

  class Empty
    def initialize(_)
    end

    def export_for(_)
      []
    end
  end
end
