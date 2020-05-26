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

class ProgramsControllerTest < ActionController::TestCase

  def setup
    login_as_admin
    @program = create_program
  end

  def test_only_mingle_admin_can_see_program_admin_buttons
    login_as_admin
    get :index
    assert_select 'a.link_as_button.primary', :text => 'new program'

    login_as_member
    get :index
    assert_select 'a.link_as_button', :count => 0
  end

  def test_admin_should_see_all_programs_regardless_of_membership
    get :index
    assert_equal Program.count, assigns['programs'].size
    assert_select ".program h2", :text => @program.name
  end

  def test_program_team_member_is_able_to_see_program_in_programs_list
    @program.add_member User.find_by_login("member")
    login_as_member

    get :index
    assert_equal Program.count, assigns['programs'].size
    assert_select ".program h2", :text => @program.name
  end

  def test_user_should_be_warned_when_they_have_no_program_memberships
    member = create_user!
    login(member)
    @program.add_member(member)

    get :index
    assert_equal 1, assigns['programs'].size
    assert_not_include "You are currently not a member of any program.", @response.body

    member.programs.each{|p| p.remove_member(member) }
    get :index

    assert_equal 0, assigns['programs'].size
    assert_include "You are currently not a member of any program.", @response.body
  end

  def test_should_create_program
    assert_nil Program.find_by_name('New Program')
    post :create
    new_program = Program.find_by_name('New Program')
    assert new_program
    assert_equal new_program.id, ActiveSupport::JSON.decode(@response.body)['program_id']
  end

  def test_should_create_program_with_unique_name
    Program.create!(:name => 'New Program', :identifier => 'program_blah')
    post :create
    assert_not_equal 'New Program', Program.find(ActiveSupport::JSON.decode(@response.body)['program_id'].to_i).name
  end


  def test_shows_plan_link_and_objective_count_when_plan_exists
    @program.objectives.planned.create!({:name => 'objective a', :start_at => "20 Feb 2011", :end_at => "1 Mar 2011"})

    get :index
    assert_select "a.plan-link", :href => program_plan_path(@program)
    assert_select "##{@program.identifier}_plan_description", :text => "1 Feature planned"
  end

  def test_shows_default_program_description
    get :index
    assert_select "a.plan-link", :href => program_plan_path(:program_id => @program.id)
    assert_select "##{@program.identifier}_plan_description", :text => "Start planning your features."
  end

  def test_should_check_user_access_for_request_when_planner_is_inaccessible
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :index
    end
  end

  def test_shows_backlog_link_and_backlog_objective_count
    @program.objectives.backlog.create!(:name => "unplanned objective")

    get :index
    assert_select "a.program-wall-link", :href => program_backlog_objectives_path(@program)
    assert_select "##{@program.identifier}_backlog_description", :text => "1 Objective"

    @program.objectives.backlog.create!(:name => "another unplanned objective")
    @program.objectives.planned.create!({:name => 'planned objective', :start_at => "20 Feb 2011", :end_at => "1 Mar 2011"})

    get :index
    assert_select "a.program-wall-link", :href => program_backlog_objectives_path(@program)
    assert_select "##{@program.identifier}_backlog_description", :text => "3 Objectives"
  end

  def test_shows_default_message_for_backlog_when_no_objectives_captured
    get :index
    assert_select "a.program-wall-link", :href => program_backlog_objectives_path(@program)
    assert_select "##{@program.identifier}_backlog_description", :text => "Start tracking your objectives."
  end

  def test_shows_program_link_and_default_message
    get :index
    assert_select "a.project-link", :href => program_program_projects_path(@program)
    assert_select ".program-projects p", :text => "Start adding projects to your program."
  end

  def test_only_mingle_admin_can_see_delete_program_link
    member = User.find_by_login('member')
    @program.add_member(member)

    login_as_admin
    get :index
    assert_select 'a', :text => 'Delete'

    login_as_member
    get :index
    assert_select 'a', {:text => "Delete", :count => 0}
  end

  def test_program_member_actions
    member = User.find_by_login('member')
    @program.add_member(member)

    login_as_member
    get :index

    assert_select 'a', {:href => program_program_memberships_path(@program), :text => 'Team'}
    assert_select 'a', {:href => program_export_index_path(@program), :text => 'Export'}
    assert_select 'a', {:text => "Delete", :count => 0}
  end

  def test_confirm_delete_program_with_objectives_and_projects_should_show_confirmation_and_warnings
    with_first_project do |project|
      assign_all_work_to_new_objective(@program, project)
      get :confirm_delete, :id => @program.to_param
      assert_response :success
      assert_select 'p', :text => "This program currently has a plan with 1 planned feature and a backlog with no unplanned features. 1 project is associated with this program."
    end
  end

  def test_delete_program_should_destroy_program
    delete :destroy, :id => @program.to_param
    assert_redirected_to programs_path
    assert_equal "Program #{@program.name.bold} was successfully deleted.", flash[:notice]
    assert Program.find_by_id(@program.id).nil?
  end

  def test_confirm_delete_empty_program_should_show_accurate_warnings
    get :confirm_delete, :id => @program.to_param
    assert_select 'p', :text => "This program currently has a plan with no planned features and a backlog with no unplanned features. No projects are associated with this program."
  end

  def test_update_program_name_updates_identifier
    put :update, :id => @program.to_param, :program => { :name => "renamed program" }
    assert_equal 'renamed_program', @program.reload.identifier
    assert_equal "renamed program", @program.name
    assert_rjs :replace_html, "program_details_#{@program.id}"
    assert_nil flash[:error]
  end

  def test_update_with_nonunique_name_renders_error
    Program.create!(:name => 'conflict', :identifier => 'conflict')
    put :update, :id => @program.to_param, :program => { :name => "conflict" }
    assert flash[:error]
  end

  def test_tabs_visibility
    get :index
    assert_select 'li.selected', :text => 'Programs'
    assert_select 'li', :text => 'Projects'
    assert_select 'li', :text => 'Admin'
  end

  def test_index_page_not_cached
    get :index
    assert_equal "no-cache, no-store, max-age=0, must-revalidate", @response.headers["Cache-Control"]
    assert_equal "no-cache", @response.headers["Pragma"]
    assert_equal "Fri, 01 Jan 1990 00:00:00 GMT", @response.headers["Expires"]
  end

  def test_reorder_objectives
    @program.objectives.backlog.create!(:name => "A")
    @program.objectives.backlog.create!(:name => "B")

    backlog_objectives = @program.objectives.backlog
    assert_equal 1, backlog_objectives.find_by_name('B').position
    assert_equal 2, backlog_objectives.find_by_name('A').position

    @program.reorder_objectives(@program.objectives.backlog.reverse.map(&:id))
    assert_equal 2, backlog_objectives.find_by_name('B').position
    assert_equal 1, backlog_objectives.find_by_name('A').position
  end

  def test_normalize_positions
    %w[c b a].each do |name|
      @program.reload.objectives.backlog.create!(:name => name)
    end

    backlog_objectives = @program.objectives.backlog

    backlog_objectives.find_by_name("a").update_attribute(:position, -1)
    backlog_objectives.find_by_name("b").update_attribute(:position, 8)
    backlog_objectives.find_by_name("c").update_attribute(:position, 14)

    backlog_objectives = @program.reload.objectives.backlog

    assert_equal -1, backlog_objectives.find_by_name('a').position
    assert_equal 8, backlog_objectives.find_by_name('b').position
    assert_equal 14, backlog_objectives.find_by_name('c').position

    @program.normalize_positions

    backlog_objectives = @program.reload.objectives.backlog

    assert_equal 1, backlog_objectives.find_by_name('a').position
    assert_equal 2, backlog_objectives.find_by_name('b').position
    assert_equal 3, backlog_objectives.find_by_name('c').position
  end

  def test_mingle_admin_can_not_see_program_admin_buttons_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      login_as_admin
      get :index
      assert_select 'a.link_as_button.primary', :text => 'new program', count: 0
      assert_select 'a.link_as_button.primary', :text => 'import program', count: 0
    end
  end

  def test_mingle_admin_can_not_see_delete_program_link_when_readonly_mode_is_toggled_on
    member = User.find_by_login('member')
    @program.add_member(member)
    MingleConfiguration.overridden_to(readonly_mode: true) do
      login_as_admin
      get :index
      assert_select "#program_#{@program.id}_link_menu_items a", :text => 'Delete', :count => 0
    end
  end

  def test_mingle_admin_can_not_see_rename_program_link_when_readonly_mode_is_toggled_on
    member = User.find_by_login('member')
    @program.add_member(member)
    MingleConfiguration.overridden_to(readonly_mode: true) do
      login_as_admin
      get :index
      assert_select "#program_#{@program.id}_link_menu_items a", :text => 'Rename', :count => 0
    end
  end

  def test_should_not_allow_to_create_program_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :create
      end
    end
  end

  def test_should_not_allow_to_destroy_program_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        delete :destroy, :id => @program.to_param
      end
    end
  end

  def test_should_not_allow_to_update_program_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        put :update, :id => @program.to_param, :program => {:name => "renamed program"}
      end
    end
  end
end
