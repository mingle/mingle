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

module ProjectsHelper
  include FeedHelper
  include IconHelper
  include PagesHelper

  def project_admin_item_box(html_options={}, &block)
    styled_box(html_options.concatenative_merge(:class => 'advanced_project_item'), &block)
  end

  def allow_anonymous
    CurrentLicense.status.allow_anonymous?
  end

  def is_authorized_for(controller, action)
    return authorized?(:controller => controller, :action => action)
  end

  def link_to_open_project(name, project)
    link_to(name, project_show_path(project.identifier)).html_safe # generate url directly to bypass auth, because we did once already
  end

  protected

  def link_to_profile_page
     link_to 'your profile', :project_id => nil, :controller => 'profile', :action => 'show', :id => User.current
  end

end
