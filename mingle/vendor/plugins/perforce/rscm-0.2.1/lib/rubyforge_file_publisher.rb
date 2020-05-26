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

# Copyright 2005 by Aslak Hellesoy (aslak.hellesoy@gmail.com)
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.

require 'lib/multipart'

module Rake

  # This publisher allows scripted submission of RubyForge's release files form.
  class RubyForgeFilePublisher
    # extension => [mime_type, rubyforge_bin_type_id, rubyforge_src_type_id]
    FILE_TYPES = Hash.new(["application/octet-stream", 9999, 5900]) # default to "other", "other source"
    FILE_TYPES.merge!(
      ".deb"  => ["application/octet-stream", 1000],

      # all of these can be source or binary
      ".rpm"  => ["application/octet-stream", 2000, 5100],
      ".zip"  => ["application/octet-stream", 3000, 5000],
      ".bz2"  => ["application/octet-stream", 3100, 5010],
      ".gz"   => ["application/octet-stream", 3110, 5020],
      ".jpg"  => ["application/octet-stream", 8000],
      ".jpeg" => ["application/octet-stream", 8000],
      ".txt"  => ["text/plain", 8100],
      ".html" => ["text/html", 8200],
      ".pdf"  => ["application/octet-stream", 8300],
      ".ebuild"  => ["application/octet-stream", 1300],
      ".exe"  => ["application/octet-stream", 1100],
      ".dmg"  => ["application/octet-stream", 1200],
      ".gem"  => ["application/octet-stream", 1400],
      ".sig"  => ["application/octet-stream", 8150]
    )
    
    # Returns an array of 2 elements where 1st is mime-type and 2nd is rubyforge-type
    def types(filename, source)
      extension = nil
      if(filename =~ /.*(\.[a-zA-Z]*)/)
        extension = $1
      end

      types = FILE_TYPES[extension]
      if(types.length == 3 && source)
        [types[0], types[2]]
      else
        types
      end
    end

    # processor_id
    I386           = 1000
    IA64           = 6000
    ALPHA          = 7000
    ANY            = 8000
    PPC            = 2000
    MIPS           = 3000
    SPARC          = 4000
    ULTRA_SPARC    = 5000
    OTHER_PLATFORM = 9999

    # Create a publisher for a RubyForge project with id +group_id+.
    # The RubyForge +user+'s password must be specified in the environment
    # variable RUBYFORGE_PASSWORD.
    # 
    # This publisher will upload/release a +file+ for a RubyForge project
    # with id +group_id+, under the release package +package_id+ and
    # name the release +release_name+.
    #
    # The package_id can be found by viewing the source of the HTML page
    # http://rubyforge.org/frs/admin/qrs.php?package=&group_id=YOUR_GROUP_ID
    # Look for a select tag named package_id and see what the alternatives are.
    #
    # The optional argument +source+ can be set to true if the file
    # pointed to by +filename+ is a source file of some sort. This is
    # to make sure RubyForge lists the file as the appropriate type.
    # (This task will figure out the correct mime-type and rubyforge type
    # based on the file's extension and the source parameter).
    #
    # If called with a block, the file will be uploaded at the end of the
    # construction of this object. Otherwise, the +upload+ method will
    # have to be called explicitly.
    #
    # The following attributes (which represent form data) have default 
    # values, but can be set/overridden explicitly:
    #
    # * processor_id
    # * release_date
    # * release_notes
    # * change_log
    #
    def initialize(group_id, user, file, package_id, release_name, source=false) # :yield: self
      
      @group_id = group_id
      @user = user
      @file = file

      @form_data = {"preformatted" => "1", "submit" => "Release File" }

      self.package_id = package_id
      self.release_name = release_name

      @types = types(file, source)
      self.type_id = @types[1]
      self.processor_id = ANY
      self.release_date = Time.now.utc
      self.release_notes = "Uploaded by Rake::RubyforgeFilePublisher"
      self.release_changes = "This is a change log"

      yield self if block_given?
      upload if block_given?
    end

    def package_id=(s)
      @form_data["package_id"] = s
    end
    def package_id
      @form_data["package_id"]
    end
    def release_name=(s)
      @form_data["release_name"] = s
    end
    def type_id=(s)
      @form_data["type_id"] = s
    end
    def processor_id=(s)
      @form_data["processor_id"] = s
    end
    def release_date=(t)
      @form_data["release_date"] = t.strftime("%Y-%m-%d %H:%M")
    end
    def release_notes=(s)
      @form_data["release_notes"] = s
    end
    def release_changes=(s)
      @form_data["release_changes"] = s
    end
    def preformatted=(b)
      @form_data["preformatted"] = b ? "1" : "0"
    end

    def upload
      Net::HTTP.start('rubyforge.org', 80) do |http|
    
        # log in so we get a cookie. we need it to post the upload form.
        password = ENV['RUBYFORGE_PASSWORD']
        raise "The RUBYFORGE_PASSWORD environment variable is not set.\n" +
              "It can be passed on the Rake command line with RUBYFORGE_PASSWORD=<your password>" if password.nil?

        response, data = http.post("/account/login.php", "form_loginname=#{@user}&form_pw=#{password}&login=Login")
        cookie = CGI::Cookie.parse(response['set-cookie'])['session_ser'].to_s
        header = {"Cookie" => cookie, "Host" => "rubyforge.org"}

        response, data = http.get(response['location'], header)

        upload_form = "/frs/admin/qrs.php?package=#{package_id}&group_id=#{@group_id}"
        response, data = http.get(upload_form, header)

        params = []
        @form_data.each do |k, v|
          params << Net::Param.new(k,v)
        end
        params << Net::FileParam.new("userfile", @file, @types[0])
        header["Referer"] = "http://rubyforge.org#{upload_form}"
        response, data = http.post_multipart(upload_form, params, header)
        
        File.open("rf.html", "w") { |io|
          io.write data
        }
#        upload_redirect = response['location']
#        response, data = http.get(upload_redirect, header)
      end
    end

  end
end
