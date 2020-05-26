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
require 'cards_import_controller'

# Tags: messaging
class CardsImportControllerMessagingTest < ActionController::TestCase 
  include TreeFixtures::PlanningTree, MessagingTestHelper
  
  def setup
    @controller = create_controller CardsImportController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = User.find_by_login('member')
    @project = create_project :prefix => 'cards_imp_func', :users => [@member]
    @request.env['HTTP_USER_AGENT'] = "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 2.0.50727)"
    AsynchRequest.delete_all
    login_as_member

    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @raw_excel_content_file_path = @excel_content_file.pathname
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_should_show_when_process_has_error
    setup_property_definitions :status => ['new', 'open']

    status = @project.find_property_definition('status')
    status.update_attribute(:restricted, true)

    import_text = %{Number\tName\tStatus
      1\tNew Funky Name for Card One\topen
      781\tCard Seven Eighty-One\tillegal
      782\tCard Seven Eighty-Two\tnew
      900\tNow Card 900\topen
    }
    write_content(import_text)
    preview_request = File.open(@raw_excel_content_file_path) do |f|
      User.current.asynch_requests.create_card_import_preview_asynch_request(@project.identifier, f)
    end

    post :accept, :project_id => @project.identifier, :tab_separated_import_preview_id => preview_request.id

    assert_render_asynch_request_progress_in_lightbox

    CardImportProcessor.run_once

    asynch_request = @member.asynch_requests.find(:all, :order => 'id').last
    assert asynch_request

    assert_equal "Importing complete, 4 rows, 0 updated, 3 created, 1 error.<br/><br/>Error detail:<br/><br/>Row 2: Validation failed: <b>status</b> is restricted to <b>new</b> and <b>open</b>", MingleFormatting.replace_mingle_formatting(asynch_request.progress_msg.strip)
  end

  def test_should_show_warning_messages_and_ignore_the_colnumn_when_the_property_is_transition_only
    @project = create_project :prefix => 'import_card', :users => [User.find_by_login('member')]
    @project.activate
    setup_property_definitions(:Browser => ['firefox'], :Platform => %w{ unix windows})
    @project.find_property_definition('Browser').update_attribute(:transition_only, true)    
    @project.find_property_definition('Platform').update_attribute(:transition_only, true)
    @project.reload
    login_as_member
    
    write_content(%{
       Number\tName\tBrowser\tPlatform\ttype
        3\tThis should be a name\tstory\tunix\tCard
    })
    preview  = create_card_import_preview!(@project, @raw_excel_content_file_path)
    
    CardImportPreviewProcessor.run_once
    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    
    assert_response :success

    assert_warning "Property <b>Browser</b> is transition only and will be ignored when updating cards. When creating new cards, these values will be set.<br />Property <b>Platform</b> is transition only and will be ignored when updating cards. When creating new cards, these values will be set."
    assert_select "select#browser_import_as>option:first-child", :text => "(ignore)"
    assert_select "select#browser_import_as>option", :count => 2
  end

  # bug 3054
  def test_should_show_correct_date_when_preview_cards_with_date_property_definition
    setup_date_property_definition('start on')
    card1 = create_card!(:name => 'card1', 'start on' => '20 Mar 2008')
    card2 = create_card!(:name => 'card2', 'start on' => '20 Mar 2008')
    import_text = %{Number\tName\tstart on
    #{card1.number}\tcard1\t20 Mar 2008
    #{card2.number}\tcard2\t20 Mar 2008
    }
    write_content(import_text)
    preview  = create_card_import_preview!(@project, @raw_excel_content_file_path)
    CardImportPreviewProcessor.run_once

    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    assert_select "td", :text => 'Error: 20 Mar 2008', :count => 0
    assert_select "td", :text => '20 Mar 2008', :count => 2
  end
  
  # bug 3660
  def test_should_have_a_dropdown_for_tree_column_when_tree_column_is_provided_but_not_all_relationship_columns_are
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      login_as_admin
      write_content(%{
        Number\tName\tDescription\tType\t#{configuration.name}\tPlanning release
        1560\tadd\t\tstory\t\tyes\t
      })
      preview = create_card_import_preview!(project, @raw_excel_content_file_path)
      
      CardImportPreviewProcessor.run_once
      post :display_preview, :project_id => project.identifier, :id => preview.progress.id
      assert_warning /#{"Properties for tree 'Planning' will not be imported because column 'Planning iteration' was not included in the pasted data.".gsub(/'/, '&#39;')}/
      assert_select "select#planning_import_as" do
        assert_select "option", :count => 1   # cheap way of making sure the ignore option is selected
        assert_select "option[value=ignore]"
      end
    end
  end

  def test_overriding_default_mappings
    login_as_admin
    import_text = %{Number\tTitle\tStatus
      1\tNew Funky Name for Card One\tclosed
      781\tCard Seven Eighty-One\tillegal
      782\tCard Seven Eighty-Two\tnew
      900\tNow Card 900\topen
    }
    write_content(import_text)
    preview_request = File.open(@raw_excel_content_file_path) do |f|
      User.current.asynch_requests.create_card_import_preview_asynch_request(@project.identifier, f)
    end

    post :accept, :project_id => @project.identifier, :tab_separated_import_preview_id => preview_request.id, :mapping => {'2' => 'name', '1' => CardImport::Mappings::TEXT_LIST_PROPERTY, '0' => 'number'}
    assert_render_asynch_request_progress_in_lightbox

    CardImportProcessor.run_once
    assert_equal 'new', @project.cards.find_by_number(782).name
    assert_equal 'Now Card 900', @project.cards.find_by_number(900).cp_title
  end

  def test_existing_numeric_property_should_only_be_imported_as_such
    setup_numeric_property_definition 'size', ['2', '4', '8']
    write_content(%{
      Name\tSize
      Fooo\t4
    })
    preview  = create_card_import_preview!(@project, @raw_excel_content_file_path)
    
    CardImportPreviewProcessor.run_once
    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    assert_response :success

    assert_tag :tag => 'select', 
               :attributes => {:id => 'size_import_as'}, 
               :child => {:tag => 'option', :attributes => {:selected => 'selected', :value => CardImport::Mappings::NUMERIC_LIST_PROPERTY}}
  end
  

  def test_should_allow_existing_user_properties_to_only_be_imported_as_such
    @project.with_active_project do |project|
      setup_user_definition 'Developer'
    end
    login_as_admin
    setup_numeric_property_definition 'size', ['2', '4', '8']
    write_content(%{
      Name\tStatus\tDeveloper
      Fooo\tOpen\tbob@email.com
    })
    preview  = create_card_import_preview!(@project, @raw_excel_content_file_path)

    CardImportPreviewProcessor.run_once
    post :display_preview, :project_id => @project.identifier, :id => preview.progress.id
    assert_response :success

    assert_tag :tag => 'select',
               :attributes => {:id => 'developer_import_as'},
               :child => {:tag => 'option', :attributes => {:selected => 'selected'}}
  end

  def test_select_mapping_overrides_in_the_same_manner_as_shown_in_the_preview_ui_bug_2025
    login_as_admin
    write_content <<-IMPORT
