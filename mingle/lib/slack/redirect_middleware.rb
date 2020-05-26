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


redirect_url = Proc.new do |matched, env|
  group = Group.find_by_id(matched[1])
  identifier = group && group.deliverable.is_a?(Project) && group.deliverable.identifier
  MingleConfiguration.saas? && identifier && env.include?('HTTP_MINGLE_API_KEY') ? "/api/v2/projects/#{identifier}/#{matched[2]}" : matched[0]
end


# Redirect all api calls with team_id to projects controller. Needed for slack app calls to mingle. Tenant needs to be actiavted for this in multitenancy mode
if MingleConfiguration.multitenancy_mode?
	ActionController::Dispatcher.middleware.insert_after(Multitenancy::TenantManagement, Rack::Rewrite) do
	  rewrite %r{/api/v2/slack/teams/(\d+)/(.*)}, redirect_url
	end
else
	ActionController::Dispatcher.middleware.insert_before(Rack::Lock, Rack::Rewrite) do
	  rewrite %r{/api/v2/slack/teams/(\d+)/(.*)}, redirect_url
	end
end
