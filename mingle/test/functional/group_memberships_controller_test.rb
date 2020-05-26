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

class GroupMembershipsControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller GroupMembershipsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.env["HTTP_REFERER"] = 'something'
    login_as_admin
    @project = first_project
    @project.activate
    
  end

  def test_update_group_membership
    with_first_project do |project|
      group1 = project.user_defined_groups.create!(:name => "group 1")
      group2 = project.user_defined_groups.create!(:name => "group 2")
      member = project.users.first
      group2.add_member(member)
      post :update, :selected_users => project.users.map(&:id), :adds => [group1.id], :removes => [group2.id], :project_id => project.identifier
      assert_response :redirect
      assert_equal "#{project.users.size} members have been removed from #{group2.name.bold} and added to #{group1.name.bold}.", flash[:notice]
      assert project.users.count > 0
      project.users.each do |member|
        assert_equal ['group 1'], project.groups_for_member(member).collect(&:name)
      end
    end
  end
  
  def test_should_display_users_name_when_updating_a_single_user
    with_first_project do |project|
      group = project.user_defined_groups.create!(:name => "group")
      member = project.users.first
      post :update, :selected_users => [member.id], :adds => [group.id], :project_id => project.identifier
      assert_equal "#{member.name.bold} has been added to #{group.name.bold}.", flash[:notice]
    end
  end

  def test_should_add_single_user_to_group
    with_first_project do |project|
      group = project.user_defined_groups.create!(:name => "group")
      member = project.users.last
      xhr :post, :add, :selected_membership => member.id, :group => group.id, :project_id => project.identifier
      assert_rjs :replace, member.html_id, /Existing group member/
      assert_rjs :replace, 'flash', Regexp.new(json_escape("<b>#{member.name}</b> has been added to <b>#{group.name}</b>"))
    end
  end
  
  def test_update_group_flash_message_for_only_add_member_to_groups
    group = @project.user_defined_groups.create!(:name => "group 1")
    all_member_ids = @project.users.map(&:id)
    post :update, :selected_users => all_member_ids, :adds => [group.id], :project_id => @project.identifier
    assert_equal "#{@project.users.size} members have been added to #{group.name.bold}.", flash[:notice]
  end
  
  def test_update_group_membership_with_adding_to_multiple_groups_flash_message
    group_1 = create_group("group 1")
    group_2 = create_group("group 2")
    all_member_ids = @project.users.collect(&:id)
    post :update, :selected_users => all_member_ids, :adds => [group_1.id, group_2.id], :project_id => @project.identifier
    assert_equal "#{@project.users.size} members have been added to #{group_1.name.bold}, #{group_2.name.bold}.", flash[:notice]
  end

  def test_update_group_membership_with_removing_from_multiple_groups_flash_message
    group_1 = create_group("group 1")
    group_2 = create_group("group 2")
    @project.users.each do |user|
      group_1.add_member(user)
      group_2.add_member(user)
    end
    
    post :update, :selected_users => @project.users.map(&:id), :removes => [group_1.id, group_2.id], :project_id => @project.identifier
    assert_match(/^#{@project.users.size} members/, flash[:notice])

    groups = flash[:notice].scan(/group \d/)
    assert_equal ["group 1", "group 2"], groups.sort
  end
  
  def test_flash_message_should_be_empty_if_nothing_happened
    group_1 = create_group("group 1")
    all_member_ids = @project.users.collect(&:id)
    post :update, :selected_users => all_member_ids, :removes => [group_1.id], :project_id => @project.identifier
    assert_nil flash[:notice]
  end
  
  def test_update_group_membership_flash_message_should_not_add_groups_multiple_times
    group_1 = create_group("group 1")
    group_2 = create_group("group 2")
    @project.users.each do |member|
      group_1.add_member(member)
      group_2.add_member(member)
    end
    
    post :update, :selected_users => @project.users.map(&:id), :removes => [group_2.id], :adds => [group_1.id], :project_id => @project.identifier
    assert_equal "#{@project.users.size} members have been removed from #{group_2.name.bold}.", flash[:notice]
  end
  
  def test_update_group_membership_flash_message_should_not_remove_groups_multiple_times
    group_1 = create_group("group 1")
    group_2 = create_group("group 2")
    
    post :update, :selected_users => @project.users.map(&:id), :removes => [group_2.id], :adds => [group_1.id], :project_id => @project.identifier
    assert_equal "#{@project.users.size} members have been added to #{group_1.name.bold}.", flash[:notice]
  end

  def test_should_not_update_group_membership_if_action_is_nochange
    with_first_project do |project|
      member = project.users.first
      group = project.user_defined_groups.create!(:name => "group 1")
      group.add_member(member)

      post :update, :selected_users => [member.id], :no_change => [group.id], :project_id => project.identifier
      assert_response :redirect
      assert_equal ['group 1'], project.groups_for_member(member).collect(&:name)
    end
  end
  
  def test_should_not_throw_error_when_trying_to_add_user_to_the_same_group_twice
    with_first_project do |project|
      member = project.users.first
      group = project.user_defined_groups.create!(:name => "group 1")

      post :update, :selected_users => [member.id], :adds => [group.id], :project_id => project.identifier
      assert_response :redirect
      
      post :update, :selected_users => [member.id], :adds => [group.id], :project_id => project.identifier
      assert_response :redirect
      
      assert_equal ["group 1"], project.groups_for_member(member).collect(&:name)
    end
  end
  
  def test_should_not_throw_error_when_trying_to_remove_a_user_from_a_group_twice
    with_first_project do |project|
      member = project.users.first
      group = project.user_defined_groups.create!(:name => "group 1")
      group.add_member(member)

      post :update, :selected_users => [member.id], :removes => [group.id], :project_id => project.identifier
      assert_response :redirect
      
      post :update, :selected_users => [member.id], :removes => [group.id], :project_id => project.identifier
      assert_response :redirect
      
      assert project.groups_for_member(member).empty?
    end
    
  end

end
