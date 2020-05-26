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

module LanesHelper

  def create_lane_url(view, view_helper)
    build_url_for("create", view, view_helper)
  end

  def rename_lane_url(view, view_helper)
    build_url_for("update", view, view_helper)
  end

  def hide_lane_url(view, view_helper)
    build_url_for("destroy", view, view_helper)
  end

  def build_url_for(action, view, view_helper)
    view_helper.url_for(view.to_params.merge(:controller => "lanes", :action => action, :format => "js", :project_id => @project.identifier))
  end

end
