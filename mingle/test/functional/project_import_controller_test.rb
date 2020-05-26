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

class ProjectImportControllerTest < ActionController::TestCase
  include MetricsHelper
  def setup
    @controller = create_controller ProjectImportController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @admin = User.find_by_login('admin')

  end

  def teardown
    Clock.reset_fake
    Project.current.deactivate
  rescue
  end

  def test_can_import_project
    project = create_project
    create_card! :name => 'card 1'
    export_file = create_project_exporter!(project, @admin).export
    post :import,
      :import => ActionController::TestUploadedFile.new(export_file, "application/zip"),
      :project => {:name => "", :identifier => ""}

    asynch_request = @admin.asynch_requests.last
    assert_redirected_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
  end

  def test_import_should_send_out_import_project_event
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      session[:s3_import_key] = 's3key'
      get :import_from_s3, :project => {}
      assert @controller.events_tracker.sent_event?('import_project')
    end
  end

  def test_should_show_error_message_when_import_data_is_string_type
    project = create_project
    export_file = create_project_exporter!(project, @admin).export
    export_file_content = File.open(export_file, 'r:iso-8859-1') do |io|
      io.read
    end
    post :import,
      :import => export_file_content,
      :project => {:name => nil, :identifier => nil}
    assert_redirected_to :action => 'index'
    assert flash[:not_found]
  end

  def test_import_project_with_new_name_and_identifier #dubious test - it used to assert that the redirect contained new project identifier?
    project = create_project
    export_file = create_project_exporter!(project, @admin).export
    new_identifier = unique_name('project')
    post :import,
      :project_id => project.identifier,
      :import => ActionController::TestUploadedFile.new(export_file, "application/zip"),
      :project => {:name => 'new name', :identifier => new_identifier}

    asynch_request = @admin.asynch_requests.last
    assert_redirected_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
  end

  def test_should_display_errors_when_there_is_validation_error_on_new_identifier_during_importing
    project = create_project
    export_file = create_project_exporter!(project, @admin).export
    new_identifier = unique_name('project')
    post :import,
      :project_id => project.identifier,
      :import => ActionController::TestUploadedFile.new(export_file, "application/zip"),
      :project => {:name => 'new name', :identifier => '1'}

    assert_response :success
    assert_template 'index'
    assert @response.body.include?('Identifier may not start with a digit')
  end

  def test_should_give_an_error_message_on_blank_import
    project = create_project
    export_file = create_project_exporter!(project, @admin).export
    post :import, :project_id => project.identifier, :import => nil
    assert_redirected_to :action => 'index'
    assert flash[:not_found]
  end

  # test for #1084
  def test_should_import_project_only_for_mingle_admin
    rescue_action_in_public!
    project = create_project
    project.deactivate
    logout_as_nil
    login_as_member
    get :import
    assert_redirected_to projects_url

    export_file = create_project_exporter!(project, @admin).export
    post :import,
         :import => ActionController::TestUploadedFile.new(export_file, "application/zip")
    assert_redirected_to projects_url
  end

  def test_should_render_s3_upload_form_for_saas_configuration
    ENV['AWS_SECRET_ACCESS_KEY'] = "My secret key"
    ENV['AWS_ACCESS_KEY_ID'] = "My access key"

    get :index
    assert_select 'input[id="key"]', :count => 0

    MingleConfiguration.with_import_files_bucket_name_overridden_to("import_files_bucket") do
      MingleConfiguration.with_app_namespace_overridden_to('ns') do
        get :index
        assert_select 'input[id="key"]' do
          assert_select '[value=?]', /ns\/.+/
        end
      end
    end
  ensure
    ENV['AWS_SECRET_ACCESS_KEY'] = nil
    ENV['AWS_ACCESS_KEY_ID'] = nil
  end

  def test_should_generate_signature_and_encrypted_policy_document_for_s3_upload
    ENV['AWS_SECRET_ACCESS_KEY'] = "My secret key"
    ENV['AWS_ACCESS_KEY_ID'] = "My access key"

    MingleConfiguration.with_import_files_bucket_name_overridden_to("import_files_bucket") do
      MingleConfiguration.with_app_namespace_overridden_to('ns') do
        get :index
        assert_select 'input[id="policy"]' do
          assert_select '[value=?]', /.+/
        end
      end
    end
  ensure
    ENV['AWS_SECRET_ACCESS_KEY'] = nil
    ENV['AWS_ACCESS_KEY_ID'] = nil
  end

  def test_should_display_validation_errors_if_any_after_s3_upload
    session[:s3_import_key] = 's3key'
    get :import_from_s3,
    :project => {:name => 'new project', :identifier => '999'}

    assert_response :success
    assert @response.body.include? "Identifier may not start with a digit"
  end

  def test_should_redirect_to_asynch_request_controller_after_s3_upload
    session[:s3_import_key] = 's3key'
    get :import_from_s3,
    :project => {:name => 'new project', :identifier => 'new_project'}
    assert_redirected_to :controller => 'asynch_requests', :action => 'progress'
  end

  def test_should_succeed_if_project_info_is_blank
    session[:s3_import_key] = 's3key'
    get :import_from_s3,
    :project => {:name => '', :identifier => ''}

    assert_redirected_to :controller => 'asynch_requests', :action => 'progress'
  end

  def test_should_strip_whitespaces_and_underscores
    session[:s3_import_key] = 's3key'
    get :import_from_s3,
    :project => {:name => '  my project  ', :identifier => '__my_project__'}

    assert_redirected_to :controller => 'asynch_requests', :action => 'progress'
    message = AsynchRequest.find(@response.redirected_to[:id].to_i).message

    assert_equal "my project", message[:project_name]
    assert_equal "my_project", message[:project_identifier]
  end

  def test_should_validate_project_info_for_s3_upload
    session[:s3_import_key] = 's3key'
    get :import_from_s3,
    :project => {:name => 'Invalid identifier', :identifier => '0_0'}
    assert_response :success
    assert flash[:error].include?("Identifier may not start with a digit")
  end

  def test_should_validate_s3_key_exists_in_session
    get :import_from_s3, :project => {:name => '', :identifier => ''}
    assert_response :success
    assert flash[:error].include?("Could not find the file uploaded, please try again")
  end

end
