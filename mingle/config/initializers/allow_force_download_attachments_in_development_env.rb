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

if Rails.env.development?

  ::Rack::File

  # this allows webrick to set the correct headers
  class ::Rack::File

    ATTACHMENT_REGEX = /\/attachments(?:_(?:\d+))?\/[a-f0-9]{32}\//

    def self.is_attachment_with_force_download?(env)
      env["REQUEST_METHOD"].downcase == "get" &&
      env["PATH_INFO"] =~ ATTACHMENT_REGEX &&
      Rack::Utils.parse_nested_query(env["QUERY_STRING"]).has_key?("download")
    end

    def call(env)
      status, headers, body = dup._call(env)

      if self.class.is_attachment_with_force_download?(env)
        headers["Content-Disposition"] = "attachment; filename=\"#{File.basename(env["PATH_INFO"])}\""
      end

      [status, headers, body]
    end

  end
end
