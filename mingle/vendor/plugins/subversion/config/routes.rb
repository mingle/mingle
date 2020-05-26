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

ActionController::Routing::Routes.draw do |map|
  map.with_options :controller => 'repository' do |subversion_configuration|
    subversion_configuration.subversion_configurations_show 'projects/:project_id/subversion_configurations', :action => 'index', :conditions => {:method => :get}, :repository_type => "SubversionConfiguration"
    
    subversion_configuration.rest_subversion_configurations_index 'api/:api_version/projects/:project_id/subversion_configurations.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml', :repository_type => "SubversionConfiguration"
    subversion_configuration.rest_subversion_configurations_show 'api/:api_version/projects/:project_id/subversion_configurations.xml', :action => 'show', :conditions => {:method => :get}, :format => 'xml', :repository_type => "SubversionConfiguration"
    subversion_configuration.rest_subversion_configurations_create_or_update 'api/:api_version/projects/:project_id/subversion_configurations.xml', :action => 'save', :conditions => {:method => [:put, :post]}, :format => 'xml', :repository_type => "SubversionConfiguration"
    subversion_configuration.rest_subversion_configurations_update 'api/:api_version/projects/:project_id/subversion_configurations/:id.xml', :action => 'save', :conditions => {:method => :put}, :format => 'xml', :repository_type => "SubversionConfiguration"
    subversion_configuration.map 'projects/:project_id/subversion_configurations.xml', :action => 'unsupported_api_call'
    subversion_configuration.map 'projects/:project_id/subversion_configurations/:id.xml', :action => 'unsupported_api_call'
  end
end
