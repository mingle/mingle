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

class GroupsControllerTest < ActionController::TestCase
    
  def setup
    @old_page_size = PAGINATION_PER_PAGE_SIZE
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 3) }
    @member = User.find_by_login('member')
    @proj_admin = User.find_by_login('proj_admin')
    @project = first_project
    @project.activate
  end

  def teardown
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', @old_page_size) }
    logout_as_nil
  end

  def test_index_shows_all_groups
    login_as_admin
    group = @project.user_defined_groups.create!(:name => "Group 1")
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_select ".group .name a", :text => group.name
    assert_select ".quick-add-group"
    assert_select '.action a', :text => "Delete"
  end

  def test_index_shows_all_groups_for_member
    login_as_member
    group = @project.user_defined_groups.create!(:name => "Group 1")
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_select ".group .name a", :text => group.name
    assert_select ".quick-add-group", :count => 0
    assert_select '.action a', :text => "Delete", :count => 0
  end
  
  def test_create_invalid_group
    login_as_admin
    post :create, :project_id => @project.identifier, :group => {:name => ''}
    assert_select ".error-box"
    assert_select ".group .name", :count => 0
  end

  def test_destroy_group
    login_as_admin
    group = create_group "Group 1"
    post :destroy, :project_id => @project.identifier, :id => group.id
    assert_response :redirect
    follow_redirect
    assert_select ".group .name", :count => 0
  end

  def test_should_not_provide_warning_if_deleting_an_unused_group
    login_as_admin
    group = create_group "Group 1"
    post :confirm_delete, :project_id => @project.identifier, :id => group.id
    assert_redirected_to :action => 'index'
  end

  def test_should_confirm_intent_to_delete_with_a_warning_if_deleting_a_group_with_a_member
    login_as_admin
    group = create_group "Group 1", @project.users[0..1]
    post :confirm_delete, :project_id => @project.identifier, :id => group.id
    assert_template :confirm_delete
    assert_select "#group_membership_deletion_warning", :text => "2 team members will lose their group membership."
  end

  def test_should_confirm_intent_to_delete_with_a_warning_if_deleting_a_group_used_in_transitions
    login_as_admin
    group = create_group "Group 1"
    create_transition(@project, 'mark fixed', :set_properties => {:status => 'fixed'}, :group_prerequisites => [group.id])
    
    post :confirm_delete, :project_id => @project.identifier, :id => group.id
    assert_template :confirm_delete
    assert_select "#transitions_affected_warning", :text => "Used by 1 transition."
  end

  def test_create_group
    login_as_admin
    post :create, :project_id => @project.identifier, :group => {:name => 'Group 2'}
    assert_response :redirect
    follow_redirect
    assert_select ".group .name", :text => "Group 2"
  end

  def test_should_not_be_able_to_create_group_as_member
    login_as_member
    assert_raises ApplicationController::UserAccessAuthorizationError do
      post :create, :project_id => @project.identifier, :group => {:name => 'Group 2'}
    end
  end

  def test_should_not_be_able_to_destroy_group_as_member
    login_as_member
    group = create_group "Group 1"
    assert_raises ApplicationController::UserAccessAuthorizationError do
      post :destroy, :project_id => @project.identifier, :id => group.id
    end
  end
  
  def test_can_update_project_group
    login_as_proj_admin
    group = create_group "Group 1"
    
    xhr :post, :update, :project_id => @project.identifier, :id => group.id, :name => 'new group'
    assert_response :success
    assert_equal 'new group', group.reload.name
  end
  
  def test_update_should_show_error_message_when_failed
    login_as_proj_admin
    group = create_group "MANA"
    group2 = @project.user_defined_groups.create!(:name => "will be mana")
    xhr :post, :update, :project_id => @project.identifier, :id => group2.id, :name => 'MANA'
    assert_equal "will be mana", group2.name
    assert_include 'Name has already been taken', flash[:error]
  end
  
  def test_should_not_allow_project_member_update
    login_as_member
    group = create_group "Group 1"
    assert_raises ApplicationController::UserAccessAuthorizationError do
      xhr :post, :update, :project_id => @project.identifier, :id => group.id, :name => 'new group'
      assert_response 403
    end
  end
  
  def test_should_show_group_members_count
    login_as_proj_admin
    create_group("group1").add_member(@project.users.first)
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_select ".numberofusers", :html => 1
  end
  
  def test_should_show_group_details
    login_as_member
    group = create_group "group1"
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select 'h1', :text => group.name
    assert_select '#inline-editor-actions a', :text => "Edit", :count => 0
  end
  
  def test_should_show_a_link_back_to_all_groups
    login_as_member
    group = create_group "group1"
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select '#back_to_group_list_button[href=?]', "/projects/#{group.deliverable.identifier}/groups", :text => "Back to user groups"
  end
  
  def test_should_show_a_link_back_to_team_if_coming_in_from_team_list
    login_as_member
    group = create_group "group1"
    get :show, :project_id => @project.identifier, :id => group.id, :back_to_team => "true"
    assert_select '#back_to_team_list_button[href=?]', "/projects/#{group.deliverable.identifier}/team", :text => "Back to team list"
  end
  
  def test_project_admin_should_be_able_to_edit_a_group
    login_as_proj_admin
    group = create_group "group1"
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select 'h1 span', :text => group.name
    assert_select '#inline-editor-actions a', :text => "Edit"
  end
  
  def test_should_show_remove_for_project_admin
    login_as_proj_admin
    group = create_group "group1"
    first_user = @project.users.first
    group.add_member(first_user)
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select "#select_all"
    assert_select "#select_none"
    assert_select "#remove_from_group"
    assert_select "##{first_user.html_id} input[type=checkbox]"
  end
  
  def test_should_not_show_remove_for_non_admin
    login_as_proj_admin
    first_user = @project.users.first
    group = create_group "group1"
    group.add_member(first_user)
    login_as_member
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select "#select_all", :count => 0
    assert_select "#select_none", :count => 0
    assert_select "#remove_from_group", :count => 0
    assert_select "##{first_user.html_id} input[type=checkbox]", :count => 0
  end
  
  def test_should_show_members
    login_as_proj_admin
    first_user = @project.users.first
    group = create_group "group1"
    group2 = create_group "group2"
    group.add_member(first_user)
    group2.add_member(first_user)
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select "##{first_user.html_id} td", :text => first_user.name
    assert_select "##{first_user.html_id} td", :text => first_user.login
    assert_select "##{first_user.html_id} td", :text => first_user.email
  end
  
  def test_should_show_add_member_button
    login_as_proj_admin
    group = create_group "group1"
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select "a.primary", :text => 'Add user as member', :href => /groups\/list_members_available_for_add\/#{group.id}/
  end
  
  def test_should_show_message_when_group_has_no_members
    login_as_proj_admin
    group = create_group "empty group"
    get :show, :project_id => @project.identifier, :id => group.id
    assert_select "td", :text => "There are currently no group members to list."
  end
  
  def test_should_paginate_group_members
    login_as_proj_admin
    new_guy = create_user! :name => 'new guy'
    mew_guy = create_user! :name => 'mew guy'
    
    [new_guy, mew_guy].each { |user| @project.add_member(user) }
    sorted_projects_members = @project.users.sort_by(&:name)
    first_member = sorted_projects_members.first
    second_member = sorted_projects_members.second
    third_member = sorted_projects_members.third
    fourth_member = sorted_projects_members.fourth
    
    group = create_group "group1"
    
    [first_member, second_member, third_member, fourth_member].each { |member| group.add_member(member) }
    
    get :show, :project_id => @project.identifier, :id => group.id, :page => 2
    assert_select "##{fourth_member.html_id} td", :text => fourth_member.name
    assert_select ".pagination .current", :text => '2'
  end
  
  def test_show_should_display_deactivated_user_correctly
    login_as_admin
    first_user = User.find_by_login('first')
    first_user.update_attribute(:activated, false)
    group = create_group "group1"
    group.add_member(first_user)
    
    get :show, :project_id => @project.identifier, :id => group.id

    assert_select "tr.deactivated", :count => 1
  end
  
  def test_list_members_available_for_add
    with_new_project_with_member_and_proj_admin do |project|
      group = project.user_defined_groups.create(:name => 'My Group')
      get :list_members_available_for_add, :project_id => project.identifier, :id => group.id
      assert_select "a", :text => /Back to group/, :href => '/groups/#{group.id}'
      assert_select "tr##{@member.html_id}", :count => 1
      assert_select "##{@member.html_id} a", :text => 'Add to group', :count => 1
      assert_tag :a, :attributes => { :onclick => /group_memberships\/add\?group=#{group.id}&amp;selected_membership=#{@member.id}/ }
    end
  end
  
  def test_list_members_available_for_add_existing_group_member_does_not_have_add_link
    with_new_project_with_member_and_proj_admin do |project|
      group = project.user_defined_groups.create(:name => 'My Group')
      group.add_member(@member)
      get :list_members_available_for_add, :project_id => project.identifier, :id => group.id
      assert_select "a", :text => /Back to group/, :href => '/groups/#{group.id}'
      assert_select "tr##{@member.html_id}", :count => 1
      assert_select "##{@member.html_id} a", :text => 'Add to group', :count => 0
      assert_select "##{@member.html_id} td", :text => 'Existing group member', :count => 1
    end
  end
  
  def test_list_members_available_for_add_is_paginated
    with_new_project_with_member_and_proj_admin do |project|
      (1..PAGINATION_PER_PAGE_SIZE).each do |index|
        project.add_member(create_user!(:name => 'a' << index))
      end
      sorted_members = project.users.sort_by(&:name)
      last_user_on_page_1 = sorted_members[PAGINATION_PER_PAGE_SIZE - 1]
      first_user_on_page_2 = sorted_members[PAGINATION_PER_PAGE_SIZE]
      group = project.user_defined_groups.create(:name => 'My Group')
      get :list_members_available_for_add, :project_id => project.identifier, :id => group.id, :page => 2
      assert_select "tr##{last_user_on_page_1.html_id}", :count => 0
      assert_select "tr##{first_user_on_page_2.html_id}", :count => 1
      assert_select ".pagination .current", :text => '2'
    end
  end
  
  def test_search_list_members_available_for_add
    with_new_project_with_member_and_proj_admin do |project|
      group = project.user_defined_groups.create(:name => 'Team Farouche')
      farouche = create_user!(:name => 'farouche')
      ian = create_user!(:name => 'ian')
      project.add_member(farouche)
      project.add_member(ian)
      get :list_members_available_for_add, :project_id => project.identifier, :id => group.id, "search"=>{"query"=>"farouche"}
      assert_select "tr##{farouche.html_id}", :count => 1
      assert_select "tr##{ian.html_id}", :count => 0
      assert_equal "Search result for #{'farouche'.bold}.", flash[:info]
    end
  end

  def test_search_list_members_available_for_add2
    with_new_project_with_member_and_proj_admin do |project|
      group = project.user_defined_groups.create(:name => 'Team Farouche')
      farouche = create_user!(:name => 'farouche')
      ian = create_user!(:name => 'ian')
      project.add_member(farouche)
      project.add_member(ian)
      get :list_members_available_for_add, :project_id => project.identifier, :id => group.id, "search"=>{"query"=>"nothingwillmatch"}
      assert_select "td", :text => "Your search for nothingwillmatch did not match any team members."
    end
  end
  
  def with_new_project_with_member_and_proj_admin
    with_new_project do |project|
      project.add_member(@member)
      project.add_member(@proj_admin, :project_admin)
      login_as_proj_admin
      yield project
    end
  end
end
