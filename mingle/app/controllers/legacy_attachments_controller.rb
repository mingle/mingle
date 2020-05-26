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

class LegacyAttachmentsController < ProjectApplicationController

  allow :get_access_for => [:show]
  skip_before_filter :load_project
  prepend_before_filter :load_project_of_attachment

  def show
    options = { :disposition => params.has_key?("download") ? "attachment" : "inline" }
    mime_type = Rack::Mime::MIME_TYPES[File.extname(@attachment.file_name.downcase)]
    options[:type] = mime_type unless mime_type.blank?

    send_file(@attachment.file, options)
  end

  private

  def load_project_of_attachment
    @attachment = Attachment.find(params[:id])
    @project = Project.find(@attachment.project_id)
  end

end
