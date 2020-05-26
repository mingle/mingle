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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')
require 'project_exports_controller'

class ProjectExportsControllerMessagingTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @controller = create_controller ProjectExportsController, :own_rescue_action => false
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    route(:from => ProjectExportProcessor::QUEUE, :to => TEST_QUEUE)
  end
  
  def test_should_show_inprogress_info_after_created
    login_as_member
    with_first_project do |project|
      post :create, :project_id => project.identifier, :export_as_template => true
      assert_response :success
      messages = get_all_messages_in_queue
      assert_equal 1, messages.size
      assert_not_nil messages.first[:request_id]
    end
  end

end
