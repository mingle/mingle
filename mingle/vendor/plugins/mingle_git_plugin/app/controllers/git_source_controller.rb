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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0.txt)

class GitSourceController < ProjectApplicationController
  
  def load_latest_info
    revisions = @project.revisions.find(:all, :conditions => ["identifier in (?)", params[:commits]])
    render(:update) do |page|
      page.select("#svn_browser td.to-be-replaced").each do |element|
        element.innerHTML = "Still caching..."
      end
      
      revisions.each do |rev|
        page.select("#svn_browser td.#{rev.identifier}").each do |element|
          page.replace(element, :partial => 'node_table_row_with_detail', :locals => { :revision => rev })
        end
      end
    end
  end
end
