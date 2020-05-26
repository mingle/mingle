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

# Copy from this guy:http://pastie.org/185380. fix Content-type and hack authorization
module MultipartPost

  def self.multipart_post(url, parameters, headers = {})
    boundary = "----------XnJLe9ZIbbGUYtzPQJ16u1"
    http = Net::HTTP.new(url.host, url.port)
    http.post url.path, multipart_body(parameters, boundary), headers.merge("Content-type" => "multipart/form-data; boundary=#{boundary}", 'authorization' => basic_encode(url.user, url.password))
  end
      
  def self.basic_encode(account, password)
    'Basic ' + ["#{account}:#{password}"].pack('m').delete("\r\n")
  end
    
  def self.multipart_requestify(params)
    params.inject({}) do |p, entry|
      key, value = entry
      if Hash === value
        value.each do |subkey, subvalue|
          p["#{CGI.escape(key.to_s)}[#{CGI.escape(subkey.to_s)}]"] = subvalue
        end
      else
        p[CGI.escape(key.to_s)] = value
      end
      p
    end
  end

  def self.multipart_body(params, boundary)
    multipart_requestify(params).map do |key, value|
      if value.respond_to?(:original_filename)
        puts value.path
        puts value.content_type
        File.open(value.path) do |f|
          <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"; filename="#{value.original_filename}"\r
Content-Type: #{value.content_type}\r
Content-Length: #{File.stat(value.path).size}\r
\r
#{f.read}\r
EOF
        end
      else
        <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"\rmultipart_body(parameters, boundary)
\r
#{value}\r
EOF
      end
    end.join("")+"--#{boundary}--\r"
  end
  
  def self.uploaded_file(path, content_type="application/octet-stream", filename=nil)
     filename ||= File.basename(path)
     t = Tempfile.new(filename)
     FileUtils.copy_file(path, t.path)
     (class << t; self; end;).class_eval do
       alias local_path path
         define_method(:original_filename) { filename }
         define_method(:content_type) { content_type }
     end
     return t
   end
end

