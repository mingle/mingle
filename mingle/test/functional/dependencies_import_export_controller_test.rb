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

class DependenciesImportExportControllerTest < ActionController::TestCase

  def setup
    @user = login_as_admin
  end

  def test_validates_import_file_extension
    with_temp_file do |tmp_file|
      post :import_preview, :import => ActionController::TestUploadedFile.new(tmp_file.path, "application/zip")
      follow_redirect
      assert_tag :div, :content => DependenciesImportExportController::ERROR_MSGS[:bad_extension]
    end
  end

  def test_validates_import_file_is_specified
    post :import_preview, :import => nil
    follow_redirect
    assert_tag :div, :content => DependenciesImportExportController::ERROR_MSGS[:missing]
  end

  def test_import_preview_asynch_request_is_required
    get :preview_errors
    assert_response :unprocessable_entity

    post :preview
    assert_response :unprocessable_entity

    export_request = DependenciesExportPublisher.new([first_project], @user).asynch_request
    post :confirm_import, :id => export_request.id
    assert_response :unprocessable_entity
  end

  def test_flash_message_is_visible_if_error_views_are_not_present
    with_temp_file do |tmp_file|
      asynch_request = @user.asynch_requests.create_dependencies_import_preview_asynch_request(Time.now.strftime("%Y-%m-%d"), tmp_file)
      asynch_request.add_error("Unknown error")
      get :index, {:id => asynch_request.id}, nil, {:error => "Unknown error"}
      assert_include "Unknown error", @response.body
    end
  end

  def test_error_view_is_displayed_if_set_on_asynch_request
    with_temp_file do |tmp_file|
      asynch_request = @user.asynch_requests.create_dependencies_import_preview_asynch_request(Time.now.strftime("%Y-%m-%d"), tmp_file)
      asynch_request.add_error("Unknown error")
      asynch_request.add_error_view("invalid_import_file")
      asynch_request.save
      get :index, {:id => asynch_request.id}, nil, {:error => "Unknown error"}
      assert_include "The import file uploaded is invalid", @response.body
      assert_not_include "Unknown error", @response.body
    end
  end

  def test_preview_errors_redirects_to_preview_if_no_errors_present
    with_temp_file do |tmp_file|
      asynch_request = @user.asynch_requests.create_dependencies_import_preview_asynch_request(Time.now.strftime("%Y-%m-%d"), tmp_file)

      get :preview_errors, {:id => asynch_request.id}
      assert_response :redirect
      assert_redirected_to :action => "preview"
    end
  end

  def test_preview_updates_current_dependency_errros_with_raising_card_numbers
    with_temp_file do |tmp_file|
      asynch_request = @user.asynch_requests.create_dependencies_import_preview_asynch_request(Time.now.strftime("%Y-%m-%d"), tmp_file)
      asynch_request.add_dependencies_error(create_dependency_error("dep1", "1"))
      asynch_request.add_dependencies_error(create_dependency_error("dep2", "2"))
      asynch_request.add_dependencies_error(create_dependency_error("dep3", "3"))
      asynch_request.save!

      post :preview, {:id => asynch_request.id, :dependencies => {:'1' => {:raising_card_number => '12', :raising_card_name => 'raise1'},
                                                                  :'2' => {:raising_card_number => '22', :raising_card_name => 'raise2'},
                                                                  :'3' => {:raising_card_number => "", :raising_card_name => ""}}}

      dep_errors = asynch_request.reload.dependencies_errors.sort do |a, b|
        a["name"] <=> b["name"]
      end
      assert_not_nil dep_errors.first["raising_card"]
      assert_equal 12, dep_errors.first["raising_card"]["number"].to_i
      assert_equal 'raise1', dep_errors.first["raising_card"]["name"]

      assert_not_nil dep_errors.second["raising_card"]
      assert_equal 22, dep_errors.second["raising_card"]["number"].to_i
      assert_equal 'raise2', dep_errors.second["raising_card"]["name"]

      assert_nil dep_errors.last["raising_card"]
    end
  end

  def create_dependency_error(name, number)
    project = first_project
    project_hash = {"name" => first_project.name, "identifier" => first_project.identifier}
    {"name" => name, "number" => number, "raising_project" => project_hash, "resolving_project" => project_hash, "raising_card" => nil, "resolving_cards" => []}
  end
end
