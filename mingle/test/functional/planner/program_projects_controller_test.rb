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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class ProgramProjectsControllerTest < ActionController::TestCase
  def setup
    @controller = ProgramProjectsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_add_project_into_plan
    project = Project.find_by_identifier('sp_unassigned_project')
    post :create, :program_id => @program.to_param, :new_program_project => {:id => project.identifier}
    assert_redirected_to :action => 'index'
    assert_equal 3, @program.projects.size
  end

  # bug #11531 [Planner] Clicking add projects button in a fairly quick speed will result in adding same project twice
  def test_create_should_not_add_same_project_twice
    project = Project.find_by_identifier('sp_unassigned_project')
    post :create, :program_id => @program.to_param, :new_program_project => {:id => project.identifier}
    post :create, :program_id => @program.to_param, :new_program_project => {:id => project.identifier}
    get :index, :program_id => @program.to_param
    assert_select '#program_projects_container tr td', :text => project.name, :count => 1
  end

  def test_list_all_program_projects
    get :index, :program_id => @program.to_param
    assert_response :success
    assert_select "#program_projects_container .done_mapping_row .project_link", :count => 2
  end

  def test_index_should_make_projects_tab_selected
    get :index, :program_id => @program.to_param

    assert_select "li.selected a", :text => "Projects"
    assert_select "li.selected a", :text => "Timeline", :count => 0
  end

  def test_should_not_list_add_project_form_when_no_assignable_projects
    @program.projects = Project.all_available
    get :index, :program_id => @program.to_param
    assert_response :success
    assert_select "#add_project_to_program_form", :count => 0
  end

  def test_should_set_status_mapping
    with_first_project do |project|
      @program.projects << project
      property_to_map = project.find_property_definition("Material")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'wood'}
      post :update, :program_id => @program.to_param, :id => project.identifier, :program_project => {:status_property_name => property_to_map.name, :done_status => enumeration_value_to_map.value }, :back_to_url => 'someplace'

      project.reload
      assert_equal property_to_map, @program.status_property_of(project)
      assert_equal enumeration_value_to_map, @program.done_status_of(project)
    end
  end

  def test_should_redirect_to_back_url_when_done_Status_updated
    with_first_project do |project|
      @program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'closed'}
      project = @program.projects.first
      post :update, :back_to_url => "http://localhost:3000/programs/#{@plan.program.id}/plan/objectives/feed_goat/work",:program_id => @program.to_param, :id => project.identifier, :program_project => {:status_property_name => property_to_map.name, :done_status => enumeration_value_to_map.value }
      assert_redirected_to :action => "index", :controller => "works"
    end
  end

  def test_should_show_add_project_form
    @program = create_program
    get :index, :program_id => @program.to_param
    assert_response :success

    Rails.logger.info "[DEBUG]Project.all_available => #{Project.all_available.inspect}"
    Rails.logger.info "[DEBUG]Project.all => #{Project.all.inspect}"

    assert_select "#add_project_to_program_form", {:count => 1}, "Could not find expected element in #{@response.body}"
  end

  def test_should_be_change_to_define_property_mapping
    with_sp_first_project do |project|
      get :index, :program_id => @program.to_param
      assert_response :success
      assert_select "a", :text => 'define done status', :count => 1
    end
  end

  def test_should_be_able_to_edit_property_mapping
    with_new_project(:name => 'dontkillbill') do |project|
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'closed'])

      @program.projects << project
      @plan.program.update_project_status_mapping(project, :status_property_name => 'Status', :done_status => 'closed')

      get :index, :program_id => @program.to_param
      assert_response :success
      assert_select "a", :text => 'Status &gt;= closed', :count => 1
    end
  end

  def test_should_be_able_to_use_a_hidden_property
    with_first_project do |project|
      @program.projects << project
      property_to_map = project.find_property_definition("Material")
      property_to_map.update_attributes(:hidden => true)
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'gold'}
      post :update, :program_id => @program.to_param, :id => project.identifier, :program_project => {:status_property_name => property_to_map.name, :done_status => enumeration_value_to_map.value }, :back_to_url => 'someplace'

      project.reload
      assert_equal property_to_map, @program.status_property_of(project)
      assert_equal enumeration_value_to_map, @program.done_status_of(project)
    end
  end

  def test_confirm_delete_of_unused_project_should_say_its_unused
    get :confirm_delete, :program_id => @program.to_param, :id => sp_first_project.identifier
    assert_select 'p', :text => /There is no work from this project/
  end

  def test_confirm_delete_should_show_number_of_works_and_objective_names
    first_objective = @program.objectives.first
    second_objective = @program.objectives.second
    @plan.assign_cards(sp_second_project, [1,2], first_objective)
    @plan.assign_cards(sp_second_project, 3, second_objective)
    get :confirm_delete, :program_id => @program.to_param, :id => sp_second_project.identifier
    assert_select 'p', :text => /3 work items/
    assert_select 'li', :text => first_objective.name, :count => 1
    assert_select 'li', :text => second_objective.name, :count => 1
  end

  def test_destroy_program_project
    assert_difference "ProgramProject.count", -1 do
      delete :destroy, :program_id => @program.to_param, :id => sp_first_project.identifier
      assert_redirected_to :action => 'index'
      follow_redirect
      assert_select '#notice', :text => "Project #{sp_first_project.name} has been removed from this program."
    end
  end

  def test_looks_up_values_for_the_property_specified_in_the_http_params
    with_first_project do |project|
      @program.projects << project
      get :property_values_and_associations, :property_name => "Status",  :program_id => @program.to_param, :id => project.identifier
      assert_response :success
      assert_match project.find_property_definition('Status').allowed_values.to_json, @response.body
    end
  end

  def test_looks_up_property_associations_for_the_property_specified_in_the_http_params
    with_first_project do |project|
      @program.projects << project
      get :property_values_and_associations, :property_name => "Status",  :program_id => @program.to_param, :id => project.identifier
      assert_response :success
      assert_match /\{\"values\":\[.*\],\"card_types\":\[.*\]\}/, @response.body
      assert_match project.find_property_definition('Status').card_type_names.to_json, @response.body
    end
  end

  def test_looks_up_property_associations_for_the_property_specified_in_the_http_params
    with_new_project(:name => 'zoozoo') do |project|
      story_type = setup_card_type(project, 'Story')
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'fixed', 'closed'], :card_type => story_type)

      @program.projects << project
      get :property_values_and_associations, :property_name => "Status",  :program_id => @program.to_param, :id => project.identifier
      assert_response :success
      assert_match ['Story'].to_json, @response.body
    end
  end

  def test_cancel_button_points_to_program_projects_index
    with_new_project(:name => 'zoozoo') do |project|
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'fixed', 'closed'])

      @program.projects << project
      get :edit, :program_id => @program.to_param, :id => project.identifier
      assert_select "input[value=?][onclick=?]", "Cancel", "window.location.href = &quot;#{program_program_projects_path(@program)}&quot;;"
    end
  end

  def test_edit_project_done_status_should_only_show_managed_text_properties
    with_new_project(:name => 'zoozoo') do |project|
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Attendees', [1, 2, 3, 4, 5], {:is_numeric => true})
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'fixed', 'closed'])

      @program.projects << project
      get :edit, :program_id => @program.to_param, :id => project.identifier
      assert_response :success
      assert_select "select#program_project_status_property_name" do
        assert_select "option", :count => 1
      end
    end
  end

  def test_edit_project_done_status_should_default_to_first_enum_property
    with_new_project(:name => 'zoozoo') do |project|
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'closed'])
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Bug Status', ['open', 'fixed'])

      @program.projects << project
      @plan.program.update_project_status_mapping(project, :status_property_name => 'Status', :done_status => 'closed')

      get :edit, :property_name => "Status",  :program_id => @program.to_param, :id => project.identifier
      assert_response :success

      assert_select "select#program_project_status_property_name" do
        assert_select "option", :count => 2
        assert_select "option[selected=selected]", :text => "Status"
        assert_select "option", :text => "Bug Status"
      end

      assert_select "select#program_project_done_status" do
        assert_select "option", :count => 2
        assert_select "option[selected=selected]", :text => "closed"
        assert_select "option", :text => "open"
      end
    end
  end

  def test_should_not_allow_to_create_program_project_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :create, :program_id => @program.to_param, :new_program_project => {:id => 'identifier'}
      end
    end
  end

  def test_should_not_allow_to_destroy_program_project_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        delete :destroy, :program_id => @program.to_param, :id => sp_first_project.identifier
      end
    end
  end

  def test_should_not_allow_to_confirm_delete_program_project_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        get :confirm_delete, :program_id => @program.to_param, :id => sp_first_project.identifier
      end
    end
  end

  def test_should_not_allow_to_update_program_project_when_readonly_mode_is_toggled_on
    with_first_project do |project|
      @program.projects << project
      property_to_map = project.find_property_definition("Material")
      enumeration_value_to_map = property_to_map.enumeration_values.detect {|ev| ev.value == 'wood'}

      MingleConfiguration.overridden_to(readonly_mode: true) do
        assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
          post :update, :program_id => @program.to_param, :id => project.identifier, :program_project => {:status_property_name => property_to_map.name, :done_status => enumeration_value_to_map.value}, :back_to_url => 'someplace'
        end
      end
    end
  end

  def test_should_not_allow_to_update_accepts_dependencies_program_project_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        put :update_accepts_dependencies, :program_id => @program.to_param
      end
    end
  end

  def test_should_not_allow_to_edit_program_project_when_readonly_mode_is_toggled_on
    with_new_project(:name => 'zoozoo') do |project|
      UnitTestDataLoader.create_enumerated_property_definition(project, 'Status', ['open', 'fixed', 'closed'])

      @program.projects << project
      MingleConfiguration.overridden_to(readonly_mode: true) do
        assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
          get :edit, :program_id => @program.to_param, :id => project.identifier
        end
      end
    end
  end


  def test_should_not_allow_to_access_property_values_and_associations_when_readonly_mode_is_toggled_on
    with_first_project do |project|
      @program.projects << project
      MingleConfiguration.overridden_to(readonly_mode: true) do
        assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
          get :property_values_and_associations, :property_name => "Status", :program_id => @program.to_param, :id => project.identifier
        end
      end
    end
  end

  def test_index_should_not_render_add_project_to_program_section
    MingleConfiguration.overridden_to(readonly_mode: true) do
      get :index, :program_id => @program.to_param
      assert_select "div.add_project_to_program #add_project_to_program_form", :count => 0
    end
  end

  def test_index_should_not_render_remove_column
    MingleConfiguration.overridden_to(readonly_mode: true) do
      get :index, :program_id => @program.to_param
      assert_select "table#project_mappings thead th:nth-child(4)", :count => 0
      assert_select "table#project_mappings tbody td:nth-child(4)", :count => 0
    end
  end

  def test_index_should_not_render_done_status_column_values_as_link
    with_first_project do |project|
      program  = create_program
      program.projects << project
      program.projects << create_project(prifix: 'Z_project')
      property_to_map = project.find_property_definition("Material")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'wood'}
      program.update_project_status_mapping(project, {status_property_name: property_to_map.name, done_status: enumeration_value_to_map.value})
      MingleConfiguration.overridden_to(readonly_mode: true) do
        get :index, :program_id => program.to_param
        assert_select "table#project_mappings tbody tr:nth-child(1) td:nth-child(2)", :text => 'Material &gt;= wood', :count => 1
        assert_select "table#project_mappings tbody tr:nth-child(1) td:nth-child(2) > a", :text => 'Material &gt;= wood', :count => 0
        assert_select "table#project_mappings tbody tr:nth-child(2) td:nth-child(2)", :text => 'define a managed text property in this project', :count => 1
        assert_select "table#project_mappings tbody tr:nth-child(2) td:nth-child(2) > a", :text => 'define a managed text property in this project', :count => 0
      end
    end
  end
end
