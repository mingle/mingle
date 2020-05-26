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

class AsynchRequestsControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller(AsynchRequestsController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = User.find_by_login('member')
    @project = create_project :prefix => 'asynch_requests_func', :users => [@member]
    @request.env['HTTP_USER_AGENT'] = "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 2.0.50727)"
    login_as_member

    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @raw_excel_content_file_path = @excel_content_file.pathname
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_card_list_view_params_get_preserved_through_progress
    setup_property_definitions :iteration => []
    tab_separated_import = %{
        Number\tName
        3\tThis should be a name
    }
    write_content(tab_separated_import)

    import = create_card_importer!(@project, @raw_excel_content_file_path, nil, [], nil, @member)
    xhr :get, :progress, :project_id => @project.identifier, :id => import.progress.id, :columns => 'iteration'

    assert @response.body.include?("progress/#{import.progress.id}?columns=iteration")

    import.process!
    xhr :get, :progress, :project_id => @project.identifier, :id => import.progress.id, :columns => 'iteration'
    assert_rjs :redirect_to, :controller => 'cards', :action => 'list', :columns => 'iteration', :style => 'list', :tab => DisplayTabs::AllTab::NAME, :escape => false
  end

  def test_open_progress
    import_text = %{name
      card name
    }
    write_content(import_text)

    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    get :open_progress, :project_id => @project.identifier, :id => preview.progress.id

    assert @response.body.include?('lightbox')
    assert @response.body.include?("asynch_requests/progress/#{preview.progress.id}")
    assert @response.body.include?("Preparing preview")

    preview.process!
    get :open_progress, :project_id => @project.identifier, :id => preview.progress.id
    assert @response.body.include?("Preparing preview completed.")
  end

  # bug 9070
  def test_should_redirect_to_success_url_on_completion_of_project_import
    asynch_request = @member.asynch_requests.create_project_import_asynch_request('some_project_identifier', nil)
    asynch_request.total = 100
    asynch_request.completed = 100
    asynch_request.mark_completed_successfully
    asynch_request.save!
    assert asynch_request.completed?

    xhr :get, :progress, :project_id => @project.identifier, :id => asynch_request.id
    assert_match /window\.location\.href\s=\s"\/projects\/some_project_identifier"/, @response.body
  end

  def test_deliverable_should_look_up_by_type
    create_program @project.identifier

    setup_property_definitions :iteration => []
    tab_separated_import = %{
        Number\tName
        3\tThis should be a name
    }
    write_content(tab_separated_import)

    import = create_card_importer!(@project, @raw_excel_content_file_path, nil, [], nil, @member)

    import.process!
    xhr :get, :progress, :project_id => @project.identifier, :id => import.progress.id, :columns => 'iteration'
    assert_response :success
  end
  private

  def write_content(content)
    @excel_content_file.write(content)
  end

end
