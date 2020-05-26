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

class TransitionsControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree  
  
  def setup
    @controller = create_controller TransitionsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member_user = User.find_by_login('member')
    @proj_admin = User.find_by_login('proj_admin')
    @admin = User.find_by_login('admin')
    @project = create_project  :users => [@member_user, @admin], :admins => [@proj_admin]
    setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [], :old_type => ['bug', 'story']
    login_as_proj_admin
  end
  
  def test_should_create_and_redirect_back_to_list_page_with_previously_filtered_criteria
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER }, 
         :sets_properties => {"status" => "fixed"},
         :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    assert_redirected_to :action => :list, :created_transition_id => @project.transitions.first.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
  end

  def test_should_update_and_redirect_back_to_list_page_with_previously_filtered_criteria
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    transition = create_transition(@project, 'fixed whatever', :set_properties => { :status => 'fixed' })
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => { :name => 'fixed whatever with new name' },
                  :sets_properties => { 'status' => 'fixed' },
                  :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    assert_redirected_to :action => :list, :updated_transition_id => transition.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
  end
  
  def test_destroy_should_redirect_back_to_list_page_with_previously_filtered_criteria
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    transition = create_transition(@project, 'fixed whatever', :set_properties => {:status => 'fixed'})
    post :destroy, :project_id => @project.identifier, 
                   :id => transition.id, 
                   :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    assert_redirected_to :action => :list, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
  end

  def test_should_create_transition_with_specified_prerequisites
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER }, 
         :sets_properties => {"status" => "fixed"}
    assert_response :redirect
    card = create_card!(:name => 'card for test', :old_type => 'bug', :status => 'open' )
    @project.transitions.find_by_name('fix bug').execute(card)
    assert_equal 'fixed', card.reload.cp_status
  end
  
  def test_should_create_transition_with_hidden_property_and_it_should_work_well_with_hidden_property
    @project.find_property_definition('status').update_attribute :hidden, true
    
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => PropertyValue::IGNORED_IDENTIFIER, "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER }, 
         :sets_properties => {"status" => "fixed"}
    assert_response :redirect
    card = create_card!(:name => 'card for test', :old_type => 'bug' )
    @project.transitions.find_by_name('fix bug').execute(card)
    assert_equal 'fixed', card.reload.cp_status
  end
  
  def test_should_create_transition_with_specified_user_prerequisites
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => 'open', "old_type" => "bug" }, 
         :sets_properties => {"status" => "fixed"},
         :user_prerequisites => {'0' => @admin.id.to_s }, 
         :used_by => TransitionsController::SELECTED_MEMBERS
    assert_response :redirect
    card =create_card!(:name => 'card for test', :old_type => 'bug', :status => 'open' )
    assert_raise(TransitionNotAvailableException) { @project.transitions.find_by_name('fix bug').execute(card) }
    login_as_admin
    @project.transitions.find_by_name('fix bug').execute(card)
    assert_equal 'fixed', card.reload.cp_status
  end
  
  def test_should_create_transition_with_specified_group_prerequisites
    group = create_group('devs')
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => 'open', "old_type" => "bug" }, 
         :sets_properties => {"status" => "fixed"},
         :group_prerequisites => {'0' => group.id.to_s }, 
         :used_by => TransitionsController::SELECTED_GROUPS
    assert_response :redirect
    card = create_card!(:name => 'card for test', :old_type => 'bug', :status => 'open' )
    assert_equal false, @project.transitions.find_by_name('fix bug').available_to?(card)
  end

  def test_should_update_transition_with_specified_group_prerequisites
    group = create_group('devs')
    transition = create_transition(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    card = create_card!(:name => 'card for test', :old_type => 'bug', :status => 'open' )
    another_group = create_group('another group', [@member_user])
    
    post :update, :project_id => @project.identifier, 
         :id => transition.id,
         :transition => {:name => transition.name}, 
         :requires_properties => {"status" => 'open', "old_type" => "bug" }, 
         :sets_properties => {"status" => "fixed"},
         :group_prerequisites => {'0' => another_group.id.to_s }, 
         :used_by => TransitionsController::SELECTED_GROUPS
    assert_response :redirect
    
    perform_as('member@email.com') do
      assert_equal true, transition.reload.available_to?(card)
    end
  end
  
  def test_should_show_detail_message_when_the_prerequisites_is_empty_on_list
    create_transition(@project, 'fixed whatever', :set_properties => {:status => 'fixed'})
    get :list, :project_id => @project.identifier
    assert_select 'td', :text => "Any value for any property"
  end
  
  def test_should_show_all_card_types_in_drop_down_on_list
    get :list, :project_id => @project.identifier
    
    assert_response :success
    assert_select "select#card-types-filter>option", :count => @project.card_types.count + 1
  end
  
  def test_list_transitions_using_plv
    status = @project.find_property_definition('status')
    create_plv!(@project, :name => 'current status', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id], :value => 'open')
    create_transition(@project.reload, 'fixed whatever with plv', :set_properties => {status.name => 'fixed'}, :required_properties => {status.name => '(current status)'})
    get :list, :project_id => @project.identifier
    assert_response :success
  end
  
  def test_should_flash_error_when_user_try_to_create_dummy_transition
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {"status" => PropertyValue::IGNORED_IDENTIFIER, "old_type" => PropertyValue::IGNORED_IDENTIFIER }, 
         :sets_properties => {"status" => PropertyValue::IGNORED_IDENTIFIER }, 
         :user_prerequisites => {'0' => @admin.id.to_s }
    assert_template 'new'
    assert_nil @project.transitions.find_by_name('fix bug')
  end
  
  def test_new_should_display_none_group_message_when_there_is_no_group
    get :new, :project_id => @project.identifier
    
    assert_select '#group-list table', :count => 0
    assert_select '#group-list span', :text => /There are no groups in the project./
  end
  
  def test_new_should_display_none_team_member_message_when_there_is_team_member
    login_as_admin
    with_new_project do |project|
      get :new, :project_id => project.identifier

      assert_select '#member-list table', :count => 0
      assert_select '#member-list span', :text => /There are no team members in the project./
    end
  end
  
  def test_should_update_transition_with_prerequisites_and_actions
    story_card =create_card!(:name => 'card for test', :old_type => 'story')
    bug_card =create_card!(:name => 'card for test', :old_type => 'bug')
    
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'}   
         
    transition = @project.transitions.find_by_name('fix bug')
    assert transition.available_to?(bug_card)
    
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => {:name => 'finish story'},
                  :requires_properties => {'old_type' => 'story'},
                  :sets_properties => {'status' => 'done'}
    transition.reload
    transition.clear_cached_results_for :prerequisites_collection
    assert_equal 'finish story', transition.name
    assert transition.available_to?(story_card)
    assert !transition.available_to?(bug_card)
    transition.execute(story_card)
    assert_equal 'done', story_card.cp_status
  end

  def test_should_be_able_to_create_a_transition_with_any_value_prerequisite
    story_card =create_card!(:name => 'card for test', :old_type => 'story')
    bug_card = create_card!(:name => 'card for test', :old_type => 'bug')
    no_old_type_card = create_card!(:name => 'card for test')
    
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'foo'}, 
         :requires_properties => {'old_type' => PropertyValue::SET_VALUE}, 
         :sets_properties => {'status' => 'open'}
    
    assert_response :redirect
    transition = @project.transitions.find_by_name('foo')
    assert transition.available_to?(bug_card)
    assert transition.available_to?(story_card)
    assert !transition.available_to?(no_old_type_card)
  end
  
  def test_should_be_able_to_update_a_transition_to_use_any_value_prerequisiste  
    story_card = create_card!(:name => 'card for test', :old_type => 'story')
    bug_card = create_card!(:name => 'card for test', :old_type => 'bug')
    no_old_type_card = create_card!(:name => 'card for test')
    transition = create_transition(@project, 'foo', :required_properties => {:old_type => 'bug'}, :set_properties => {:status => 'open'})
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => {:name => 'foo'},
                  :requires_properties => {'old_type' => PropertyValue::SET_VALUE},
                  :sets_properties => {'status' => 'open'}
    transition.reload
    transition.clear_cached_results_for :prerequisites_collection
    assert transition.available_to?(story_card)
    assert transition.available_to?(bug_card)
    assert !transition.available_to?(no_old_type_card)
    transition.execute(story_card)
    assert_equal 'open', story_card.cp_status
  end
  
  def test_can_edit_any_value_prerequisite
    cp_old_type = @project.find_property_definition('old_type')
    transition = create_transition(@project, 'foo', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    get :edit, :project_id => @project.identifier, :id => transition.id
    assert_response :success
    assert_select "a##{cp_old_type.class.name.downcase}_#{cp_old_type.id}_requires_drop_link", :text => PropertyValue::SET
  end
  
  def test_should_redirect_to_edit_and_show_message_when_update_failed
    story_card =create_card!(:name => 'card for test', :old_type => 'story')
    bug_card =create_card!(:name => 'card for test', :old_type => 'bug')
    
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'}
         
    transition = @project.transitions.find_by_name('fix bug')
    
    post :update, :project_id => @project.identifier, :id => transition.id, 
         :transition => {:name => 'bar'}, 
         :requires_properties => {}, 
         :sets_properties => {}
    assert_rollback
    assert_template 'edit'
  end
  
  def test_update_user_prerequisites
    bug_card =create_card!(:name => 'card for test', :old_type => 'bug')
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'}
    transition = @project.transitions.find_by_name('fix bug')
    post :update, :project_id => @project.identifier, :id => transition.id, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'},
         :user_prerequisites => {'0' => @admin.id.to_s }, 
         :used_by => TransitionsController::SELECTED_MEMBERS
    assert !transition.reload.available_to?(bug_card)
    login_as_admin
    assert transition.reload.available_to?(bug_card)
  end
  
  def test_should_provide_error_when_selecting_a_transition_to_be_available_to_specific_users_without_explicitly_selecting_any
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {}, 
         :sets_properties => {"status" => "fixed"},
         :user_prerequisites => {}, 
         :used_by => TransitionsController::SELECTED_MEMBERS
    assert_template "new"
    assert_nil @project.transitions.find_by_name('fix bug')
  end
  
  def test_create_transition_should_keep_the_input_data_when_it_failed_because_user_doesnt_select_any_team_member
    post :create,  :project_id => @project.identifier, 
                   :transition => {:name => 'fix bug'}, 
                   :used_by => TransitionsController::SELECTED_MEMBERS,
                   :sets_properties => {"status" => "fixed"}
    assert_response :success
    transition = assigns(:transition)
    assert_equal 'fix bug', transition.name
    assert_checked "#show-members", true
  end
  
  def test_update_transition_should_keep_the_input_data_when_it_failed_because_user_doesnt_select_any_team_member
    transition = create_transition(@project, 'finish bug', :set_properties => {:status => 'done'})
    
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => {:name => 'finish story'},
                  :used_by  => TransitionsController::SELECTED_MEMBERS,
                  :sets_properties => {'status' => 'done'}
    assert_response :success
    transition = assigns(:transition)
    assert_equal 'finish story', transition.name
    assert_checked "#show-members", true
  end
  
  def test_choose_selected_member_option_but_select_none_team_member_should_cause_error_when_update
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'}
    transition = @project.transitions.find_by_name('fix bug')
    post :update, :project_id => @project.identifier,
         :id => transition.id,
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {}, 
         :sets_properties => {"status" => "fixed"},
         :used_by => TransitionsController::SELECTED_MEMBERS
    assert_template "edit"
  end

  def test_create_transition_should_keep_the_input_data_when_it_failed_because_user_doesnt_select_any_group
    post :create,  :project_id => @project.identifier, 
                   :transition => {:name => 'fix bug'}, 
                   :used_by => TransitionsController::SELECTED_GROUPS,
                   :sets_properties => {"status" => "fixed"}
    assert_response :success
    transition = assigns(:transition)
    assert_equal 'fix bug', transition.name
    assert_checked "#show-groups", true
  end
  
  def test_update_transition_should_keep_the_input_data_when_it_failed_because_user_doesnt_select_any_group
    transition = create_transition(@project, 'finish bug', :set_properties => {:status => 'done'})
    
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => {:name => 'finish story'},
                  :used_by  => TransitionsController::SELECTED_GROUPS,
                  :sets_properties => {'status' => 'done'}
    assert_response :success
    transition = assigns(:transition)
    assert_equal 'finish story', transition.name
    assert_checked "#show-groups", true
  end
  
  # Bug 1290
  def test_transition_should_be_available_for_all_specified_team_memebers
    bug_card =create_card!(:name => 'card for test', :old_type => 'bug')
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug'}, 
         :requires_properties => {'old_type' => 'bug'}, 
         :sets_properties => {'status' => 'open'},
         :user_prerequisites => {'0' => @admin.id.to_s, '1' => @member_user.id.to_s, '2' => @proj_admin.id.to_s }, 
         :used_by => TransitionsController::SELECTED_MEMBERS
    transition = @project.transitions.find_by_name('fix bug')
    assert transition.reload.available_to?(bug_card)
    login_as_admin
    assert transition.reload.available_to?(bug_card)
    login_as_member
    assert transition.reload.available_to?(bug_card)
  end
  
  def test_save_card_type
    post :create, :project_id => @project.identifier, 
         :transition => {:name => 'fix bug', :card_type_name => @project.card_types.first.name}, 
         :requires_properties => {"status" => 'open'}, 
         :sets_properties => {"status" => "fixed"}
    assert_response :redirect
  
    assert_equal @project.card_types.first, @project.reload.transitions.find_by_name('fix bug').card_type
  end
  
  def test_should_save_enumeration_values_added_during_creation_of_transition
    status = @project.find_property_definition('status')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    original_count = status.enumeration_values.size
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => "brandnewvalue"},
         :sets_properties => {"status" => "brandnewvalue2"}
    
    @project.clear_enumeration_values_cache
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    assert original_count + 2, status.enumeration_values.size
  end
  
  def test_should_save_enumeration_values_added_during_update_of_transition
    status = @project.find_property_definition('status')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    original_count = status.enumeration_values.size
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => "open"},
         :sets_properties => {"status" => "fixed"}
    
    transition = @project.transitions.find_by_name('whatever')
    
    post :update, :project_id => @project.identifier,
         :id => transition.id,
         :transition => {:name => 'whatever'}, 
         :requires_properties => {"status" => "brandnewvalue"},
         :sets_properties => {"status" => "brandnewvalue2"}
    
    @project.clear_enumeration_values_cache
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    assert original_count + 2, status.enumeration_values.size
  end
  
  # bug 2256
  def test_should_save_enumeration_values_added_during_creation_of_transition_if_locked_but_user_is_admin
    status = @project.find_property_definition('status')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    original_count = status.enumeration_values.size
    
    status.update_attributes(:restricted => true)
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => "brandnewvalue"},
         :sets_properties => {"status" => "brandnewvalue2"}
    
    @project.clear_enumeration_values_cache
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue2')
    assert original_count + 2, status.enumeration_values.size
  end
  
  def test_should_not_save_enumeration_values_that_are_set_to_ignore
    status = @project.find_property_definition('status')
    assert !status.enumeration_values.collect(&:value).include?('brandnewvalue')
    original_count = status.enumeration_values.size
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => PropertyValue::IGNORED_IDENTIFIER},
         :sets_properties => {"status" => "brandnewvalue"}
    
    @project.clear_enumeration_values_cache
    assert status.enumeration_values.collect(&:value).include?('brandnewvalue')
    assert !status.enumeration_values.collect(&:value).include?(PropertyValue::IGNORED_IDENTIFIER)
    assert original_count + 1, status.enumeration_values.size
  end
  
  def test_should_not_save_enumeration_values_that_are_set_to_require_user_to_enter
    status = @project.find_property_definition('status')
    assert !status.contains_value?(Transition::USER_INPUT_REQUIRED)
    original_count = status.enumeration_values.size
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => 'brandnewvalue'},
         :sets_properties => {"status" => Transition::USER_INPUT_REQUIRED}
    
    @project.clear_enumeration_values_cache
    assert status.contains_value?('brandnewvalue')
    assert !status.contains_value?(Transition::USER_INPUT_REQUIRED)
    assert original_count + 1, status.enumeration_values.size
  end
  
  def test_should_not_save_enumeration_values_that_are_set_to_user_input_optional
    status = @project.find_property_definition('status')
    assert !status.contains_value?(Transition::USER_INPUT_OPTIONAL)
    original_count = status.enumeration_values.size
    
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
         :requires_properties => {"status" => 'brandnewvalue'},
         :sets_properties => {"status" => Transition::USER_INPUT_OPTIONAL}
    
    @project.clear_enumeration_values_cache
    assert status.contains_value?('brandnewvalue')
    assert !status.contains_value?(Transition::USER_INPUT_OPTIONAL)
    assert original_count + 1, status.enumeration_values.size
  end
  
  def test_list_should_display_user_input_optional_card_properties
    init_planning_tree_types
    create_three_level_tree
    release_type, iteration_type, story_type = find_planning_tree_types
    transition = create_transition(@project, 'user input optional', :card_type => story_type, :set_properties => {:'Planning iteration' => Transition::USER_INPUT_OPTIONAL})
    get :list, :project_id => @project.identifier
    
    assert_select "td.transition-to" do
      assert_select "span.property-value", :text => Transition::USER_INPUT_OPTIONAL
      assert_select "span.property-name", :text => 'Planning iteration:'
    end
  end
  
  def test_should_redirect_to_new_page_when_the_set_properties_is_empty
    @project.card_types.create(:name => 'bug')
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'whatever', :card_type_name => 'bug'}
    assert_response :success
  end
  
  def test_should_create_transition_with_project_variable_in_required_properties
    current_iteration = create_plv!(@project, :name => 'current iteration', :value => 4, :data_type => ProjectVariable::STRING_DATA_TYPE)
    current_iteration.property_definitions = [@project.find_property_definition('iteration')]
    current_iteration.save!
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'close current iteration', :card_type_name => 'card'},
         :requires_properties => {:iteration => current_iteration.display_name},
         :sets_properties => {:status => 'closed'}
    assert_response :redirect
    transition = @project.transitions.find_by_name('close current iteration')
    assert_equal current_iteration.name, transition.prerequisites.first.project_variable.name
  end
  
  def test_should_create_transition_with_project_variable_in_sets_properties
    current_iteration = create_plv!(@project, :name => 'current iteration', :value => 4, :data_type => ProjectVariable::STRING_DATA_TYPE)
    current_iteration.property_definitions = [@project.find_property_definition('iteration')]
    current_iteration.save!
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'set to current iteration', :card_type_name => 'card'},
         :sets_properties => {:iteration => current_iteration.display_name}
     assert_response :redirect
     transition = @project.transitions.find_by_name('set to current iteration')
     assert_equal current_iteration, transition.actions.first.variable_binding.project_variable
  end
  
  # bug 2978   
  def test_invalid_numeirc_value_should_not_be_lowercased_in_error_messages
     setup_numeric_property_definition('size', ['2', '4'])
     post :create, :project_id => @project.identifier,
          :transition => {:name => 'whatever', :card_type_name => @project.card_types.first.name},
          :sets_properties => {"size" => '4DD'}
     assert_error "Property to set <b>size</b>: <b>4DD</b> is an invalid numeric value"
  end
  
  # bug 3684
  def test_error_messages_are_not_duplicated_when_updating_transition_action_to_value_with_braces
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'fix bug'},
         :sets_properties => {'status' => 'fixed'}
    
    transition = @project.transitions.find_by_name('fix bug')
    
    post :update, :project_id => @project.identifier,
                  :id => transition.id,
                  :transition => {:name => 'fix bug'},
                  :requires_properties => {'status' => '(foo)'},
                  :sets_properties => {'status' => '(bar)'}
    
    assert_error "status: <b>(foo)</b> is an invalid value. Value cannot both start with '(' and end with ')'. status: <b>(bar)</b> is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."
  end
  
  def test_should_create_transition_with_tree_belonging_actions
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      post :create, :project_id => project.identifier,
           :transition => {:name => 'remove something', :card_type_name => 'iteration'},
           :sets_tree_belongings => {"#{tree.id}" => TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE}
      assert_response :redirect
      
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      
      assert tree.include_card?(iteration1)
      project.transitions.find_by_name('remove something').execute(iteration1)
      assert !tree.include_card?(iteration1)
      assert tree.include_card?(story1)
      assert tree.include_card?(story2)
    end
  end
  
  def test_should_create_transition_that_can_remove_a_card_from_a_tree_with_children
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      post :create, :project_id => project.identifier,
           :transition => {:name => name = 'remove card and children', :card_type_name => 'iteration'},
           :sets_tree_belongings => {"#{tree.id}" => TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE}
      assert_response :redirect
      
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      
      assert tree.include_card?(iteration1)
      project.transitions.find_by_name(name).execute(iteration1)
      assert !tree.include_card?(iteration1)
      assert !tree.include_card?(story1)
      assert !tree.include_card?(story2)
    end
  end
  
  def test_list_should_display_remove_from_tree_action_description
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      iteration = project.card_types.find_by_name('iteration')
      transition = create_transition(project, 'tree belongings just this card', :card_type => iteration, :remove_from_trees => [tree])
      get :list, :project_id => project.identifier
      assert_select "span.property-value", :text => TreeBelongingPropertyDefinition::JUST_THIS_CARD_TEXT
    end
  end
  
  def test_list_should_display_remove_from_tree_with_children_action_description
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      release = project.card_types.find_by_name('release')
      transition = create_transition(project, 'tree belongings this card with children', :card_type => release, :remove_from_trees_with_children => [tree])
      get :list, :project_id => project.identifier
      assert_select "td.transition-to" do
        assert_select "span.property-value", :text => TreeBelongingPropertyDefinition::WITH_CHILDREN_TEXT
        assert_select "span.property-name", :text => tree.name + ' tree:'
      end
    end
  end
  
  def test_can_edit_remove_from_tree_transition
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      release = project.card_types.find_by_name('release')
      transition = create_transition(project, 'hey now', :card_type => release, :remove_from_trees => [tree])
      get :edit, :project_id => project.identifier, :id => transition.id
      assert_response :success
    end
  end
  
  def test_should_be_able_to_clear_tree_belongings_actions
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      story = project.card_types.find_by_name('story')
      transition = create_transition(project, name = 'say now', :card_type => story, :remove_from_trees => [tree])
      post :update, :project_id => project.identifier,
                    :id => transition.id,
                    :transition => {:name => name},
                    :sets_tree_belongings => {tree.id.to_s => PropertyValue::IGNORED_IDENTIFIER}
      assert_response :success
      assert_error "Transition must #{'set'.html_bold} at least one property."
    end
  end
  
  def test_tree_belonging_actions_should_also_reveal_relationship_property_information_on_the_list_only_for_types_above
    create_tree_project :init_three_level_tree do |project, tree_view, tree|
      iteration_type = project.card_types.find_by_name('iteration')
      transition = create_transition(project, name = 'say now', :card_type => iteration_type, :remove_from_trees => [tree])
      get :list, :project_id => project.identifier
      assert_select "span.property-name", :text => 'Planning release:'
      assert_select "span.property-name", :text => 'Planning iteration:', :count => 0
    end
  end
  
  def test_transition_cannot_be_used_in_bulk_message_appears_correctly
    input_optional_transition = create_transition(@project, 'raisins', :set_properties => {'status' => Transition::USER_INPUT_OPTIONAL})
    input_required_transition = create_transition(@project, 'grapes', :set_properties => {'status' => Transition::USER_INPUT_REQUIRED})
    input_mixed_transition = create_transition(@project, 'wine', :set_properties => {'status' => Transition::USER_INPUT_REQUIRED, 'iteration' => Transition::USER_INPUT_OPTIONAL})
    get :list, :project_id => @project.identifier
    
    assert_select "div#transition-#{input_required_transition.id}" do
      assert_select "p", :text => "This transition cannot be activated using the bulk transitions panel because at least one property is set to #{Transition::USER_INPUT_REQUIRED}."
    end
    
    assert_select "div#transition-#{input_optional_transition.id}" do
      assert_select "p", :text => "This transition cannot be activated using the bulk transitions panel because at least one property is set to #{Transition::USER_INPUT_OPTIONAL}."
    end
    
    assert_select "div#transition-#{input_mixed_transition.id}" do
      assert_select "p", :text => "This transition cannot be activated using the bulk transitions panel because properties are set to #{Transition::USER_INPUT_REQUIRED} and #{Transition::USER_INPUT_OPTIONAL}."
    end
  end
  
  def test_transition_cannot_be_used_in_bulk_info_box_appears_for_user_input_optional_case
    post :create, :project_id => @project.identifier,
         :transition => {:name => 'make sandwich'},
         :sets_properties => {"status" => Transition::USER_INPUT_OPTIONAL}
    follow_redirect
    assert_info "Transition #{'make sandwich'.html_bold} cannot be activated using the bulk transitions panel because some properties are set to #{Transition::USER_INPUT_REQUIRED} or #{Transition::USER_INPUT_OPTIONAL}."
  end
  
  def test_transition_list_with_no_transitions_will_say_that_there_are_no_transitions_to_list_and_offer_links_if_user_is_admin
    get :list, :project_id => @project.identifier
    assert_select "div#no-transition-message", :text => "There are currently no transitions to list. You can create a new transition or generate a new transition workflow."
    
    login_as_member
    get :list, :project_id => @project.identifier
    assert_select "div#no-transition-message", :text => "There are currently no transitions to list."
  end

  def test_destroy_should_delete_and_render
    transition = create_transition(@project, 'fixed whatever', :set_properties => {:status => 'fixed'})

    assert_difference "Transition.count", -1 do
      post :destroy, :project_id => @project.identifier, :id => transition.id
      assert_response :redirect
      follow_redirect
    end
    assert_equal "Transition #{'fixed whatever'.bold} was successfully deleted", flash[:notice]
  end
  
  def test_list_transtions_as_xml_format
    @transition = create_transition(@project, 'fixed whatever', :set_properties => {:status => 'fixed'})
    get :index, :project_id => @project.identifier, :format => 'xml'
    xml = @response.body
    assert_equal 1, get_number_of_elements(xml, "//transitions")
    assert_equal @transition.id, get_element_text_by_xpath(xml, "//transitions/transition/id").to_i
  end

  def test_show_transition_as_xml_format
    @transition = create_transition(@project, 'fixed whatever', :set_properties => {:status => 'fixed'})
    get :show, :project_id => @project.identifier, :format => 'xml', :id => @transition.id
    xml = @response.body
    assert_equal 1, get_number_of_elements(xml, "//transition")
    assert_equal @transition.id, get_element_text_by_xpath(xml, "//transition/id").to_i
  end
  
  def test_transition_with_in_group_prerequisite_needs_at_least_one_group_to_be_specified
    post :create, :project_id => @project.identifier, 
                  :transition => {:name => 'fix bug'}, 
                  :used_by => TransitionsController::SELECTED_GROUPS,
                  :sets_properties => {"status" => "fixed"}
    assert_equal "Please select at least one group", flash[:error]         
  end

  def test_should_show_currently_selected_groups_on_transition_edit
    jimmy_group = create_group "jimmy"
    timmy_group = create_group "timmy"
    @transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'}, :group_prerequisites => [jimmy_group.id])
    get :edit, :project_id => @project.identifier, :id => @transition.id

    assert_checked '#show-groups', :count => 1
    assert_checked "#group_prerequisites_#{jimmy_group.id}", :count => 1
    assert_checked "#group_prerequisites_#{timmy_group.id}", :count => 0
  end

  def test_should_update_transition_to_contain_additional_group_execution_permissions
    jimmy_group = create_group "jimmy"
    timmy_group = create_group "timmy"
    @transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'}, :group_prerequisites => [jimmy_group.id])
    
    post :update, :project_id => @project.identifier, 
                  :id => @transition.id,
                  :transition => {:name => 'fix bug'},
                  :used_by => TransitionsController::SELECTED_GROUPS,
                  :group_prerequisites => {"0" => jimmy_group.id.to_s, "1" => timmy_group.id.to_s},
                  :sets_properties => {"status" => "fixed"}
    
    assert @transition.reload.uses_group?(jimmy_group)
    assert @transition.reload.uses_group?(timmy_group)
  end

  def test_should_update_transition_to_delete_groups_removed_during_an_update
    jimmy_group = create_group "jimmy"
    timmy_group = create_group "timmy"
    @transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'}, :group_prerequisites => [jimmy_group.id, timmy_group.id])
    
    post :update, :project_id => @project.identifier, 
                  :id => @transition.id,
                  :transition => {:name => 'fix bug'},
                  :used_by => TransitionsController::SELECTED_GROUPS,
                  :group_prerequisites => {"0" => timmy_group.id.to_s},
                  :sets_properties => {"status" => "fixed"}
    
    assert_equal false, @transition.reload.uses_group?(jimmy_group)
    assert_equal true, @transition.reload.uses_group?(timmy_group)
  end
  
  def test_should_be_available_to_all_users_upon_deletion_of_the_last_group_that_it_is_available_to
    group = create_group('group')
    transition_with_in_group = create_transition(@project, 'with group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    group.destroy
    
    get :edit, :project_id => @project.identifier, :id => transition_with_in_group.id
    assert_checked '#all_team_members', :count => 1
  end


  def test_new_should_display_transition_to_channel_mappings_options
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'

    mapped_channels = [
        {:name => public_channel_name, :id => '1', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => '1', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true, :transitions => {1 => 'channel1', 2 => 'channel2'} })

      get :new, :project_id => @project.identifier
      assert_select '#transition_to_slack_channel_mapping'
      assert_select '#selected_slack_channel_id option', :count => 3
      assert_select '#selected_slack_channel_id optgroup', :count => 2
    end
  end

  def test_new_should_not_display_transition_to_channel_mappings_options_when_tenant_is_not_integrated
    login_as_proj_admin

    tenant_name = 'tenant'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})

      get :new, :project_id => @project.identifier
      assert_select '#transition_to_slack_channel_mapping', :count => 0
      assert_select '#selected_slack_channel_id option', :count => 0
    end
  end

  def test_new_should_not_display_transition_to_channel_mappings_options_when_team_is_not_mapped
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'

    mapped_channels = [
        {:name => public_channel_name, :id => '1', :mapped => true, :teamId => 123456, :private => false, },
        {:name => private_channel_name, :id => '1', :mapped => true, :teamId => 123457, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => false })

      get :new, :project_id => @project.identifier
      assert_select '#transition_to_slack_channel_mapping', :count => 0
      assert_select '#selected_slack_channel_id option', :count => 0
    end
  end

  def test_new_should_not_display_transition_to_channel_mappings_options_when_toggled_off
    login_as_proj_admin

    tenant_name = 'tenant'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        transition_to_channel_mapping_enabled: 'false') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})

      get :new, :project_id => @project.identifier
      assert_select '#transition_to_slack_channel_mapping' , :count => 0
      assert_select '#selected_slack_channel_id option', :count => 0
    end
  end

  def test_edit_should_display_transition_to_channel_mappings_options
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true})

      transition = create_transition(@project, 'foo', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
      get :edit, :project_id => @project.identifier, :id => transition.id
      assert_select '#selected_slack_channel_id[disabled]', false
      assert_select '#selected_slack_channel_id option[selected]', :count => 0
      assert_select '#transition_to_slack_channel_mapping option'
      assert_select '#selected_slack_channel_id option', :count => 3
      assert_select '#selected_slack_channel_id optgroup', :count => 2
    end
  end

  def test_edit_should_display_disabled_select_drop_down_if_user_does_not_have_access_to_the_selected_channel
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    transition = create_transition(@project, 'foo', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false }
    ]

    transitions = {transition.id.to_s => 'privateChannelId', 23.to_s => 'anotherPrivateChannelId' }

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true, :transitions => transitions })

      get :edit, :project_id => @project.identifier, :id => transition.id
      assert_select '#selected_slack_channel_id[disabled]'
      assert_select '#selected_slack_channel_id option[selected]', :text => 'private channel'
      selected_channel = css_select '#is_selected_channel_inaccessible'
      assert_equal 'true', selected_channel.first.attributes['value']
    end
  end


  def test_edit_should_display_mapped_channel_as_default
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'
    transition = create_transition(@project, 'foo', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    transitions = {transition.id.to_s => 'publicChannelId', 23.to_s => 'privateChannelId' }

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true, :transitions => transitions })

      get :edit, :project_id => @project.identifier, :id => transition.id

      assert_select '#selected_slack_channel_id option[selected]', :text => 'publicChannel'
      assert_select '#transition_to_slack_channel_mapping option'
      assert_select '#selected_slack_channel_id option', :count => 3
      assert_select '#selected_slack_channel_id optgroup', :count => 2
      selected_channel = css_select '#is_selected_channel_inaccessible'
      assert_equal 'false', selected_channel.first.attributes['value']
    end
  end

  def test_list_should_display_information_related_to_transition_mapping
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'
    transition1 = create_transition(@project, 'transition1', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    transition2 = create_transition(@project, 'transition2', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    transition3 = create_transition(@project, 'transition3', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    transition4 = create_transition(@project, 'transition4', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    transitions = {transition1.id.to_s => 'publicChannelId', transition2.id.to_s => 'privateChannelId', transition4.id.to_s => 'inaccessiblePrivateChannelId' }

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true, :transitions => transitions })

      get :list, :project_id => @project.identifier
      assert_select "#transition-#{transition1.id} .mapped_slack_channel", :text => /This transition is mapped to/
      assert_select "#transition-#{transition1.id} .mapped_slack_channel", :text => /publicChannel/
      assert_select "#transition-#{transition2.id} .mapped_slack_channel", :text => /This transition is mapped to/
      assert_select "#transition-#{transition2.id} .mapped_slack_channel", :text => /privateChannel/
      assert_select "#transition-#{transition3.id} .mapped_slack_channel", :text => 'This transition is not mapped to any channel'
      assert_select "#transition-#{transition4.id} .mapped_slack_channel", :text => /a private channel/
    end
  end


  def test_list_should_not_display_information_related_to_transition_mapping_when_team_is_not_mapped
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'
    create_transition(@project, 'transition1', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    create_transition(@project, 'transition2', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => 123456, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => 123457, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => false, :transitions => {} })

      get :list, :project_id => @project.identifier
      assert_select '.mapped_slack_channel', :count => 0
    end
  end

  def test_list_should_not_display_information_related_to_transition_mapping_when_toggled_off
    login_as_proj_admin

    tenant_name = 'tenant'

    create_transition(@project, 'transition1', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})
    create_transition(@project, 'transition2', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        transition_to_channel_mapping_enabled: 'false') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})

      get :list, :project_id => @project.identifier
      assert_select '.mapped_slack_channel', :count => 0
    end
  end

  def test_should_create_transition_with_channel_mapping_and_redirect_back_to_list_page_with_previously_filtered_criteria
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    tenant_name = 'tenant'
    selected_slack_channel = 'privateChannelId'
    created_transition_id = nil

    MingleConfiguration.overridden_to( app_namespace: tenant_name,
                                       transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.expects(:map_transition).with do |tenant, team_id, channel_id, transition_id|
        tenant == tenant_name
        team_id == @project.team.id
        selected_slack_channel == channel_id
        created_transition_id = transition_id
      end.returns({ok: true})

      post :create, :project_id => @project.identifier,
           :transition => {:name => 'fix bug'},
           :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER },
           :sets_properties => {"status" => "fixed"},
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id },
           :selected_slack_channel_id => selected_slack_channel,
           :previously_selected_slack_channel_id => ''

      assert_redirected_to :action => :list, :created_transition_id => @project.transitions.first.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
      assert_not_nil(created_transition_id)
      assert_equal(created_transition_id, @project.transitions.find_by_name('fix bug').id)
    end

  end

  def test_should_update_transition_with_channel_mapping_and_redirect_back_to_list_page_with_previously_filtered_criteria
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    tenant_name = 'tenant'
    selected_slack_channel = 'privateChannelId'
    old_slack_channel = 'oldChannelId'
    transition = create_transition(@project, 'fixed whatever', :set_properties => { :status => 'fixed' })

    MingleConfiguration.overridden_to( app_namespace: tenant_name,
                                       transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.expects(:map_transition).with do |tenant, team_id, channel_id, transition_id|
        tenant == tenant_name
        team_id == @project.team.id
        selected_slack_channel == channel_id
        transition.id = transition_id
      end.returns({ok: true})


      post :update, :project_id => @project.identifier,
           :id => transition.id,
           :transition => { :name => 'fixed whatever with new name' },
           :sets_properties => { 'status' => 'fixed' },
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id },
           :selected_slack_channel_id => selected_slack_channel,
           :previously_selected_slack_channel_id => old_slack_channel

      assert_redirected_to :action => :list, :updated_transition_id => transition.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    end
  end

  def test_should_post_flash_message_if_updation_of_channel_transition_fails
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    tenant_name = 'tenant'
    selected_slack_channel = 'privateChannelId'
    transition = create_transition(@project, 'fixed whatever', :set_properties => { :status => 'fixed' })

    MingleConfiguration.overridden_to( app_namespace: tenant_name,
                                       transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.expects(:map_transition).returns({ok: false, error: 'Failed'})


      post :update, :project_id => @project.identifier,
           :id => transition.id,
           :transition => { :name => 'alladsu' },
           :sets_properties => { 'status' => 'fixed' },
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id },
           :selected_slack_channel_id => selected_slack_channel,
           :previously_selected_slack_channel_id => ''

      assert_equal 'Transition alladsu was updated but slack channel failed to update: Failed', flash[:info]
    end
  end

  def test_save_should_not_call_map_transition_when_channel_is_not_changed
    login_as_proj_admin
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    tenant_name = 'tenant'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      post :create, :project_id => @project.identifier,
           :transition => {:name => 'fix bug'},
           :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER },
           :sets_properties => {"status" => "fixed"},
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id},
           :selected_slack_channel_id => 'AAA',
           :previously_selected_slack_channel_id => 'AAA'

      assert_redirected_to :action => :list, :created_transition_id => @project.transitions.first.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    end
  end

  def test_save_should_not_call_map_transition_when_selected_channel_is_not_accessible_for_current_user
    login_as_proj_admin
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    tenant_name = 'tenant'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      post :create, :project_id => @project.identifier,
           :transition => {:name => 'fix bug'},
           :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER },
           :sets_properties => {"status" => "fixed"},
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id},
           :selected_slack_channel_id => 'AAA',
           :previously_selected_slack_channel_id => 'AAB',
           :is_selected_channel_inaccessible => 'true'

      assert_redirected_to :action => :list, :created_transition_id => @project.transitions.first.id, :project_id => @project.identifier, :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id }
    end
  end

  def test_edit_should_display_transition_to_channel_mappings_options_when_update_fails
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    selected_slack_channel = 'publicChannelId'
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true})

      transition = create_transition(@project, 'foo', :required_properties => {:old_type => PropertyValue::SET_VALUE}, :set_properties => {:status => 'open'})

      post :update, :project_id => @project.identifier,
           :id => transition.id,
           :transition => { :name => '' },
           :sets_properties => { 'status' => 'fixed' },
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id },
           :selected_slack_channel_id => selected_slack_channel,
           :previously_selected_slack_channel_id => ''

      assert_select '#selected_slack_channel_id option[selected]', :text => public_channel_name
      assert_select '#transition_to_slack_channel_mapping option'
      assert_select '#selected_slack_channel_id option', :count => 3
      assert_select '#selected_slack_channel_id optgroup', :count => 2
    end
  end

  def test_new_should_display_transition_to_channel_mappings_options_when_create_fails
    selected_card_type = @project.card_types.first
    selected_property_definition = selected_card_type.property_definitions.first
    selected_slack_channel = 'publicChannelId'
    login_as_proj_admin

    tenant_name = 'tenant'
    public_channel_name = 'publicChannel'
    private_channel_name = 'privateChannel'

    mapped_channels = [
        {:name => public_channel_name, :id => 'publicChannelId', :mapped => true, :teamId => @project.team.id, :private => false, },
        {:name => private_channel_name, :id => 'privateChannelId', :mapped => true, :teamId => @project.team.id, :private => true, }
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==',
        saas_env: 'test',
        transition_to_channel_mapping_enabled: 'true') do

      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: tenant_name, url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:list_channels).returns({:channels => mapped_channels , :teamMapped => true})

      post :create, :project_id => @project.identifier,
           :transition => {:name => ''},
           :requires_properties => {"status" => 'open', "old_type" => "bug", "iteration" => PropertyValue::IGNORED_IDENTIFIER },
           :sets_properties => {"status" => "fixed"},
           :filter => { :card_type_id => selected_card_type.id, :property_definition_id => selected_property_definition.id},
           :selected_slack_channel_id => selected_slack_channel,
           :previously_selected_slack_channel_id => ''

      assert_select '#selected_slack_channel_id option[selected]', :text => public_channel_name
      assert_select '#transition_to_slack_channel_mapping option'
      assert_select '#selected_slack_channel_id option', :count => 3
      assert_select '#selected_slack_channel_id optgroup', :count => 2
    end
  end
end
