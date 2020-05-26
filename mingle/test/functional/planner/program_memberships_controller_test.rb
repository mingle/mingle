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

class ProgramMembershipsControllerTest < ActionController::TestCase
  def setup
    @controller = ProgramMembershipsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @program = program("simple_program")
  end
  
  def test_index_should_select_admin_tab_and_team_members_sub_tab
    get :index, :program_id => @program.to_param
    assert_select 'li.selected a', :text => 'Team'
  end
  
  def test_index
    member = User.find_by_login('member')
    @program.add_member(member)
    get :index, :program_id => @program.to_param
    
    assert_equal [member], assigns['users']
    assert_select 'table td', :text => member.name
    assert_select 'table td', :text => member.login
    assert_select 'table td', :text => member.email
  end
  
  def test_create
    member = User.find_by_login('member')
    
    post :create, :program_id => @program.to_param, :user_id => member.id
    assert_response :success
    assert_rjs 'replace', member.html_id, /Existing team member/
    assert_include member, @program.reload.users
    assert_equal MembershipRole[:program_admin], @program.role_for(member)
  end
  
  def test_list_users_for_add
    member = create_user!
    admin = User.find_by_login('admin')
    @program.add_member(admin)
    
    get :list_users_for_add, :program_id => @program.to_param
    assert_response :success
    assert_select "table tr:first-child td", :text => "admin"
    assert_select "table tr:first-child td", :text => "Existing team member"

    assert_select "table tr td", :text => member.name
    assert_select "table tr td", :text => "Add to team"
  end

  def test_should_be_existing_member_for_light_user_team_member
    member = User.find_by_login('member')
    @program.add_member(member)
    member.update_attribute(:light, true)

    get :list_users_for_add, :program_id => @program.to_param
    assert_select "table tr td", :text => "Existing team member"
    assert_select "table tr td", :text => "Light user cannot be added as program team member", :count => 0
  end

  def test_should_not_be_able_to_add_light_user
    bob = User.find_by_login('bob')
    bob.update_attribute(:light, true)

    get :list_users_for_add, :program_id => @program.to_param
    assert_select "table tr td", :text => "Light user cannot be added as program team member"

    post :create, :program_id => @program.to_param, :user_id => bob.id
    assert_response :success
    assert_not_include bob, @program.reload.users
    assert_rjs 'replace', bob.html_id, /Light user cannot be added as program team member/
  end
  
  def test_bulk_destroy
    member = User.find_by_login('member')
    bob = User.find_by_login('bob')
    @program.add_member(member)
    @program.add_member(bob)

    post :bulk_destroy, :program_id => @program.to_param, :user_ids => [member.id, bob.id]

    assert_redirected_to program_program_memberships_path(@program)
    assert !@program.member?(member)
    assert !@program.member?(bob)
    assert_equal "2 members have been removed from the #{'simple program'.bold} team successfully.", flash[:notice]
  end

  def test_bulk_destroy_should_not_allow_member_to_remove_self
    member = login_as_member
    @program.add_member(member)

    post :bulk_destroy, :program_id => @program.to_param, :user_ids => [member.id]

    assert @program.member?(member)
    assert_equal "Cannot remove yourself from program", flash[:error]
  end

  def test_bulk_destroy_should_allow_mingle_admin_to_remove_anyone
    admin = login_as_admin
    member = User.find_by_login('member')

    @program.add_member(admin)
    @program.add_member(member)

    post :bulk_destroy, :program_id => @program.to_param, :user_ids => [admin.id, member.id]

    assert !@program.member?(member)
    assert !@program.member?(admin)
  end
  
  def test_bulk_destroy_should_remember_pages_params
    admin = login_as_admin
    member = User.find_by_login('member')
    @program.add_member(admin)
    @program.add_member(member)
    @program.add_member(User.find_by_login('longbob'))
    @program.add_member(User.find_by_login('bob'))
    
    with_page_size(2) do
      post :bulk_destroy, :program_id => @program.to_param, :user_ids => [member.id], :page => 2
      
      assert_redirected_to program_program_memberships_path(@program, :page => 2)
    end
  end
  
  def test_bulk_destroy_should_remmeber_search_param
    admin = login_as_admin
    member = User.find_by_login('member')
    @program.add_member(admin)
    @program.add_member(member)
    
    with_page_size(2) do
      post :bulk_destroy, :program_id => @program.to_param, :user_ids => [member.id], :search => { :query => 'member' }
      
      assert_redirected_to program_program_memberships_path(@program, :search => { :query => 'member' })
    end
  end

  def test_should_not_allow_to_create_program_membership_when_readonly_mode_is_toggled_on
    member = User.find_by_login('member')
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :create, :program_id => @program.to_param, :user_id => member.id
      end
    end
  end

  def test_should_not_allow_to_remove_program_membership_when_readonly_mode_is_toggled_on
    member = User.find_by_login('member')
    bob = User.find_by_login('bob')
    @program.add_member(member)
    @program.add_member(bob)
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :bulk_destroy, :program_id => @program.to_param, :user_ids => [member.id, bob.id]
      end
    end
  end

  def test_should_not_allow_to_list_user_for_add_when_readonly_mode_is_toggled_on
    member = create_user!
    admin = User.find_by_login('admin')
    @program.add_member(admin)
    MingleConfiguration.overridden_to(readonly_mode: true) do
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        get :list_users_for_add, :program_id => @program.to_param
      end
    end
  end

  def test_index_should_not_render_add_member_link_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      get :index, :program_id => @program.to_param

      assert_select 'a.add_link', :text => 'Add team member', :count => 0
    end
  end

  def test_index_should_not_render_table_actions_link_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      get :index, :program_id => @program.to_param

      assert_select 'a#select_all', :text => 'All', :count => 0
      assert_select 'a#select_none', :text => 'None', :count => 0
      assert_select 'input#remove_members', :text => 'Remove', :count => 0
    end
  end

  def test_index_should_not_render_members_list_with_checkbox_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      get :index, :program_id => @program.to_param

      assert_select 'table thead tr th', :count => 3
      assert_select 'table thead tr th:nth-child(1)', :text => 'Display name'
      assert_select 'table thead tr th:nth-child(2)', :text => 'Sign-in name'
      assert_select 'table thead tr th:nth-child(3)', :text => 'Email'

      assert_select 'table tbody tr td', :count => 3
      assert_select 'table tbody tr td:nth-child(1)', :text => 'member@email.com'
      assert_select 'table tbody tr td:nth-child(2)', :text => 'member'
      assert_select 'table tbody tr td:nth-child(3)', :text => 'member@email.com'
    end
  end
end
