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

class TeamControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller TeamController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = User.find_by_login('member')
    @proj_admin = User.find_by_login('proj_admin')
    @admin = login_as_admin
    @project = create_project :users => [@member, @proj_admin]
    @project.add_member(@member)
    @project.add_member(@proj_admin, :project_admin)
    login_as_proj_admin
    register_trial_license
  end

  def teardown
    ActionMailer::Base.deliveries = []
  end

  def test_proj_admin_cannot_remove_self
    assert_no_difference "@project.reload.users.count" do
      post :destroy, :project_id => @project.identifier, :selected_users => [@proj_admin.id]
    end
    assert_redirected_to :action => 'list'
    assert_match /Cannot remove yourself from team/, flash[:error]
  end

  def test_list_with_page_number_and_selected_users_specified
    with_page_size(2) do
      (1..3).each do |index|
        @project.add_member(create_user!(:name => 'a' << index))
      end

      get :list, :project_id => @project.identifier, :page => 2, :selected_users => [@member.id.to_s]
      assert_select ".pagination .current", :text => '2'
      assert_checked "#selected_membership_#{@proj_admin.id}", :count => 0
      assert_checked "#selected_membership_#{@member.id}"
    end
  end

  def test_filter_out_deactivated_users
    u1 = create_user!(:name => 'user1')
    u1.update_attributes(:activated => false)
    u2 = create_user!(:name => 'user2')

    @project.add_member(u1)
    @project.add_member(u2)

    get :index, :project_id => @project.identifier, :format => 'json', :search => { :query => 'user' }
    assert_equal ['user1', 'user2'], JSON.parse(@response.body).map { |u| u['name'] }

    get :index, :project_id => @project.identifier, :format => 'json', :search => { :query => 'user', :exclude_deactivated_users => 'true' }
    assert_equal ['user2'], JSON.parse(@response.body).map { |u| u['name'] }
  end

  def test_get_users_with_json_format_return_use_with_name_order
    (1..3).each do |index|
      @project.add_member(create_user!(:name => 'a' << index.to_s))
    end

    get :index, :project_id => @project.identifier, :search => {:per_page => 2}, :format => 'json'

    assert_response :ok
    assert_equal ['a1', 'a2'], JSON.parse(@response.body).map { |u| u['name'] }
  end

  def test_team_members_should_not_see_checkboxes_or_remove_button
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select "a", :text => "Remove", :count => 0
    assert_select ".select-membership", :count => 0
  end

  def test_project_admin_should_see_member_name_as_links
    get :list, :project_id => @project.identifier
    @project.users.each do |member|
      assert_select "##{member.html_id} a", :text => member.name, :count => 1
    end
  end

  def test_project_admin_should_see_own_user_name_as_link_to_profile
    get :list, :project_id => @project.identifier
    assert_response :success
    assert_select "a[href=?]", "/profile/show/#{@proj_admin.id}", :count=>1, :text=>@proj_admin.name
  end

  def test_mingle_admin_should_see_own_user_name_as_link_to_profile
    login_as_admin
    admin = User.find_by_login('admin')
    @project.add_member(admin)
    get :list, :project_id => @project.identifier
    assert_select "a[href=?]", "/profile/show/#{admin.id}", :count=>1, :text=> admin.name
    assert_select "a[href=?]", "/users/#{@proj_admin.id}", :count=>1, :text=>@proj_admin.name
  end

  def test_project_admin_of_current_project_should_see_member_name_as_links
    bob = User.find_by_login('bob')
    first_project.add_member(bob, :project_admin)
    login_as_bob
    get :list, :project_id => first_project.identifier
    assigns(:users).each do |user|
      assert_select "##{user.html_id} .user-name a", :text => user.name, :count => 1
    end
  end

  def test_project_admin_of_other_project_should_see_not_member_name_as_links
    bob = User.find_by_login('bob')
    @project.add_member(bob, :project_admin)
    assert_false first_project.admin?(bob)
    login_as_bob
    get :list, :project_id => first_project.identifier

    assert assigns(:users).detect {|user| user == User.current}
    assert assigns(:users).size > 1
    assigns(:users).each do |user|
      assert_select "##{user.html_id} .user-name a", :text => user.name, :count => 0
      assert_select "##{user.html_id} .user-name", :text => user.name, :count => 1
    end
  end

  def test_non_project_admin_should_not_see_member_name_as_links
    login_as_member
    get :list, :project_id => @project.identifier

    assert @project.users.size > 1

    @project.users.each do |member|
      assert_select "##{member.html_id} td" do |elements|
        children = elements.collect { |element| element.children.first }
        assert_equal_ignoring_spaces member.name, children[0].content
      end
      assert_select "##{member.html_id} .user-name a", :text => member.name, :count => 0
      assert_select "##{member.html_id} .user-name", :text => member.name, :count => 1
    end
  end

  def test_delete_all_selected_users
    bob = User.find_by_login('bob')
    first = User.find_by_login('first')
    @project.add_member(bob)
    @project.add_member(first)

    user_ids = [bob, first, @member].map(&:id)
    post :destroy, :project_id => @project.identifier, :selected_users => user_ids
    assert_redirected_to :action => 'list'
    assert_equal ['proj_admin@email.com'], @project.reload.users.collect(&:name)
  end

  def test_delete_selected_users_twice
    bob = User.find_by_login('bob')
    first = User.find_by_login('first')
    @project.add_member(bob)
    @project.add_member(first)

    user_ids = [bob, first, @member]

    post :destroy, :project_id => @project.identifier, :selected_users => user_ids
    post :destroy, :project_id => @project.identifier, :selected_users => user_ids

    assert_redirected_to :action => 'list'
    assert_equal ['proj_admin@email.com'], @project.reload.users.collect(&:name)
  end

  def test_destroy_empty_selected_users
    post :destroy, :project_id => @project.identifier, :selected_users => nil
    assert_redirected_to :action => 'list'
  end

  def test_should_ask_for_confirmation_if_users_involved_in_transitions
    setup_user_definition 'owner'
    create_transition(@project, (transition_name = 'remove owner'), :set_properties => {:owner => @member.id}).save!
    assert_no_difference "@project.reload.users.count" do
      post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    end
    assert_response :success
    assert_select 'p', :text => "1 Transition Deleted: #{transition_name}"
  end

  def test_should_ask_for_confirmation_if_users_involved_in_card_defaults
    setup_user_definition 'owner'
    card_type = @project.card_types.first
    card_type.card_defaults.update_properties :owner => @member.id

    assert_no_difference "@project.reload.users.count" do
      post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    end
    assert_response :success
    assert_select 'p', :text => "1 Card Defaults Modified: #{card_type.name}"
  end

  def test_should_delete_memberships_with_confirm_option_when_there_is_warning
    setup_user_definition 'owner'
    create_transition(@project, (transition_name = 'remove owner'), :set_properties => {:owner => @member.id}).save!
    assert_difference "@project.reload.users.count", -1 do
      post :destroy, :project_id => @project.identifier, :selected_users => [@member.id], :confirm => "true"
    end
    assert_redirected_to :action => 'list'
  end

  def test_should_only_display_team_members
    new_user = create_user!

    get :list, :project_id => @project.identifier
    assert_not_include new_user.login, assigns('users').collect(&:login)

    @project.add_member(new_user)
    get :list, :project_id => @project.identifier
    assert_include new_user.login, assigns('users').collect(&:login)
  end

  def test_should_list_member_in_name_order
    user1 = create_user!(:name  => 'dog', :login => 'a')
    user2 = create_user!(:name  => 'cat', :login => 'b')
    @project.add_member(user1)
    @project.add_member(user2)

    get :list, :project_id => @project.identifier
    assert assigns('users').index(user1) > assigns('users').index(user2)
  end

  # Bug 5647
  def test_list_member_should_order_by_name_and_case_insensitive
    (1..PAGINATION_PER_PAGE_SIZE).each do |index|
      @project.add_member(create_user!(:name => 'a' << index))
    end

    user1 = create_user!(:name => 'yoon', :login => 'yoon')
    user2 = create_user!(:name => 'Zumboldt', :login => 'Zumboldt')
    @project.add_member(user1)
    @project.add_member(user2)

    get :list, :project_id => @project.identifier, :page => '2'
    assert assigns('users').index(user1) < assigns('users').index(user2)
  end

  def test_destroy_team_member
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_response :redirect
    assert !@project.reload.member?(@member)
  end

  def test_add_team_member
    post :add_user_to_team, :project_id => @project.identifier, :user_id => @member.id
    assert_response :success
    assert_select "#user_#{@member.id}", :text => /Existing team member/
    assert @project.reload.member?(@member)
  end

  # bug 2906, scenario 1 warning.
  def test_should_warn_that_transitions_will_be_deleted_when_only_a_user_property_exists
    setup_user_definition 'owner'
    setup_user_definition 'owned'

    create_transition(@project, (second_sorted_name = 'remove owner'), :set_properties => {:owner => @member.id}).save!
    create_transition(@project, (first_sorted_name = 'remove owned'),  :set_properties => {:owned => @member.id}).save!

    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_response :success
    assert_template 'confirm_destroy'

    assert_select 'p', :text => "2 Transitions Deleted: #{first_sorted_name}, #{second_sorted_name}"
  end

  def test_should_warn_that_transitions_will_remove_specified_user_that_remove
    setup_property_definitions(:status => ['open', 'closed'])
    transition = create_transition(@project, 'just for member', :set_properties => {:status => 'closed'}, :user_prerequisites => [@member.id])
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_template 'confirm_destroy'
    assert_select 'p', :text => "1 Transition Modified: #{transition.name}"
  end

  # bug 2906, scenario 1 action.
  def test_should_delete_transition_that_only_sets_a_property_to_member_just_removed
    setup_user_definition 'owner'

    create_transition(@project, (transition_name = 'remove owner'), :set_properties => {:owner => @member.id}).save!

    @project.reload
    login_as_admin
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id], :confirm => true
    assert_redirected_to :action => :list
    assert_equal nil, @project.transitions.find_by_name(transition_name)
  end

  def test_should_delete_transitions_that_use_project_variable_that_use_the_removed_member
    owner = setup_user_definition 'owner'
    i_am_a_member = create_plv!(@project, :name => 'i am a member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @member.id, :property_definition_ids => [owner.id])
    transition = create_transition(@project, 'set user to the member', :set_properties => {:owner => i_am_a_member.value})

    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]

    assert_select 'p', "1 Transition Deleted: #{transition.name}"
  end

  # bug 4528
  def test_should_not_delete_transitions_just_because_user_property_action_sets_to_current_user
    login_as_admin
    admin = User.find_by_login('admin')
    @project.add_member(admin)

    daddy_mac = setup_user_definition('daddy mac')

    keep_transition = create_transition(@project, 'make me daddy mac', :set_properties => {'daddy mac' => PropertyType::UserType::CURRENT_USER})
    delete_transition = create_transition(@project, 'admin is daddy mac', :set_properties => {'daddy mac' => admin.id})

    post :destroy, :project_id => @project.identifier, :selected_users => [admin.id]
    assert_response :success
    assert_template 'confirm_destroy'

    assert_select 'p', "1 Transition Deleted: #{delete_transition.name}"
  end

  def test_add_a_user_to_project_team_member
    user = create_user!
    xhr :post, :add_user_to_team, :project_id => @project.identifier, :user_id => user.id
    assert_response :success
    assert_not_nil flash.now[:notice]
    assert @project.reload.member?(user)
  end

  def test_can_add_a_user_as_a_readonly_member
    user = create_user!
    xhr :post, :add_user_to_team, :project_id => @project.identifier, :user_id => user.id, :readonly => true
    assert_response :success
    assert_equal "#{user.name.bold} has been added to the #{@project.identifier.bold} team successfully.", flash.now[:notice]
    assert_select "#user_#{user.id}", :text => /Existing team member/
    assert @project.reload.readonly_member?(user)
  end

  def test_adding_user_should_redirect_to_correct_page
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member,  :membership => {:permission => "project_admin"}, :page => 2
    assert_response :success
    assert_rjs :redirect_to, :action => 'list', :page => 2, :tab => 'users_tab', :escape => false
  end

  def test_remove_user_from_team
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_redirected_to :action => 'list'
    assert_include "successfully", flash[:notice]
    assert !@project.reload.member?(@member)
  end

  def test_should_display_warning_message_when_remove_a_team_member_who_is_setted_as_user_property_value
    setup_user_definition 'owner'
    create_card!(:name => 'card1', :owner => @member.id)

    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_template 'confirm_destroy'
  end

  def test_should_display_warning_message_when_remove_a_readonly_member_who_is_setted_as_user_property_value
    @project.add_member(@member, :readonly_member)
    setup_user_definition 'owner'
    create_card!(:name => 'card1', :owner => @member.id)
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_select 'p', :text => "Card Properties changed to (not set): owner"
  end

  def test_should_display_warning_message_when_remove_a_team_member_who_is_set_as_project_variable_even_if_project_variable_not_associated_with_property
    owner_def = setup_user_definition 'owner'

    project_variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @member.id, :property_definition_ids => [])
    project_variable = create_plv!(@project, :name => 'Variable2', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @member.id, :property_definition_ids => [owner_def.id])

    @project.reload
    login_as_admin
    post :destroy, :project_id => @project.identifier, :selected_users => [@member.id]
    assert_template 'confirm_destroy'
  end

  def test_set_a_member_to_readonly
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => "readonly_member"}
    assert_response :success
    assert_not_nil flash[:notice]
    assert @project.reload.readonly_member?(@member)
  end

  def test_set_a_member_to_full_member
    @project.add_member(@member, :readonly_member)
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => "full_member"}
    assert_response :success
    assert_false @project.reload.readonly_member?(@member)
  end

  def test_set_a_member_to_admin
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => 'project_admin'}
    assert_response :success
    assert_not_nil flash[:notice]
    assert @project.reload.admin?(@member)
  end

  def test_set_a_member_to_garbage_should_blow_up
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => 'garbage'}
    assert_response :bad_request
    assert_nil flash[:notice]
    assert_false @project.reload.admin?(@member)
    assert_false @project.reload.readonly_member?(@member)
  end

  def test_should_show_error_when_set_to_not_readonly_failed
    @member.update_attribute(:light, true)
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => 'full_member'}
    assert_response :bad_request
    assert @project.reload.readonly_member?(@member)
  end

  def test_light_user_should_not_be_allowed_to_be_a_project_admin
    @member.update_attribute(:light, true)
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => "project_admin"}
    assert_response :bad_request
    assert_false @project.reload.project_admin?(@member)
  end

  def test_light_user_is_not_changeable
    login_as_admin
    @member.update_attribute(:light, true)
    get :list, :project_id => @project.identifier
    assert_permission_modification_disabled_for(@member)
  end

  # bug 5488
  def test_remove_user_from_team_keeps_user_on_same_page_of_team_list
    with_page_size(3) do
      @project.users.each { |member| @project.remove_member(member) }
      @project.reload
      (1..4).each do |index|
        @project.add_member(create_user!(:name => 'a' << index))
      end

      @project.add_member(@member)

      post :destroy, :project_id => @project.identifier, :selected_users => [@member.id], :page => 2
      assert_redirected_to :action => 'list', :page => 2
      assert_include "successfully", flash[:notice]
      assert !@project.reload.member?(@member)
    end
  end

  # bug 5488
  def test_destroy_user_after_confirmation_should_still_remain_page_parameter
    with_page_size(3) do
      login_as_admin

      clear_all_existing_user_memberships_for(@project)

      (1..4).each do |index|
        @project.add_member(create_user!(:name => 'a' << index))
      end

      @project.add_member(@member)

      setup_user_definition 'owner'
      create_transition(@project, 'remove owner', :set_properties => {:owner => @member.id}).save!

      post :destroy, :project_id => @project.identifier, :selected_users => [@member.id], :page => 2

      ['a.ok', 'a.cancel'].each do |link_css|
        assert_select link_css do |elements|
          assert_include 'page=2', elements.first.attributes['href']
        end
      end
    end
  end

  def test_enable_auto_enroll
    post :enable_auto_enroll, :project_id => @project.identifier, :auto_enroll_user_type => 'full'
    assert_redirected_to :action => :list
    @project.reload
    assert_equal User.find(:all).size, @project.users.size
  end

  def test_enable_all_users_as_members_should_not_display_for_team_member
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select('#enable_auto_enroll_form', false)
  end

  def test_disable_enroll_all_users_as_members_should_not_display_for_team_member
    @project.update_attribute :auto_enroll_user_type, 'full'
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select('#enroll_all_users_as_team_members_options', false)
  end

  def test_should_show_members_group_info
    login_as_proj_admin
    create_group("Dev").add_member(@member)
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select "##{@member.html_id}_groups", :text => "Dev"
  end

  def test_members_group_names_should_be_sorted
    login_as_proj_admin
    create_group("a Dev").add_member(@member)
    create_group("B Dev").add_member(@member)
    create_group("1 Dev").add_member(@member)
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select "##{@member.html_id}_groups", :text => ["1 Dev", "a Dev", "B Dev"].join(", ")
  end

  def test_members_group_names_should_be_linked_to_appropriate_group
    group1 = create_group("a Dev")
    group2 = create_group("B Dev")
    group1.add_member(@member)
    group2.add_member(@member)

    login_as_member
    get :list, :project_id => @project.identifier
    assert_select "##{@member.html_id}_groups>a" do |e|
      assert_select "a[href=?]", group_url(:id => group1.id, :back_to_team => true), :text => group1.name
      assert_select "a[href=?]", group_url(:id => group2.id, :back_to_team => true), :text => group2.name
    end
  end

  def test_avaliable_group_names_should_be_smart_sorted
    group1 = create_group("a Dev")
    group2 = create_group("B Dev")
    group3 = create_group("1 Dev")

    login_as_admin
    get :list, :project_id => @project.identifier
    assert_select "#group-selector .tristate-checkbox" do |elements|
      assert_equal ["1 Dev", "a Dev", "B Dev"], elements.map { |element| element.children.first.to_s.strip }
    end
  end

  def test_should_search_team_list
    farouche = create_user!(:name => 'farouche')
    ian = create_user!(:name => 'ian')
    @project.add_member(farouche)
    @project.add_member(ian)
    get :list, :project_id => @project.identifier, "search"=>{"query"=>"farouche"}
    assert_select "tr##{farouche.html_id}", :count => 1
    assert_select "tr##{ian.html_id}", :count => 0
    assert_equal "Search result for #{'farouche'.bold}.", flash[:info]
  end

  def test_set_user_permission_should_retain_search
    xhr :post, :set_permission, :project_id => @project.identifier, :user_id => @member, :membership => {:permission => 'readonly_member'}, :search => { :query => 'farouche'}
    assert_response :success
    assert_rjs :redirect_to, :action => 'list', :search => { :query => 'farouche'}, :tab => 'users_tab', :escape => false
  end

  def test_group_name_should_be_html_escaped
    group = create_group("<b>a Dev</b>")

    login_as_admin
    get :list, :project_id => @project.identifier

    assert_select "#group-selector .tristate-checkbox" do |elements|
      assert_equal ["&lt;b&gt;a Dev&lt;/b&gt;"], elements.map { |element| element.children.first.to_s.strip }
    end
  end

  def test_list_all_users_for_add_memeber
    get :list_users_for_add_member, :project_id => first_project.identifier
    assert_response :success
    assert_equal User.count, assigns['users'].size
    assert_equal first_project, assigns['project']
    assert_nil flash[:error]
  end

  def test_invite_existing_user_when_license_is_full_responds_successfully
    existing_user = create_user!
    register_trial_license(:max_active_users => User.activated_full_users)
    post :invite_user, :project_id => @project.identifier, :email => existing_user.email
    assert_response :success
    assert @project.member?(existing_user)
  ensure
    reset_license
  end

  def test_invite_new_user_when_license_is_full_responds_with_html_error_message
    register_trial_license(:max_active_users => User.activated_full_users)
    post :invite_user, :project_id => @project.identifier, :email => 'pierre@support.studios.com'
    assert_response :unprocessable_entity
    response_json = JSON.parse(@response.body)
    assert_match /upgrade/i, response_json['errorHtml']
  ensure
    reset_license
  end

  def test_invite_new_user_when_license_is_full_responds_with_buy_info
    register_trial_license(:max_active_users => User.activated_full_users)
    MingleConfiguration.with_new_buy_process_overridden_to('true') do
      post :invite_user, :project_id => @project.identifier, :email => 'pierre@support.studios.com'
      assert_response :unprocessable_entity
      response_json = JSON.parse(@response.body)
      assert_match /buy-form/i, response_json['errorHtml']
    end
  ensure
    reset_license
  end

  def test_license_is_full_after_invited_user_should_responds_with_buy_info
    register_trial_license(:max_active_users => (User.activated_full_users + 1))
    MingleConfiguration.with_new_buy_process_overridden_to('true') do
      post :invite_user, :project_id => @project.identifier, :email => 'pierre@support.studios.com'
      assert_response :success
      response_json = JSON.parse(@response.body)
      assert_match /buy-form/i, response_json['buy']
    end
  ensure
    reset_license
  end

  def test_license_is_full_after_invited_user_should_responds_nothing_if_toggle_is_off
    register_trial_license :max_active_users => (User.activated_full_users + 1)
    post :invite_user, :project_id => @project.identifier, :email => 'pierre@support.studios.com'
    assert_response :success
    response_json = JSON.parse(@response.body)
    assert_nil response_json['buy']
  ensure
    reset_license
  end

  def test_invite_user_fails_for_something_other_than_license_count_gives_corresponding_message
    post :invite_user, :project_id => @project.identifier, :email => 'not-an-email'
    assert_response :unprocessable_entity
    response_json = JSON.parse(@response.body)
    assert_match /email/i, response_json['errorMessage']
  end

  def test_invite_user_with_existing_user_should_add_invited_user_to_team
    user = create_user!
    post :invite_user, :project_id => @project.identifier, :email => user.email
    assert_response :success
    assert @project.member?(user)
  end

  def test_invite_new_user_responds_with_201_created
    post :invite_user, :project_id => @project.identifier, :email => 'luca@studios-support-team.com'
    assert_response :created
  end

  def test_invite_existing_user_responds_with_200_ok
    invitee = create_user!
    post :invite_user, :project_id => @project.identifier, :email => invitee.email
    assert_response :ok
  end

  def test_invite_existing_user_should_send_email_to_invited_user
    inviter = User.current
    user = create_user!
    post :invite_user, :project_id => @project.identifier, :email => user.email
    assert_equal 1, ActionMailer::Base.deliveries.size
    email_subject = ActionMailer::Base.deliveries.first.subject
    assert_include "#{inviter.name} has invited you to join the Mingle project", email_subject
    assert_equal [user.email], ActionMailer::Base.deliveries.first.to
  end

  def test_invite_user_returns_invited_user_information
    existing_user = create_user!
    post :invite_user, :project_id => @project.identifier, :email => existing_user.email
    response_json = JSON.parse(@response.body)
    assert_equal existing_user.id, response_json["id"]
    assert_equal Color.for(existing_user.name), response_json["color"]
    assert_match UserIcons.new(view_helper).url_for(existing_user), response_json["icon"]
    assert_equal existing_user.name, response_json["name"]
  end

  def test_invite_user_returns_license_alert_message_if__license_threshold_is_reached
    register_license(:paid => true, :max_active_users => User.activated_full_users + 2)
    existing_user = create_user!
    license_alert_message = '1 license left'
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do
      post :invite_user, :project_id => @project.identifier, :email => existing_user.email
      response_json = JSON.parse(@response.body)
      assert_equal existing_user.id, response_json["id"]
      assert_equal Color.for(existing_user.name), response_json["color"]
      assert_equal license_alert_message, response_json["license_alert_message"]
    end
  ensure
    reset_license
  end

  def test_invite_user_returns_nil_in_license_alert_message_if_license_threshold_is_not_reached
    register_license(:paid => true, :max_active_users => User.activated_full_users + 7)
    existing_user = create_user!
    license_alert_message = nil
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do
      post :invite_user, :project_id => @project.identifier, :email => existing_user.email
      response_json = JSON.parse(@response.body)
      assert_equal existing_user.id, response_json["id"]
      assert_equal Color.for(existing_user.name), response_json["color"]
      assert_equal license_alert_message, response_json["license_alert_message"]
    end
  ensure
    reset_license
  end

  def test_full_team_member_can_invite_new_user
    login_as_member
    post :invite_user, :project_id => @project.identifier, :email => 'brand-new@thoughtworks.com'
    assert_response :success
    user = User.find_by_email('brand-new@thoughtworks.com')
    assert user
    assert @project.member?(user)
  end

  def test_full_team_member_can_invite_new_user_when_project_is_enabled_auto_enroll
    @project.update_attribute(:auto_enroll_user_type, AutoEnrollUserType::ALL_USERS_ARE_FULL_MEMBERS)

    login_as_member
    post :invite_user, :project_id => @project.identifier, :email => 'brand-new@thoughtworks.com'
    assert_response :success
  end

  def test_readonly_member_cannot_access_invite_user
    readonly_member = create_user!
    @project.add_member(readonly_member, :readonly_member)
    login(readonly_member)
    assert_raises ErrorHandler::UserAccessAuthorizationError do
      post :invite_user, :project_id => @project.identifier, :email => 'brand-new@thoughtworks.com'
    end
  end

  def test_invite_user_not_yet_in_mingle_should_send_them_different_invitation_email
    post :invite_user, :project_id => @project.identifier, :email => 'brand-new@thoughtworks.com'
    assert_response :success
    assert_equal 1, ActionMailer::Base.deliveries.size
    email_subject = ActionMailer::Base.deliveries.first.subject
    assert_match /invited you to join Mingle/, email_subject
  end

  def test_invite_suggestions_is_not_accessible_by_readonly_member
    user = create_user!
    @project.add_member(user, :readonly_member)
    login(user)
    assert_raises ErrorHandler::UserAccessAuthorizationError do
      get :invite_suggestions, :project_id => @project.identifier, :format => :json
    end
  end

  def test_invite_suggestions_should_return_the_emails_of_non_team_members
    get :invite_suggestions, :project_id => @project.identifier, :format => :json
    assert_response :success
    data = JSON.parse(@response.body)
    assert_include 'longbob@email.com', data

    @project.users.each do |existing_member|
      assert_not_include existing_member, data
    end

    expected_size = User.count - @project.users.size
    assert_equal expected_size, data.size
  end

  def test_invite_suggestions_with_term_that_matches_many_users_only_returns_25
    26.times do |index|
      user = create_user! :login =>"invite_me_#{index}"
    end
    get :invite_suggestions, :project_id => @project.identifier, :format => :json, :term => 'invite'
    data = JSON.parse(@response.body)
    assert_equal 25, data.size
  end

  def test_invite_suggestions_matching_a_user_without_an_email_does_not_include_them_in_results
    user_without_email = create_user! :login => 'luddite', :email => nil
    get :invite_suggestions, :project_id => @project.identifier, :format => :json, :term => 'luddite'
    data = JSON.parse(@response.body)
    assert_equal [], data
  end

  def test_invite_suggestions_with_term_should_filter_emails
    get :invite_suggestions, :project_id => @project.identifier, :format => :json, :term => 'bob'
    data = JSON.parse(@response.body)
    assert_equal ["bob@email.com", "longbob@email.com"].sort, data.sort
  end

  def test_invite_suggestions_with_nonmatching_term_returns_empty_array
    get :invite_suggestions, :project_id => @project.identifier, :format => :json, :term => 'zzz'
    data = JSON.parse(@response.body)
    assert_equal [], data
  end

  def test_invite_not_allowed_when_member_logged_in
    login_as_member
    register_license(:trial => false)
    post :invite_user, {:project_id => @project.identifier, :email => 'new_user@example.com'}
    assert_response :method_not_allowed
  end

  def test_list_users_for_add_member_should_show_all_users_when_not_showing_deactived_users
    user = create_user!
    user.update_attribute(:activated, false)

    UserDisplayPreference.current_user_prefs.update_preference(:show_deactived_users, false)
    User.current.reload

    get :list_users_for_add_member, :project_id => first_project.identifier

    assert_equal User.count, assigns('users').size
    assert_include user.login, assigns('users').collect(&:login)
  end

  def test_should_show_error_when_no_users_match_search
    get :list_users_for_add_member, :project_id => first_project.identifier, :search => { :query => 'not matched' }
    assert_response :success
    assert_equal "Your search for #{"not matched".bold} did not match any users.", flash[:info]
  end

  def test_should_show_search_info_when_users_found
    get :list_users_for_add_member, :project_id => first_project.identifier, :search => { :query => 'bob' }
    assert_response :success
    assert_not_nil flash[:info]
    assert_select "input#search-query[value=bob]"
  end

  def test_should_search_users_for_add_memeber
    get :list_users_for_add_member, :project_id => first_project.identifier, :search => { :query => 'bob' }
    assert_response :success
    assert_equal 2, assigns['users'].size
  end

  def test_should_show_full_and_readonly_links_in_add_member_list_when_user_is_a_full_user
    user = create_user!
    get :list_users_for_add_member, :project_id => first_project.identifier, :search => { :query => '' }
    assert_select "a#add-full-member-#{user.html_id}-to-team"
    assert_select "a#add-readonly-member-#{user.html_id}-to-team"
    assert_select "a#add-full-member-#{@admin.html_id}-to-team"
    assert_select "a#add-readonly-member-#{@admin.html_id}-to-team"
  end

  def test_list_users_for_add_member_can_return_single_member
    longbob = User.find_by_login 'longbob'
    get :list_users_for_add_member, :user_id => longbob.id, :project_id => first_project.identifier
    assert_template 'single_user_for_adding'
    assert_equal [longbob], assigns["users"]
  end

  def test_should_only_show_readonly_link_to_light_user
    user = create_user!
    user.update_attribute(:light, true)
    get :list_users_for_add_member, :project_id => first_project.identifier, :search => { :query => '' }
    assert_select "a#add-full-member-#{user.html_id}-to-team", :count => 0
    assert_select "a#add-readonly-member-#{user.html_id}-to-team"
  end

  def test_show_user_selector
    with_first_project do |project|
      xhr :get, :show_user_selector, :project_id => project.identifier, :property_definition_name => 'dev'
      assert_response :success
    end
  end

  def test_should_return_empty_list_when_get_index_with_out_bound_page_number
    with_first_project do |project|
      xhr :get, :index, :project_id => project.identifier, :page => '1', :format => 'json'
      assert_response :success
      users = JSON.parse(@response.body)
      assert users.length > 0

      xhr :get, :index, :project_id => project.identifier, :page => '50', :format => 'json'
      assert_response :success
      users = JSON.parse(@response.body)
      assert_equal [], users
    end
  end

  def assert_permission_modification_disabled_for(user)
    assert_select "tr##{user.html_id} .user_permission a", :count => 0
  end

  def assert_permission_modification_enabled_for(user)
    assert_select "tr##{user.html_id} .user_permission a", :count => 1
  end

  def register_trial_license(opts={})
    register_license(opts.merge(:trial => true))
  end
end
