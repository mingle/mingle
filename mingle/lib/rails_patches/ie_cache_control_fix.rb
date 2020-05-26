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
  class Response < Rack::Response
    private
    def handle_conditional_get_with_ie_fix!
      handle_conditional_get_without_ie_fix! unless ie_request?
    end
    alias_method_chain :handle_conditional_get!, :ie_fix

    def ie_request?
      return false unless request.headers['HTTP_USER_AGENT'] 
      request.headers['HTTP_USER_AGENT'].include?('MSIE')
    end
  end
end
