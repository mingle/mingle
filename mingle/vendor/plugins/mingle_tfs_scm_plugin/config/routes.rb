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

ActionController::Routing::Routes.draw do |map|
  map.with_options :controller => 'repository' do |tfsscm_configuration|
    tfsscm_configuration.tfsscm_configurations_show 'projects/:project_id/tfsscm_configurations', :action => 'index', :conditions => {:method => :get}, :repository_type => "TfsscmConfiguration", :api_version => "v2"

    tfsscm_configuration.rest_tfsscm_configurations_index 'api/v2/projects/:project_id/tfsscm_configurations.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml', :repository_type => "TfsscmConfiguration", :api_version => "v2"
    tfsscm_configuration.rest_tfsscm_configurations_show 'api/v2/projects/:project_id/tfsscm_configurations/:id.xml', :action => 'show', :conditions => {:method => :get}, :format => 'xml', :repository_type => "TfsscmConfiguration", :api_version => "v2"
    tfsscm_configuration.rest_tfsscm_configurations_create_or_update 'api/v2/projects/:project_id/tfsscm_configurations.xml', :action => 'save', :conditions => {:method => [:put, :post]}, :format => 'xml', :repository_type => "TfsscmConfiguration", :api_version => "v2"
    tfsscm_configuration.rest_tfsscm_configurations_update 'api/v2/projects/:project_id/tfsscm_configurations/:id.xml', :action => 'save', :conditions => {:method => :put}, :format => 'xml', :repository_type => "TfsscmConfiguration", :api_version => "v2"
    tfsscm_configuration.map 'projects/:project_id/tfsscm_configurations.xml', :action => 'unsupported_api_call'
    tfsscm_configuration.map 'projects/:project_id/tfsscm_configurations/:id.xml', :action => 'unsupported_api_call'
  end

end
