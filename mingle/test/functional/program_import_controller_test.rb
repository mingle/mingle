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

class ProgramImportControllerTest < ActionController::TestCase

  def setup
    @user = login_as_admin
    @program = program('simple_program')
  end

  def test_can_import_plan
    export_file = create_program_exporter!(@program, @user).process!
    post :import, :import => ActionController::TestUploadedFile.new(export_file, "application/zip")

    asynch_request = @user.asynch_requests.last
    assert_redirected_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
  end

  def test_shows_error_message_on_invalid_import_file
    tmp_file = Tempfile.new(["test_export",".program"])
    post :import, :import => ActionController::TestUploadedFile.new(tmp_file.path, "application/zip")
    assert_tag :div, :content => ProgramImportController::ERROR_MSGS[:unzip_failure]
  ensure
    tmp_file.delete
  end

  def test_validates_file_extension
    export_file = create_project_exporter!(first_project, @user).process!
    post :import, :import => ActionController::TestUploadedFile.new(export_file, "application/zip")
    follow_redirect
    assert_tag :div, :content => ProgramImportController::ERROR_MSGS[:bad_extension]
  end

  def test_validates_file_specified
    post :import, :import => nil
    follow_redirect
    assert_tag :div, :content => ProgramImportController::ERROR_MSGS[:missing]
  end

  def test_on_cancel_goes_to_root_context
    get :new
    assert_tag :a, :content => 'Cancel', :attributes => {:href => "/programs"}
  end

  def test_validates_file_size_uploaded
    MingleConfiguration.with_asynch_request_tmp_file_size_limit_overridden_to("0") do
      export_file = create_program_exporter!(@program, @user).process!
      post :import, :import => ActionController::TestUploadedFile.new(export_file, "application/zip")

      assert_tag :div, :content => "File cannot be larger than 0MB."
    end
  end

  def test_should_not_allow_to_import_program_if_import_program_is_disabled
    MingleConfiguration.with_disable_import_program_overridden_to('true') do
      get :new
      assert flash[:info]
      assert_equal 'Importing a program has been temporarily disabled. Please try again later.', flash.now[:info]
    end
  end
end