Number\tRelease\tComponent\tSub-Component\tProduct Type (for Store Stories)\tSprint (Jira Version)\tProposed Sprint\tJira ID\tPriority\tStory Title\tIntegration Point (true, false, blank)
1\tDay 2\tCart\tAddress Verify\t\t\t\tECBO-82\t5\tWhen filling in an address , Jennifer fills in incorrect data and sees an error message when she submits the information
2\tDay 1\tCart\tAddress Verify\t\t\t\t\t5\tJennifer enters an incorrect zip code while entering  the shipping or billing  address and sees an  error message that zip code does not match to state
IMPORT

    preview_request = File.open(@raw_excel_content_file_path) do |f|
      User.current.asynch_requests.create_card_import_preview_asynch_request(@project.identifier, f)
    end
    post :accept, :project_id => @project.identifier, :mapping => {"0" => 'number',
                               "1" => CardImport::Mappings::TEXT_LIST_PROPERTY,
                               '2' => CardImport::Mappings::ANY_TEXT_PROPERTY,
                               '3' => 'description',
                               '4' => CardImport::Mappings::TEXT_LIST_PROPERTY,
                               '5' => CardImport::Mappings::ANY_TEXT_PROPERTY,
                               '6' => CardImport::Mappings::ANY_TEXT_PROPERTY,
                               '7' => CardImport::Mappings::ANY_TEXT_PROPERTY,
                               '8' => CardImport::Mappings::TEXT_LIST_PROPERTY,
                               '9' => 'description',
                               '10' => CardImport::Mappings::TEXT_LIST_PROPERTY},
                  :tab_separated_import_preview_id => preview_request.id

    assert_render_asynch_request_progress_in_lightbox

    CardImportProcessor.run_once
    @project.reload.with_active_project do |project|
      assert @project.text_property_definitions_with_hidden.collect(&:name).include?('Component')
      card1 = project.cards.find_by_number('1')
      assert_equal('Cart', card1.cp_component)
    end
  end

  def test_should_publish_an_asynch_request_message_when_preview_is_requested
    post :preview, :project_id => @project.identifier, :tab_separated_import => %{
      Number
      1
    }
    assert_response :success

    assert_equal 1, all_messages_from_queue(CardImportPreviewProcessor::QUEUE).size
  end

  def test_should_authorize_user_privilege_when_accept_importing_cards
    write_content(%{
        Number\tName\told_type
        3\tThis should be a name\tstory
    })
    preview_request = File.open(@raw_excel_content_file_path) do |f|
      User.current.asynch_requests.create_card_import_preview_asynch_request(@project.identifier, f)
    end

    post :accept, :project_id => @project.identifier, :tab_separated_import_preview_id => preview_request.id

    assert_render_asynch_request_progress_in_lightbox
    CardImportProcessor.run_once

    asynch_request = @member.asynch_requests.find(:all, :order => 'id').last

    assert asynch_request.failed?
    assert_equal "Importing complete, 0 rows, 0 updated, 0 created, 1 error.<br/><br/>Error detail:<br/><br/>Error creating custom property <b>old_type</b>. You must be a project administrator to create custom properties.", MingleFormatting.replace_mingle_formatting(asynch_request.progress_msg.strip)

    assert @project.reload.property_definitions.empty?
  end

  protected

  def assert_render_asynch_request_progress_in_lightbox(title='Importing')
    assert @response.body.include?('lightbox')
    assert @response.body.include?(title)
    assert @response.body.include?("asynch_requests/progress/#{User.current.asynch_requests.find(:all, :order => 'id').last.id}")
  end

  def write_content(content)
    @excel_content_file.write(content)
  end

end
