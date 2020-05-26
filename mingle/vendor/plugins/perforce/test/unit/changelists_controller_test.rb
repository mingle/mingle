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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ChangelistsControllerTest < ActionController::TestCase
  
  def setup
    @controller = create_controller ChangelistsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @project = create_project
    @p4_opts = {:username => "ice_user", :host=> "localhost", :port=> "1666", :repository_path =>"//depot/..."}
    init_p4_driver_and_repos
  end
  
  def test_displays_helpful_message_when_revision_not_found
    login_as_admin
    PerforceConfiguration.create({:project => @project}.merge(@p4_opts.merge(:repository_path => "//depot")))
    get :show, :project_id => @project.identifier, :rev => 1
    assert_template 'revisions/show'
  end
  
end
