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

require File.expand_path("../unit_test_helper", File.dirname(__FILE__))

class LegacyAttachmentsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller LegacyAttachmentsController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
    @project = first_project
    @attachment = @project.attachments.create(:file => sample_attachment('sample.txt'))
  end

  def test_show_attachment_should_fail_authorization_check_for_non_project_member
    longbob = login_as_longbob
    assert_false @project.member?(longbob)
    assert_raises(ErrorHandler::UserAccessAuthorizationError) { get :show, :id => @attachment.id}
  end

  def test_show_should_deliver_contents_to_anonymous_user_for_anonymously_accessible_project
    set_anonymous_access_for(@project, true)
    logout_as_nil
    change_license_to_allow_anonymous_access

    get :show, :id => @attachment.id

    assert_response :ok
    output = Writer.new
    @response.body.call(nil, output)
    assert_equal 'This is a sample attachment.', output.content.strip
  end

  def test_show_attachment_should_redirect_to_login_for_anonymous_user
    logout_as_nil
    get :show, :id => @attachment.id
    assert_response :redirect
    assert_redirected_to :controller => 'profile', :action => 'login'
  end

  def test_show_attachment_should_deliver_the_contents_with_no_cache_header
    get :show, :id => @attachment.id
    assert_response :ok
    assert_equal "no-cache", @response.headers['Cache-Control']
  end

  def test_show_attachment_should_deliver_the_content_for_a_project_member
    get :show, :id => @attachment.id
    assert_response :ok
    output = Writer.new
    @response.body.call(nil, output)
    assert_equal 'This is a sample attachment.', output.content.strip
  end

end

class Writer
  attr_reader :content
  def write(to_write)
    @content ||= ''
    @content << to_write
  end
end
