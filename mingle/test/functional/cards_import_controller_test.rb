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

class CardsImportControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree
  include MetricsHelper

  def setup
    @controller = create_controller CardsImportController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = User.find_by_login('member')
    @project = create_project :prefix => 'cards_imp_func', :users => [@member]
    @request.env['HTTP_USER_AGENT'] = "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 2.0.50727)"
    login_as_member
    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @raw_excel_content_file_path = @excel_content_file.pathname
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
    logout_as_nil
  end

  def test_preview_with_asynch_request
    post :preview, :project_id => @project.identifier, :tab_separated_import => %{
      Number
      1
    }
    assert_render_asynch_request_progress_in_lightbox("Preparing")
  end

  def test_should_not_provide_error_and_warning_messages_at_the_same_time
    import_text = %{
      Number
      1.456
    }
    write_content(import_text)
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)

    preview.process!
    @controller.instance_eval do
      def card_context
        @context ||= CardContext.new(@project, {})
      end
    end
    @controller.card_context.store_tab_state(DisplayTabs::AllTab.all_cards_card_list_view_for(@project), 'All', CardContext::NO_TREE)

    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id

    assert_response :success

    assert_template "import"
    assert_error "Cards were not imported. #{'1.456'.html_bold} is not a valid card number."
    assert_no_notice "Some cards being imported do not have a card name. "
  end

  def test_card_list_view_params_get_reserved_through_preview_import
    setup_property_definitions :iteration => []
    post :accept, :project_id => @project.identifier, :columns => 'iteration'

    assert @response.body.include?('lightbox')
    assert @response.body.include?('Importing')
    assert @response.body.include?('asynch_requests/progress')
    assert @response.body.include?('columns=iteration')
  end

  def test_should_not_offer_the_option_to_import_as_user_property_if_no_user_property_exists
    login_as_admin
    post :preview, :project_id => @project.identifier, :tab_separated_import => %{
      Name\tStatus\tDeveloper
      Fooo\tOpen\tbob@email.com
    }
    assert_no_tag :tag => 'select', :attributes => {:id => 'status_import_as', :child => {
        :tag => 'option',
        :content => 'as user property',
        :attributes => {:value => 'user property', :selected => 'selected'}}}
  end

  def test_should_redirect_to_asynch_requests_progress_page_when_display_preview_and_its_not_completed
    write_content %{
      Name
      Fooo
    }
    preview  = create_card_import_preview!(@project, @raw_excel_content_file_path)

    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    assert @response.body.include?("redirected")
    assert @response.body.include?("asynch_requests/progress/#{preview.progress.id}")
  end

  # bug 3425
  def test_preview_ignore_checkboxes_should_begin_at_index_1
    import_text = %{Number\tName
    3\tThis should be a name
    4\tHello there
    }
    write_content(import_text)

    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)
    preview.process!

    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    assert_response :success

    assert_select "input[name='ignore[0]']", false
    assert_select "input[name='ignore[1]']", true
    assert_select "input[name='ignore[2]']", true
  end

  def test_card_import_take_preview_asynch_request_id_as_input
    imported_card = %{
        Number\tName
        3\tThis should be a name
    }
    write_content imported_card
    preview = create_card_import_preview!(@project, @raw_excel_content_file_path)

    post :accept, :project_id => @project.identifier, :tab_separated_import_preview_id => preview.progress.id

    asynch_request = @member.asynch_requests.find(:all, :order => 'id').last
    assert_equal preview.progress.id, asynch_request.message[:tab_separated_import_preview_id].to_i
  end

  def test_accept_should_send_out_cards_import_event
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      imported_card = %{
        Number\tName
        3\tThis should be a name
    }
      write_content imported_card
      preview = create_card_import_preview!(@project, @raw_excel_content_file_path)

      post :accept, :project_id => @project.identifier, :tab_separated_import_preview_id => preview.progress.id
      assert @controller.events_tracker.sent_event?("import_cards")
    end
  end

  def test_card_import_preview_saves_import_in_tmp_file
    imported_card = %{
        Number\tName
        3\tThis should be a name
    }

    post :preview, :project_id => @project.identifier, :tab_separated_import => imported_card

    asynch_request = @member.asynch_requests.find(:all, :order => 'id').last
    assert_equal imported_card, File.read(asynch_request.tmp_file)
  end

  protected

  def assert_render_asynch_request_progress_in_lightbox(title='Importing')
    assert @response.body.include?('lightbox')
    assert @response.body.include?(title)
    assert @response.body.include?("asynch_requests/progress/#{User.current.asynch_request_ids.max}")
  end

  def render_to_string(*args)
    return args[0][:inline]
  end

  def write_content(content)
    @excel_content_file.write(content)
  end

end
