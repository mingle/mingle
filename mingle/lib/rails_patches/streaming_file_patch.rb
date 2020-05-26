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

module ActionController
  module Streaming    
    def send_file_headers!(options)
      options.update(DEFAULT_SEND_FILE_OPTIONS.merge(options))
      [:length, :type, :disposition].each do |arg|
        raise ArgumentError, ":#{arg} option required" if options[arg].nil?
      end

      disposition = options[:disposition].dup || 'attachment'

      disposition <<= %(; filename="#{options[:filename]}") if options[:filename]

      content_type = options[:type]
      if content_type.is_a?(Symbol)
        raise ArgumentError, "Unknown MIME type #{options[:type]}" unless Mime::EXTENSION_LOOKUP.has_key?(content_type.to_s)
        content_type = Mime::Type.lookup_by_extension(content_type.to_s)
      end
      content_type = content_type.to_s.strip # fixes a problem with extra '\r' with some browsers

      headers.merge!(
        'Content-Length'            => options[:length].to_s,
        'Content-Type'              => content_type,
        'Content-Disposition'       => disposition,
        'Content-Transfer-Encoding' => 'binary'
      )

      # Fix a problem with IE 6.0 on opening downloaded files:
      # If Cache-Control: no-cache is set (which Rails does by default),
      # IE removes the file it just downloaded from its cache immediately
      # after it displays the "open/save" dialog, which means that if you
      # hit "open" the file isn't there anymore when the application that
      # is called for handling the download is run, so let's workaround that
      
      # BEGIN PATCH (commenting out the following line)
      # headers['Cache-Control'] = 'private' if headers['Cache-Control'] == 'no-cache'
      # END PATCH
    end
  end
end
