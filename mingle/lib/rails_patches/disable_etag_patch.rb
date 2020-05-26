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

# As part of the Rails 2.1 to Rails 2.3 upgrade, we noticed that sometimes pages were displayed as blank in the browser, and such requests return with a 304 Not Modified status.
# We found it is because of the etag functionality that came along in Rails 2.2.  We are not sure why the browser wasn't showing a client-side cached version of the page.  So we
# removed the code that sets the body to an empty string and the response code to 304.

module ActionController # :nodoc:
  class Response < Rack::Response
    
    private
    
    def handle_conditional_get!
      if etag? || last_modified?
        set_conditional_cache_control!
      end
    end
    
  end
end
