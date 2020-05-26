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

require 'uri'
require 'rack'
require "thread"
require "active_support"

class GoogleMapsMacro

  def initialize(parameters, project, current_user)
    @src = parameters['src']
    @width = parameters['width']
    @height = parameters['height']
  end
    
  def execute
    raise "Parameter src must be a recognized Google Maps URL." unless valid?
    
    %{
      <iframe src="#{source_with_embedded_output}" width="#{@width}" height="#{@height}" /> 
    }
  end
  
  def valid?
    return false unless @src
    begin
      uri = URI.parse(@src)
      return unless uri.host
      return unless (uri.scheme == "http" ||uri.scheme == "https")
      uri.host.start_with?('maps.google.com')
    rescue URI::InvalidURIError
      false
    end
  end
  
  def can_be_cached?
    true  # if appropriate, switch to true once you move your macro to production
  end
  
  private
  
  def source_with_embedded_output
    uri = URI.parse(@src)
    query = uri.query || ""
    query_params = Rack::Utils.parse_query(query)
    uri.query = query_params.merge('output' => 'embed').to_query
    uri.to_s
  end
  
end
