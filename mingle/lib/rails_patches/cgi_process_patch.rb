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

# The method dispatch_cgi asks the CGI object for its env_table, which is a hash or is hash-like object.  It then tries to add keys, but is not allowed
# because for some reason the hash or hash-like object is not modifiable.  So we make a new hash on the first line.

module ActionController #:nodoc:
  class CGIHandler
    
    def self.dispatch_cgi(app, cgi, out = $stdout)
      env = Hash[cgi.__send__(:env_table)]   # this is the patched line
      env.delete "HTTP_CONTENT_LENGTH"

      cgi.stdinput.extend ProperStream

      env["SCRIPT_NAME"] = "" if env["SCRIPT_NAME"] == "/"

      env.update({
        "rack.version" => [0,1],
        "rack.input" => cgi.stdinput,
        "rack.errors" => $stderr,
        "rack.multithread" => false,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
      })

      env["QUERY_STRING"] ||= ""
      env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
      env["REQUEST_PATH"] ||= "/"
      env.delete "PATH_INFO" if env["PATH_INFO"] == ""

      status, headers, body = app.call(env)
      begin
        out.binmode if out.respond_to?(:binmode)
        out.sync = false if out.respond_to?(:sync=)

        headers['Status'] = status.to_s

        if headers.include?('Set-Cookie')
          headers['cookie'] = headers.delete('Set-Cookie').split("\n")
        end

        out.write(cgi.header(headers))

        body.each { |part|
          out.write part
          out.flush if out.respond_to?(:flush)
        }
      ensure
        body.close if body.respond_to?(:close)
      end
    end
    
  end
end
