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

module WorksHelper
  include ObjectivesHelper
  include JsFilterHelper

  def done_status(work, project)
    if work.plan.program.program_projects.find_by_project_id(project.id).mapping_configured?
      work.completed? ? "Done" : "Not done"
    else
      link_to('"Done" status not defined for project', :controller => :program_projects, :action => :edit, :id => project.identifier)
    end
  end
  
  def auto_sync_message(auto_sync_turned_on)
    auto_sync_turned_on ? content_tag(:span, "(auto sync on)", :class => "auto-sync-message") : ""
  end

  def autosync_enabled?
    @autosync_filter.present?
  end

  def property_value_of_filter(filter)
    filter.value_display_value rescue "Unknown Value"
  end
  
  def auto_sync_filter_message(count)
    "#{pluralize(count, 'card')} currently #{count > 1 ? 'match' : 'matches'} your filter."
  end
  
end
