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
class GoogleCalendarMacro

  def initialize(parameters, project, current_user)
    @src = parameters['src']
    @width = parameters['width']
    @height = parameters['height']
  end
    
  def execute
    raise "Parameter src must be a recognized Google Calendar URL." unless valid?
    
    <<-HTML
      <iframe src="#{@src}" style=" border-width:0 " width="#{@width}" frameborder="0" height="#{@height}">
      </iframe>
    HTML
  end
  
  def can_be_cached?
    false
  end
  
  private
  
  def valid?
    begin
      uri = URI.parse(@src)
    rescue URI::InvalidURIError
      return false
    end
    return unless has_valid_scheme?(uri)
    return unless has_valid_host?(uri)
    return unless has_valid_query?(uri)
    return unless has_valid_path?(uri)
    true
  end
  
  private
  
  def has_valid_scheme?(uri)
    uri.scheme && (uri.scheme == "http" || uri.scheme == "https")
  end
  
  def has_valid_host?(uri)
    uri.host && uri.host.start_with?('www.google.com')
  end
  
  def has_valid_query?(uri)
    uri.query && uri.query.include?('src')
  end
  
  def has_valid_path?(uri)
    uri.path && uri.path.include?("/calendar")
  end
  
end

