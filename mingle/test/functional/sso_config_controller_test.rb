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

class SsoConfigControllerTest < ActionController::TestCase

  def setup
    MingleConfiguration.app_namespace = "parsley"
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)

    @controller = create_controller(SsoConfigController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_admin
    MingleConfiguration.sso_config = 'true'
  end

  def teardown
    MingleConfiguration.sso_config = nil
    MingleConfiguration.app_namespace = nil
    ProfileServer.reset
  end

  def test_update_saml_metadata
    metadata_file = File.join(Rails.root, "test/data/saml_metadata.xml")
    post :update, :saml_metadata => ActionController::TestUploadedFile.new(metadata_file, "application/xml")
    assert_redirected_to :action => :show

    assert_equal 1, sso_config_requests.size
    req = sso_config_requests.last

    assert_equal :put, req.http_method
    data = JSON.parse(req.body)
    assert_equal File.read(metadata_file), data['organization']['saml_metadata']
  end

  def test_should_handle_invalid_saml_metadata_files
    metadata_file = File.join(Rails.root, "test/data/lion.jpg")
    post :update, :saml_metadata => ActionController::TestUploadedFile.new(metadata_file, "application/xml")
    assert_redirected_to :action => :show
  end

  def test_remove_saml_metadata_config
    metadata_file = File.join(Rails.root, "test/data/saml_metadata.xml")
    post :update, :saml_metadata => nil
    assert_redirected_to :action => :show

    assert_equal 1, sso_config_requests.size
    req = sso_config_requests.last
    assert_equal :put, req.http_method
    data = JSON.parse(req.body)
    assert_equal nil, data['organization']['saml_metadata']
  end

  def test_should_not_allow_upload_large_metadata_file
    @http_stub.register_get_response("https://profile_server/organizations/parsley/sso_config.json", [200, "saml metadata"])

    # mingle_1_1_export_project.mingle: 150K
    metadata_file = File.join(Rails.root, "test/data/mingle_1_1_export_project.mingle")
    post :update, :saml_metadata => ActionController::TestUploadedFile.new(metadata_file, "application/xml")
    assert_template 'edit'
    assert_equal "SAML metadata file is too big", flash.now[:error]
  end

  def test_response_404_if_sso_config_toggle_is_off
    MingleConfiguration.with_sso_config_overridden_to('false') do
      get :show
      assert_response :not_found
    end
  end

  def sso_config_requests
    @http_stub.requests.select{|r| r.url =~ /sso_config/}
  end
end
