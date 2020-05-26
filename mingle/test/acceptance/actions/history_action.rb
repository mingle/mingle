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

module HistoryAction
  def navigate_to_history_for(project, period = nil, propeties={})
    @browser.run_once_history_generation
    project = project.identifier if project.respond_to? :identifier
    url = "/projects/#{project}/history"
    url += "?" if period or !propeties.empty?
    url += "period=#{period}" if period
    url += "&" if period and !propeties.empty?
    url += propeties.collect do |property_name, value|
      if property_name == :tags
        "involved_filter_tags=#{value.join(', ')}"
      else
        "involved_filter_properties[#{property_name}]=#{value}"
      end
    end.join('&')
    @browser.open url
  end
end
