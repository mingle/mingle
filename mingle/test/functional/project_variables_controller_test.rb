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

class ProjectVariablesControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree
  def setup
    @controller = create_controller(ProjectVariablesController, :own_rescue_action => false)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @project = create_project
    login_as_admin
    setup_property_definitions(:Status => ['fixed', 'new', 'open', 'closed','in progress'])
    setup_property_definitions(:iteration => [1, 2, 3, 4, 5])
    setup_numeric_property_definition 'Release', ['1', '2']
  end

  def test_create
    status = @project.find_property_definition('status')
    post :create, :project_id => @project.identifier, :project_variable => {:name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'value', :property_definition_ids => [status.id.to_s]}
    
    assert_response :redirect
    assert_redirected_to :action => 'list'
    
    follow_redirect

    assert_notice "Project variable #{'variable'.html_bold} was successfully created."
    
    @project.reload
    assert_equal 1, @project.project_variables.size
    assert_equal 'variable', @project.project_variables.first.name
    assert_equal status, @project.project_variables.first.property_definitions.first
  end
  
  def test_should_trim_name_and_value
    post :create, :project_id => @project.identifier, :project_variable => {:name => 'v    ariable  ', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'v al   ue  '}
    assert_equal 'v ariable', @project.project_variables.last.name
    assert_equal 'v al ue', @project.project_variables.last.value
  end
  
  def test_create_with_errors
    post :create, :project_id => @project.identifier, :project_variable => {:name => nil}
    
    assert_response :success
    assert_template 'new'
    
    assert_error 'Name can\'t be blank'
    
    @project.reload
    assert_equal 0, @project.project_variables.size
  end
  
  def test_list
    create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]')
    create_plv!(@project, :name => 'Variable2', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable2[value]')
    
    get :list, :project_id => @project.identifier
    assert_response :success
    
    assert_select 'td', :text => "(Variable1)\n            Text"
    assert_select 'td', :text => 'Variable1[value]'
    assert_select 'td', :text => "(Variable2)\n            Text"
    assert_select 'td', :text => 'Variable2[value]'
  end
  
  def test_update_available_property_definitions_without_project_variable_id
    xhr :get, :select_data_type, :project_id => @project.identifier, :project_variable => {:data_type => ProjectVariable::STRING_DATA_TYPE}
    assert_response :success
    assert @response.body.include?(@project.find_property_definition('status').html_id)
    assert !@response.body.include?(@project.find_property_definition('Release').html_id)
  end
  
  def test_update_available_property_definitions_with_existed_project_variable_id
    variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]')
    xhr :get, :select_data_type, :project_id => @project.identifier, :project_variable => {:data_type => ProjectVariable::NUMERIC_DATA_TYPE}
    assert_response :success
    assert !@response.body.include?(@project.find_property_definition('status').html_id)
    assert @response.body.include?(@project.find_property_definition('Release').html_id)
  end
  
  def test_delete
    @project.connection.execute("delete from variable_bindings")
    status_prop = @project.find_property_definition('status')
    variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]', :property_definition_ids => [status_prop.id])
    post :delete, :project_id => @project.identifier, :id => variable.id.to_s
    
    assert_response :redirect
    assert_redirected_to :action => 'list'

    @project.reload
    assert_equal 0, @project.project_variables.size
    assert @project.connection.select_all("select project_variable_id from variable_bindings").empty?
  end
  
  def test_should_clear_property_definitions_when_property_definition_ids_is_nil
    status_prop = @project.find_property_definition('status')
    variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]', :property_definition_ids => [status_prop.id])
    
    post :update, :project_id => @project.identifier, :id => variable.id, :project_variable => {:name => variable.name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 1}
    assert_response :redirect
    
    variable.reload
    assert_equal [], variable.property_definitions
  end
  
  def test_confirm_delete_warns_that_transitions_will_be_deleted
    status_prop = @project.find_property_definition('status')
    variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]', :property_definition_ids => [status_prop.id.to_s])
    transition_uses_project_variable = create_transition(@project, 'set status', :set_properties => {:status => variable.display_name})
    post :confirm_delete, :project_id => @project.identifier, :id => variable.id.to_s
    
    assert_select "li", "The following 1 transition will be deleted: #{transition_uses_project_variable.name}."
  end
  
  #bug 3648
  def test_confirm_propogates_card_type_id_over
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      release = project.find_property_definition('planning release')
      release1 = project.cards.find_by_name('release1')
      post :create, :project_id => project.identifier, 
        :project_variable => {:name  =>  'current thing', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => release1.id, :property_definition_ids =>[release.id.to_s], :card_type => type_release }
      
      variable = project.project_variables.find_by_name('current thing')
      view_using_current_iteration = CardListView.find_or_construct(project, :filters => ["[Type][is][story]", "[planning release][is][(current thing)]"])
      view_using_current_iteration.name = 'foo'
      view_using_current_iteration.save!
      
      iteration = project.find_property_definition('planning iteration')
      iteration1 = project.cards.find_by_name('iteration1')
      post :confirm_update, :project_id => project.identifier, :id => variable.id.to_s, :project_variable => {:name => 'current thing', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => iteration1.id, :property_definition_ids =>[iteration.id.to_s], :card_type_id => type_iteration.id}
      assert_select "input[name='project_variable[card_type_id]']", :count => 1
    end
  end
  
  def test_confirm_delete_warns_that_team_view_will_be_deleted
    iteration = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id.to_s])
    team_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])    
    personal_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'my story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"], :user_id => User.current.id)    
    post :confirm_delete, :project_id => @project.identifier, :id => current_iteration.id.to_s
    assert_select "li", "The following 1 team favorite will be deleted: #{team_view_use_plv.name}."
  end
  
  def test_delete_actually_does_delete_both_personal_and_team_views
    iteration = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id.to_s])
    team_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])    
    personal_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'my story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"], :user_id => User.current.id)    
    post :delete, :project_id => @project.identifier, :id => current_iteration.id.to_s
    assert_equal [], @project.card_list_views
  end
  
  def test_change_name_value_should_rename_usages_in_mql_filters
    iteration = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id.to_s])
    view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => {:mql => "Type=story AND iteration = (current iteration)"})    
    post :confirm_update, :project_id => @project.identifier, :id => current_iteration.id.to_s, :project_variable => {:name => 'new name', :data_type => current_iteration.data_type, :value => '6', :property_definition_ids =>[ iteration.id.to_s]}
    assert_response :redirect
    assert_equal({:mql => "Type = story AND iteration = (new name)"}, @project.card_list_views.find_by_name('story wall').to_params[:filters])
  end
  
  def test_change_name_value_should_not_warn_transition_or_view_will_be_deleted
    iteration = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id.to_s])
    view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])    
    post :confirm_update, :project_id => @project.identifier, :id => current_iteration.id.to_s, :project_variable => {:name => 'I am release 6', :data_type => current_iteration.data_type, :value => '6', :property_definition_ids =>[iteration.id.to_s]}
    assert_response :redirect
  end
  
  def test_confirm_update_warns_that_transitions_will_be_deleted
    release = @project.find_property_definition('Release')
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5', :property_definition_ids => [release.id.to_s])
    transition_uses_current_release = create_transition(@project, 'set status', :set_properties => {:release => current_release.display_name})
    post :confirm_update, :project_id => @project.identifier, :id => current_release, :project_variable => {:name => current_release.name, :data_type => current_release.data_type, :value => current_release.value}
    
    assert_select 'li', "The following 1 transition will be deleted: #{transition_uses_current_release.name}."
  end
  
  def test_update_directly_when_there_are_no_transitions
    release = @project.find_property_definition('Release')
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5', :property_definition_ids => [release.id.to_s])
    post :confirm_update, :project_id => @project.identifier, :id => current_release, :project_variable => {:name => 'I am release 6', :data_type => current_release.data_type, :value => '6'}
    assert_response :redirect
    release_6 = @project.project_variables.find(current_release.id)
    assert_equal 'I am release 6', release_6.name
    assert_equal '6', release_6.value
  end
  
  def test_removing_property_definitions_from_project_variable_will_delete_appropriate_transitions
    release = setup_numeric_property_definition('release', [1, 2, 3])
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [release]
    current_release.save!
    
    transition = create_transition(@project, 'set to current release', 
                                              :set_properties => {:release => current_release.display_name})
                                              
    post :update, :project_id => @project.identifier, :id => current_release.id, :project_variable => {:name => current_release.name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 1}
    
    assert_nil @project.transitions.find_by_name(transition.name)
  end
  
  def test_project_variable_list_should_show_transition_count_in_each_row
    status_prop = @project.find_property_definition('status')
    variable = create_plv!(@project, :name => 'Variable1', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Variable1[value]', :property_definition_ids => [status_prop.id.to_s])
    transition_uses_project_variable = create_transition(@project, 'set status', :set_properties => {:status => variable.display_name})
    
    get :list, :project_id => @project.identifier
    assert_select "td", "no favorites, 1 transition"
  end
  
  def test_variable_value_is_added_to_enumeration_value_lists
    status = @project.find_property_definition('status')
    
    assert !status.contains_value?('value')
    post :create, :project_id => @project.identifier,
                  :project_variable => {:name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'value', :property_definition_ids => [status.id.to_s]}
    @project.clear_enumeration_values_cache
    assert status.reload.contains_value?('value')
    
    assert !status.contains_value?('value2')
    variable = @project.project_variables.find_by_name('variable')
    post :update, :project_id => @project.identifier, :id => variable.id,
                  :project_variable => {:name => variable.name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'value2', :property_definition_ids => [status.id.to_s]}
    @project.clear_enumeration_values_cache
    assert status.contains_value?('value2')
  end
  
  def test_create_project_variable_with_type_card
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration = project.find_property_definition('planning iteration')
      iteration1 = project.cards.find_by_name('iteration1')
      post :create, :project_id => project.identifier, 
        :project_variable => {:name  =>  'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => iteration1.id, :property_definition_ids =>[iteration.id.to_s], :card_type => type_iteration }
      assert_response(:redirect)
      current_iteration = project.project_variables.find_by_name('current iteration')  
      assert current_iteration
      assert_equal ProjectVariable::CARD_DATA_TYPE, current_iteration.data_type 
      assert_equal iteration1.id.to_s, current_iteration.value 
      assert_equal type_iteration, current_iteration.card_type 
      assert_equal [iteration], current_iteration.property_definitions 
    end
  end
  
  def test_should_change_saved_view_and_card_context_in_session_when_change_plv_name
    iteration_prop = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current it', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids => [iteration_prop.id.to_s])
    view = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current it)]"])
    @request.session["project-#{@project.id}"] = { 
          "last_tab"=> {:style=>"list", :filters=>["[Type][is][story]", "[iteration][is][(current it)]"], :action=>"list", :tab=>"All"}, 
          "last_tab_name"=>"All", 
          "current_list_navigation_card_numbers"=>[], 
          "All_tab"=>{"None"=>{:style=>"list", :filters=>["[Type][is][story]", "[iteration][is][(current it)]"], :action=>"list", :tab=>"All"}, "last_tree_name"=>"None"}, 
          "All_state_canonical_string"=>"filters=[iteration][is][(current it)],[type][is][story],style=list", 
          "page_tab"=>{}
        }
    
    post :update, :project_id => @project.identifier, :id => current_iteration.id,
                  :project_variable => {:name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids => [iteration_prop.id.to_s]}    
    
    
    view = @project.card_list_views.find_by_name('story wall')
    assert_equal ["[Type][is][story]", "[iteration][is][(current iteration)]"], view.to_params[:filters]
    assert_equal ["[Type][is][story]", "[iteration][is][(current iteration)]"], @request.session["project-#{@project.id}"]['last_tab'][:filters]
    assert_equal ["[Type][is][story]", "[iteration][is][(current iteration)]"], @request.session["project-#{@project.id}"]['All_tab']['None'][:filters]
    assert_equal "filters=[iteration][is][(current iteration)],[type][is][story],style=list", @request.session["project-#{@project.id}"]["All_state_canonical_string"]
  end

  def test_should_provide_all_card_relationship_property_definitions_for_applicable_property_definitions_for_a_card_plv_if_card_type_is_nil
    related_card = setup_card_relationship_property_definition('related card')
    other_related_card = setup_card_relationship_property_definition('other related card')

    variable = create_plv!(@project, :name => 'Jimmy', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => nil)

    get :edit, :project_id => @project.identifier, :id => variable.id
    assert_select "td#project_variable_property_name_#{related_card.id}", :count => 1, :text => 'related card'
    assert_select "td#project_variable_property_name_#{other_related_card.id}", :count => 1, :text => 'other related card'
  end

  def test_should_refresh_applicable_property_definitions_partial_with_all_card_relationship_property_definitions_if_card_type_is_nil
    related_card = setup_card_relationship_property_definition('related card')
    other_related_card = setup_card_relationship_property_definition('other related card')

    variable = create_plv!(@project, :name => 'Jimmy', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => nil)

    xhr :post, :select_card_type, :project_id => @project.identifier, :id => variable.id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type_id => nil

    assert_response :success
    assert @response.body.include?("project_variable_property_name_#{related_card.id}")
    assert @response.body.include?("project_variable_property_name_#{other_related_card.id}")
  end
  
  def test_should_refresh_applicable_property_definitions_partial_with_all_card_relationship_property_definitions_if_card_type_is_present_in_tree
    create_tree_project(:init_empty_planning_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      planning_iteration = project.find_property_definition('planning iteration')
      related_card = setup_card_relationship_property_definition('related card')
      other_related_card = setup_card_relationship_property_definition('other related card')
    
      variable = create_plv!(project, :name => 'Jimmy', :data_type => ProjectVariable::STRING_DATA_TYPE)

      xhr :post, :select_card_type, :project_id => project.identifier, :id => variable.id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type_id => type_iteration.id

      assert_response :success
      assert @response.body.include?("project_variable_property_name_#{planning_iteration.id}")
      assert @response.body.include?("project_variable_property_name_#{related_card.id}")
      assert @response.body.include?("project_variable_property_name_#{other_related_card.id}")
    end
  end
  
  # bug 5093
  def test_selected_properties_should_not_be_lost_on_change_of_card_type
    create_tree_project(:init_empty_planning_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')
      related_card = setup_card_relationship_property_definition('related card')
      other_related_card = setup_card_relationship_property_definition('other related card')
      
      variable = create_plv!(project, :name => 'Jimmy', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release, :property_definition_ids => [related_card.id, planning_release.id])
      
      xhr :post, :select_card_type, :project_id => project.identifier, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type_id => type_iteration.id, :project_variable => { :property_definition_ids => [related_card.id.to_s, planning_release.id.to_s] }
      assert_property_not_checked(planning_iteration)
      assert_property_not_checked(other_related_card)
      assert_property_checked(related_card)
      
      xhr :post, :select_card_type, :project_id => project.identifier, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type_id => type_release.id, :project_variable => { :property_definition_ids => [planning_release.id.to_s, other_related_card.id.to_s] }
      assert_property_checked(planning_release)
      assert_property_checked(other_related_card)
      assert_property_not_checked(related_card)
    end
  end
  
  def assert_property_checked(property_definition)
    assert json_unescape(@response.body) =~ /<input checked=\\"checked\\" id=\\"property_definitions\[#{property_definition.id}\]\\" name=\\"project_variable\[property_definition_ids\]\[\]\\" type=\\"checkbox\\" value=\\"#{property_definition.id}\\" \/>/
  end
  
  def assert_property_not_checked(property_definition)
    assert json_unescape(@response.body) =~ /<input id=\\"property_definitions\[#{property_definition.id}\]\\" name=\\"project_variable\[property_definition_ids\]\[\]\\" type=\\"checkbox\\" value=\\"#{property_definition.id}\\" \/>/
  end
  
end
