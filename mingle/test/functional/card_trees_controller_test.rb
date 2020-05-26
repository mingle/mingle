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

class CardTreesControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @controller = create_controller CardTreesController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @project = create_project
    @tree_configuration = @project.tree_configurations.create(:name => 'Release tree')
    @first_id = @tree_configuration.id

    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end

  def test_index
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list, :project_id => @project.identifier

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:trees)
  end

  def test_new
    get :new, :project_id => @project.identifier

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:tree)
    assert_select "div[id='tree_config_view']"
  end

  def test_should_display_message_for_user_to_create_card_type_when_there_is_only_one_card_type_and_user_try_to_create_a_tree
    with_new_project do |project|
      get :new, :project_id => project.identifier
      assert_response :success
      assert_template 'new'
      assert @response.body.include?('Trees require at least two card types in a project.')
      assert !@response.body.include?("tree_config_view")
    end
  end

  def test_create
    num_card_trees = TreeConfiguration.count

    post :create, :tree => {:name => 'I am card tree', :description => 'description'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_response :redirect
    assert_redirected_to card_tree_path(:tree_name => 'I am card tree', :tab => 'All')

    assert_equal 'description', @project.tree_configurations.find_by_name("I am card tree").description
  end

  def test_confirm_delete
    init_three_level_tree(@tree_configuration)
    get :confirm_delete, :id => @tree_configuration, :project_id => @project.identifier
    assert_response :success
    assert @response.body.include?("CAUTION! This action is final and irrecoverable.")
  end

  def test_delete
    init_three_level_tree @tree_configuration
    post :delete, :id => @tree_configuration, :project_id => @project.identifier
    assert_response :redirect
    assert_record_deleted @tree_configuration
  end

  def test_create_with_configuration
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_response(:redirect)
    assert @response.has_flash_object?(:notice)
    @project.all_property_definitions.reload
    assert @project.tree_configurations.find_by_name('I am card tree').configured?
  end

  def test_create_should_show_atleast_2_type_nodes_even_when_there_is_an_error
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => '', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => nil}
    }
    expect_javascript = "var typeNode0 = treeConfigView.createTypeNode(null, \"release\", null);var typeNode1 = treeConfigView.createTypeNode(typeNode0, null, \"\");"

    assert @response.body.include?(expect_javascript);
  end

  def test_create_should_show_error_when_there_are_relationship_properties_with_blank_names
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => '', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_error
  end

  def test_create_should_provide_correct_non_unique_relationship_property_error_messages_correctly
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'Foo', :card_type_name => @type_release.name},
      '1' => {:relationship_name => 'foo', :card_type_name => @type_iteration.name},
      '2' => {:relationship_name => nil, :card_type_name => @type_story.name}
    }
    assert_error 'Relationship name <b>Foo</b> is not unique'
  end

  def test_should_be_able_to_create_tree_with_overrides_for_default_relationship_names
    post :create, :tree => {:name => 'ct'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }

    assert_response(:redirect)
    @project.all_property_definitions.reload
    assert_equal ['tree release'], @project.tree_configurations.find_by_name('ct').relationships.collect(&:name)
  end

  def test_create_with_invalid_configuration
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {'0' => {}, '1' => {}}
    assert_template 'new'
    assert_error
    assert_rollback
  end

  def test_create_with_too_long_relationship_name
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => ('a' * 50), :card_type_name => @type_release.name},
      '1' => {:card_type_name => @type_iteration.name}
    }
    assert_template 'new'
    assert_error "Relationship <b>aaaaaaaaaaaaaaaaaaaaaa...</b> has errors:<br /><ul><li>Name is too long (maximum is 40 characters)</li></ul>"
    assert_rollback
  end

  def test_edit
    get :edit, :id => @first_id, :project_id => @project.identifier

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:tree)
    assert assigns(:tree).valid?
  end

  def test_update
    post :update, :id => @first_id, :project_id => @project.identifier, :tree => {:name => 'new name'}, :card_types => {
     '0' => {:relationship_name => 'tree release', :card_type_name => @type_release.name},
     '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_equal 'new name', @tree_configuration.reload.name
    @project.all_property_definitions.reload
    assert_not_nil @project.find_property_definition('tree release')
    assert_response :success
  end

  def test_update_configuration
    post :update, :id => @first_id, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_response :success
    @project.all_property_definitions.reload
    assert_equal [@type_release, @type_iteration], @tree_configuration.all_card_types

    post :update, :id => @first_id, :project_id => @project.identifier, :update_permanently => 'true', :card_types => {
      '0' => {:relationship_name => 'I am card tree iteration', :card_type_name => @type_iteration.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_release.name}
    }

    assert_template 'edit'
    assert_error
    assert_rollback
  end

  # bug 3497
  def test_can_change_case_of_relationship_name_and_it_will_be_saved
    init_three_level_tree(@tree_configuration)
    planning_release = @project.find_property_definition('planning release')

    new_planning_release_name = planning_release.name.upcase
    assert new_planning_release_name != planning_release.name # just making sure new name is different case

    post :update, :id => @first_id, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => new_planning_release_name, :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }, :update_permanently => true
    assert_response :success
    assert_equal new_planning_release_name, planning_release.reload.name
  end

  # bug 3082
  def test_update_configuration_warning_screen_should_maintain_form_values
    @tree_configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })

    post :update, :id => @first_id, :project_id => @project.identifier, :tree => {:name => 'whoa', :description => 'hey-o'}, :card_types => {
      '0' => {:relationship_name => 'release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => 'iteration', :card_type_name => @type_iteration.name}
    }
    assert_select "input#tree_name[value='whoa']"
    assert_select "input#tree_description[value='hey-o']"
    assert @tree_configuration.reload.name != 'whoa'
    assert_select "div[id=content][class=invisible]"
  end

  def test_update_configuration_should_show_card_type_project_variables_warning_messages
    @tree_configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'},
      @type_iteration => {:position => 1, :relationship_name => 'iteration'},
      @type_story => {:position => 2}
    })
    cp_iteration = @project.find_property_definition('iteration')
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :property_definition_ids => [cp_iteration.id])
    post :update, :id => @first_id, :project_id => @project.identifier, :tree => {:name => 'whoa', :description => 'hey-o'}, :card_types => {
      '0' => {:relationship_name => 'release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => 'story', :card_type_name => @type_story.name}
    }
    assert_select 'li[name="project_variable_warning"]', :text => "The following 1 project variable will no longer be associated with the deleted property: current iteration"
  end

  def test_if_no_trees_in_project_no_trees_flash_should_show_up
    @project.tree_configurations.destroy_all
    get :list, :project_id  => @project.identifier
    assert @response.body.include?("There are currently no trees to list. You can create a new tree from the action bar.")
  end

  def test_invalid_creation_should_keep_empty_configuration_types
    post :create, :tree => {:name => ''}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => ''},
      '2' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }
    assert_template 'new'
    expect_javascript = "var typeNode0 = treeConfigView.createTypeNode(null, \"release\", null);var typeNode1 = treeConfigView.createTypeNode(typeNode0, \"iteration\", \"I am card tree release\");"
    assert @response.body.include?(expect_javascript)
  end

  # for ie6 may submit 'null' as null value
  def test_should_ignore_non_numeric_string_of_card_types
    post :create, :tree => {:name => 'I am card tree'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => 'I am card tree', :card_type_name => ''},
      '2' => {:card_type_name => @type_iteration.name}
    }
    assert_response :redirect
    assert_redirected_to card_tree_path(:tree_name => 'I am card tree', :tab => 'All')
  end

  def test_create_aggregate_property_definition_works_with_hidden_target
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')
    num_prop_def = setup_numeric_property_definition('size', [1, 2, 3])
    num_prop_def.hidden = true
    num_prop_def.save!

    post :create_aggregate_property_definition, :id => @tree_configuration.id, :project_id => @project.identifier,
         :aggregate_property_definition => {:name => 'sum of size', :aggregate_type => AggregateType::SUM,
           :aggregate_scope_card_type_id => AggregateScope::ALL_DESCENDANTS, :aggregate_card_type_id => @type_release.id, :tree_configuration_id => @tree_configuration.id,
           :aggregate_target_id => num_prop_def.id }

    assert !@project.reload.find_property_definition_or_nil('sum of size').nil?
  end

  def test_create_aggregate_property_defintion_can_have_a_condition
    init_three_level_tree(@tree_configuration)
    setup_numeric_text_property_definition 'size'

    post :create_aggregate_property_definition, :id => @tree_configuration.id, :project_id => @project.identifier,
         :aggregate_property_definition => {:name => 'aggregate_with_condition', :aggregate_type => AggregateType::COUNT,
         :aggregate_scope_card_type_id => AggregateScope::DEFINE_CONDITION, :aggregate_condition => 'size=1', :aggregate_card_type_id => @type_release.id,
         :tree_configuration_id => @tree_configuration.id }

    assert_response :success
    assert_nil flash[:error]

    aggregate = @project.reload.find_property_definition_or_nil('aggregate_with_condition')

    assert_equal "size=1", aggregate.aggregate_condition
    assert_equal nil, aggregate.aggregate_scope
  end

  def test_create_aggregate_property_definition_should_error_if_condition_is_empty
    init_three_level_tree(@tree_configuration)
    setup_numeric_text_property_definition 'size'

    post :create_aggregate_property_definition, :id => @tree_configuration.id, :project_id => @project.identifier,
         :aggregate_property_definition => {:name => 'aggregate_with_condition', :aggregate_type => AggregateType::COUNT,
         :aggregate_scope_card_type_id => AggregateScope::DEFINE_CONDITION, :aggregate_condition => '', :aggregate_card_type_id => @type_release.id,
         :tree_configuration_id => @tree_configuration.id }

    assert_equal ["Aggregate condition cannot be blank"], flash[:error]
  end

  def test_update_aggregate_property_definition_should_error_if_condition_is_empty
    init_three_level_tree(@tree_configuration)
    setup_numeric_text_property_definition 'size'

    post :create_aggregate_property_definition, :id => @tree_configuration.id, :project_id => @project.identifier,
         :aggregate_property_definition => {:name => 'aggregate_with_condition', :aggregate_type => AggregateType::COUNT,
         :aggregate_scope_card_type_id => AggregateScope::DEFINE_CONDITION, :aggregate_condition => 'size = 1', :aggregate_card_type_id => @type_release.id,
         :tree_configuration_id => @tree_configuration.id }

    aggregate_property_definition = @project.find_property_definition('aggregate_with_condition')

    post :update_aggregate_property_definition, :id => aggregate_property_definition.id, :project_id => @project.identifier,
         :aggregate_property_definition => { :name => 'aggregate_with_condition', :aggregate_type => AggregateType::COUNT,
           :aggregate_scope_card_type_id => AggregateScope::DEFINE_CONDITION, :aggregate_condition => '', :aggregate_card_type_id => @type_release.id,
           :tree_configuration_id => @tree_configuration.id }

    assert_include "Aggregate condition cannot be blank", flash[:error]
  end


  def test_should_give_warning_message_when_user_deleted_a_card_type_node_from_tree_configuration
    post :update, :id => @first_id, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => 'I am card tree iteration', :card_type_name => @type_iteration.name},
      '2' => {:card_type_name => @type_story.name}
    }
    assert_response :success

    post :update, :id => @first_id, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:card_type_name => @type_iteration.name}
    }

    assert_response :success
    assert_template 'edit'
    
    assert @response.body.include?("CAUTION! This action is final and irrecoverable.")
    assert @response.body.include?("Pages and tables/charts that use this property will no longer work.")
  end

  def test_should_show_error_when_remove_card_type_from_configuration_which_contains_aggregrate_property_which_is_used_in_a_formula
    init_three_level_tree(@tree_configuration)
    @type_release, @type_iteration, @type_story = find_planning_tree_types
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @tree_configuration.id, @type_release.id, @type_iteration)
    @tree_configuration.reload
    setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

    post :update, :id => @tree_configuration.id, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'iteration', :card_type_name => @type_iteration.name},
      '1' => {:card_type_name => @type_story.name}
    }

    assert_select 'p', :html => /<b>Release tree<\/b> cannot be reconfigured as properties in this tree are currently used by this project/
    assert_select 'p', :html => /cannot be deleted:/
    assert_select 'li', :html => /used as a component property of/
  end

  def test_should_show_error_when_delete_tree_which_contains_aggregrate_property_which_is_used_in_a_formula
    init_three_level_tree(@tree_configuration)
    @type_release, @type_iteration, @type_story = find_planning_tree_types
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @tree_configuration.id, @type_release.id, @type_iteration)
    @tree_configuration.reload
    setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

    get :confirm_delete, :id => @tree_configuration.id, :project_id => @project.identifier

    assert_select 'p', :html => /<b>Release tree<\/b> cannot be deleted as properties in this tree are currently used by this project/
    assert_select 'p', :html => /cannot be deleted:/
    assert_select 'li', :html => /used as a component property of/
  end

  def test_delete_aggregate_property_definition
    init_three_level_tree(@tree_configuration)

    iteration_size = setup_numeric_text_property_definition('iteration size')
    @type_iteration.add_property_definition(iteration_size)

    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::SUM, iteration_size, @tree_configuration.id, @type_release.id,  @type_iteration)
    post :delete_aggregate_property_definition, :id => aggregate_property_definition.id, :project_id => @project.identifier

    assert !@project.reload.aggregate_property_definitions_with_hidden.collect(&:id).include?(aggregate_property_definition.id)
    assert @response.body.include?("deleted successfully")
    assert_select "span", :text => "aggregate name: Sum of iteration size", :count => 0
  end

  def test_should_show_error_when_deleting_aggregate_which_is_used_in_a_formula
    init_three_level_tree(@tree_configuration)
    iteration_size = setup_numeric_text_property_definition('iteration size')
    @type_iteration.add_property_definition(iteration_size)

    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::SUM, iteration_size, @tree_configuration.id, @type_release.id,  @type_iteration)
    john = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

    post :delete_aggregate_property_definition, :id => aggregate_property_definition.id, :project_id => @project.identifier
    assert_include "is used as a component property of #{john.name.html_bold}. To manage #{john.name.html_bold}, please go to <a href=\"/projects/#{@project.identifier}/property_definitions/edit/#{john.id}\" target=\"blocking\">card property management page</a>.", flash[:info]
  end

  def test_update_aggregate_property_definition
    init_three_level_tree(@tree_configuration)

    iteration_size = setup_numeric_text_property_definition('iteration size')
    @type_iteration.add_property_definition(iteration_size)

    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::SUM, iteration_size, @tree_configuration.id, @type_release.id, @type_iteration)
    post :update_aggregate_property_definition, :id => aggregate_property_definition.id, :project_id => @project.identifier,
      :aggregate_property_definition => {:name => 'new name', :aggregate_type => AggregateType::AVG}

    assert_equal 'new name', aggregate_property_definition.reload.name
    assert_equal AggregateType::AVG, aggregate_property_definition.aggregate_type
    assert @response.body.include?("updated successfully")
  end

  def test_update_aggregate_property_definition_calculated_scope
    init_three_level_tree(@tree_configuration)

    iteration_size = setup_numeric_text_property_definition('iteration size')
    @type_iteration.add_property_definition(iteration_size)

    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::SUM, iteration_size, @tree_configuration.id, @type_release.id, @type_iteration)
    post :update_aggregate_property_definition, :id => aggregate_property_definition.id, :project_id => @project.identifier,
      :aggregate_property_definition => { :aggregate_scope => AggregateScope::CONDITION, :aggregate_condition => "'iteration size'=1" }

    assert_nil aggregate_property_definition.reload.aggregate_scope
    assert_equal "'iteration size'=1", aggregate_property_definition.aggregate_condition
    assert @response.body.include?("updated successfully")
  end

  # bug 3211 (when scope type was more than one card type level below level of aggregate (e.g. aggregate level: release, scope: story), target property would not be selected)
  def test_show_edit_aggregate_form_has_target_property_selected
    init_three_level_tree(@tree_configuration)
    size = setup_numeric_text_property_definition('size')
    @type_story.add_property_definition(size)

    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @tree_configuration.id, @type_release.id, @type_story)
    xhr :post, :show_edit_aggregate_form, :project_id => @project.identifier, :id => release_size.id

    match = "select id=\"aggregate_property_definition_aggregate_target_id\" name=\"aggregate_property_definition[aggregate_target_id]\"><option value=\"\">What you want to aggregate...</option><option value=\"#{size.id}\" selected=\"selected\">size</option></select>"
    assert json_unescape(@response.body).gsub(/\\n/, '').gsub(/\\/, '').include?(match)
  end

  def test_create_with_redirect_to_aggregates
    post :create, :tree => {:name => 'I am card tree', :description => 'description'}, :project_id => @project.identifier, :card_types => {
      '0' => {:relationship_name => 'I am card tree release', :card_type_name => @type_release.name},
      '1' => {:relationship_name => nil, :card_type_name => @type_iteration.name}
    }, :navigate_to_aggregates => "true"
    assert_response :redirect
    assert_redirected_to edit_aggregate_properties_path(:id => @project.tree_configurations.find_by_name('I am card tree').id)
  end
end
