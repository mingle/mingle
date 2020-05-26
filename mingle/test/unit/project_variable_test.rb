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

class ProjectVariableTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = first_project
    @project.activate
    login_as_member
    @iteration = @project.find_property_definition('iteration')
    @status = @project.find_property_definition('status')
  end

  def teardown
    @project.deactivate
  end

  def test_should_validate_the_length_of_name
    invalid_variable = create_plv(@project, :name => 'looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong name', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert !invalid_variable.errors.empty?
  end

  def test_should_be_uniq_name_and_case_insensitive
    create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
    invalid_variable = create_plv(@project, :name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert invalid_variable.errors.on(:name)
  end

  def test_default_data_type_is_string_type
    assert_equal 'StringType', create_plv(@project, :name => 'Variable').data_type
  end

  def test_create_with_invalid_data_type
    create_plv!(@project, :name => 'Variable')

    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => 'invalid data type')
    assert invalid_variable.errors.on(:data_type)
  end

  def test_should_not_allow_variables_to_be_created_with_name_of_reserved_identifiers_without_parenthesis
    Project::RESERVED_IDENTIFIERS.each do |reserved_id|
      reserved_id = reserved_id.gsub(/\(|\)/, '')
      invalid_variable = create_plv(@project, :name => reserved_id.upcase, :data_type => ProjectVariable::STRING_DATA_TYPE)
      assert invalid_variable.errors.on(:name)
    end
  end

  def test_should_allow_variables_to_be_created_with_name_of_reserved_identifiers_with_parenthesis
    Project::RESERVED_IDENTIFIERS.inject([]) do |reserved_identifiers, reserved_id|
      reserved_id_without_parenthesis = reserved_id.gsub(/\(|\)/, '')
      reserved_identifiers << "(#{reserved_id_without_parenthesis})"
    end.uniq.each do |reserved_id|
      invalid_variable = create_plv(@project, :name => reserved_id.upcase, :data_type => ProjectVariable::STRING_DATA_TYPE)
      assert !invalid_variable.errors.on(:name)
    end
  end

  def test_should_not_allow_to_create_variable_with_value_matched_with_project_reserved_identifier_regex
    invalid_variable = create_plv(@project, :name => 'Variable', :value => '(invalid)')
    assert invalid_variable.errors.on(:value)

    invalid_variable = create_plv(@project, :name => 'Variable', :value => '(invalid)', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert invalid_variable.errors.on(:value)

    valid_variable = create_plv(@project, :name => 'Variable', :value => '(not inva)lid', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert !valid_variable.errors.on(:value)

    date_invalid_variable = create_plv(@project, :name => 'Variable', :value => '(invalid)', :data_type => ProjectVariable::DATE_DATA_TYPE)
    assert invalid_variable.errors.on(:value)
    assert_not_equal date_invalid_variable.errors.on(:value), invalid_variable.errors.on(:value)
  end

  def test_warning_messages_for_creating_variable_association_with_enum_or_user_property_defintion
    assert_nil ProjectVariable.warning_messages_of(@project, nil, nil)
    status_prop = @project.find_property_definition('status')
    assert_nil ProjectVariable.warning_messages_of(@project, nil, status_prop)

    variable_name = 'open'
    assert ProjectVariable.warning_messages_of(@project, variable_name, status_prop)

    dev_prop = @project.find_property_definition('dev')
    variable_name = 'member'
    assert ProjectVariable.warning_messages_of(@project, variable_name, dev_prop)
  end

  def test_should_not_allow_adding_property_definition_which_does_not_included_in_the_all_available_property_definitions
    status_prop = @project.find_property_definition('status')
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE, :property_definition_ids => [status_prop.id.to_s])
    assert invalid_variable.errors.on(:property_definitions)
  end

  def test_all_available_property_definitions_should_be_filtered_by_data_type
    with_new_project do |project|
      setup_user_definition 'dev'
      variable = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::USER_DATA_TYPE)
      assert_equal ['dev'], variable.all_available_property_definitions.collect(&:name)

      setup_date_property_definition('start date')
      variable.reload
      variable.update_attributes :data_type => ProjectVariable::DATE_DATA_TYPE
      assert_equal ['start date'].sort, variable.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_all_available_property_definitions_should_be_enum_and_text_property_definitions_when_variable_data_type_is_string
    with_new_project do |project|
      setup_numeric_text_property_definition 'numeric text'
      setup_numeric_property_definition 'release', ['1', '2']
      setup_property_definitions :status => ['new', 'open'], :it => ['x', 'xx']
      setup_text_property_definition 'text free'

      variable = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
      assert_equal ['it', 'status', 'text free'].sort, variable.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_all_available_property_definitions_should_be_numeric_enum_and_text_and_not_be_formula_property_definitions_when_variable_data_type_is_numeric
    with_new_project do |project|
      setup_numeric_text_property_definition 'numeric text'
      setup_numeric_property_definition 'release', ['1', '2']
      setup_formula_property_definition 'next release', 'release + 1'
      setup_property_definitions :status => ['new', 'open'], :it => ['x', 'xx']
      setup_text_property_definition 'text free'

      variable = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::NUMERIC_DATA_TYPE)
      assert_equal ['numeric text', 'release'].sort, variable.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_all_available_property_definitions_should_be_date_and_not_formula_property_definitions_when_variable_data_type_is_date
    with_new_project do |project|
      setup_numeric_text_property_definition 'numeric text'
      setup_numeric_property_definition 'release', ['1', '2']
      setup_formula_property_definition 'next release', 'release + 1'
      setup_property_definitions :status => ['new', 'open'], :it => ['x', 'xx']
      setup_text_property_definition 'text free'
      setup_date_property_definition 'abner'

      variable = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE)
      assert_equal ['abner'].sort, variable.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_all_available_property_definitions_for_card_data_type
    with_card_query_project do |project|
      card_plv = create_plv!(project, :name => 'Timmy', :data_type => ProjectVariable::CARD_DATA_TYPE)
      assert_equal(['related card'], card_plv.all_available_property_definitions.collect(&:name).sort)
    end
  end

  def test_should_include_card_and_tree_relationship_properties_when_a_tree_card_type_is_selected
    create_tree_project(:init_empty_planning_tree) do |project, tree, configuration|
      setup_card_relationship_property_definition('related card')

      type_release = project.card_types.find_by_name('release')
      release_plv = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release)

      assert_equal ['Planning release', 'related card'], release_plv.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_should_include_only_tree_relationship_properties_when_a_tree_card_is_selected_and_no_card_relationship_property_exists
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      release_plv = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release)
      iteration_plv = create_plv!(project, :name => 'Variable 2', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration)

      assert_equal ['Planning release', 'related card'], release_plv.all_available_property_definitions.collect(&:name).sort
      assert_equal ['Planning iteration', 'related card'], iteration_plv.all_available_property_definitions.collect(&:name).sort
    end
  end

  def test_should_validate_value_by_data_type_for_numerics
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 'xx')
    assert invalid_variable.errors.on(:value)

    variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1.2')
    assert variable.errors.empty?
  end

  def test_should_validate_value_by_data_type_for_dates
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => 'xx')
    assert invalid_variable.errors.on(:value)

    variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '01/01/2008')
    assert variable.errors.empty?
  end

  def test_date_type_should_not_allow_today
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '(today)')
    assert invalid_variable.errors.on(:value)
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => 'today')
    assert invalid_variable.errors.on(:value)
  end

  def test_should_validate_value_by_data_type_for_user_type
    invalid_variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::USER_DATA_TYPE, :value => 'xx')
    assert invalid_variable.errors.on(:value)

    variable = create_plv(@project, :name => 'Variable', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id)
    assert variable.errors.empty?
  end

  def test_all_available_property_definitions_should_include_hidden_property_definition
    status_prop = @project.find_property_definition('status')
    variable = create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert variable.all_available_property_definitions.include?(status_prop)

    status_prop.update_attribute(:hidden, true)
    variable.reload
    assert variable.all_available_property_definitions.include?(status_prop)
  end

  def test_should_clear_project_variable_value_but_not_property_definitions_when_user_is_removed_from_team_who_is_the_project_variable_value
    with_new_project do |project|
      member = User.find_by_login('member')
      project.add_member(member)
      setup_user_definition 'dev'
      dev_prop = project.find_property_definition('dev')
      variable = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::USER_DATA_TYPE, :value => member.id, :property_definition_ids => [dev_prop.id])

      project.remove_member(member)

      variable = project.project_variables.find_by_name(variable.name)
      assert_equal nil, variable.value
      assert_equal [dev_prop.name], variable.property_definitions.collect(&:name)
    end
  end

  def test_delete_should_also_delete_transitions_using_project_variable
    with_new_project do |project|
      release = setup_numeric_property_definition('release', [1, 2, 3])
      current_release = create_plv!(project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
      current_release.property_definitions = [release]
      current_release.save!
      transition = create_transition(project, 'set to current release',
                                                :set_properties => {:release => current_release.display_name})

      current_release.destroy
      assert_nil project.transitions.find_by_name(transition.name)
    end
  end

  def test_display_value_should_be_not_set_when_empty
    assert_equal PropertyValue::NOT_SET, create_plv(@project, :name => 'Variable').display_value
    assert_equal PropertyValue::NOT_SET, create_plv(@project, :name => 'Variable', :value => '').display_value
  end

  def test_used_by_transitions
    with_new_project do |project|
      release = setup_numeric_property_definition 'release', ['1', '2', '3']
      current_release = create_plv!(project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :property_definition_ids => [release.id])
      assert_equal [], current_release.used_by_transitions
      transition_use_current_release = create_transition(project, 'set to current release', :set_properties => {:release => current_release.display_name})

      assert_equal [transition_use_current_release.name], current_release.reload.used_by_transitions.collect(&:name)
      transition = create_transition(project, 'set to release 3', :set_properties => {:release => '3'})
      assert_equal [transition_use_current_release.name], current_release.reload.used_by_transitions.collect(&:name)
    end
  end

  def test_select_options_from_user_type_should_include_not_set
    user_type = ProjectVariable::UserType.new(@project)
    assert_equal [PropertyValue::NOT_SET, nil], user_type.select_options.first
  end

  def test_new_value_should_fit_the_exist_values_order_which_generated_when_create_new_project_variable
    with_new_project do |project|
      estimate = setup_numeric_property_definition 'estimate', [1, 6]
      medium_estimate = create_plv!(project, :name => 'medium', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :property_definition_ids => [estimate.id])

      assert_equal ['1', '3', '6'], estimate.reload.enumeration_values.collect(&:value)
    end
  end

  def test_user_types_card_query_value_should_be_login
    member = @project.users.find_by_login('member')
    qa_lead = create_plv!(@project, :name => 'QA lead', :data_type => ProjectVariable::USER_DATA_TYPE, :value => member.id.to_s)
    assert_equal 'member', qa_lead.card_query_value
  end

  def test_change_card_type_of_card_used_as_value_of_plv_should_result_in_error_message
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_story)
      planning_iteration = project.find_property_definition('planning iteration')
      current_iteration = create_plv!(project, :name => 'current iteration', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_iteration.id])
      non_current_iteration = create_plv!(project, :name => 'non current iteration', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_iteration.id])
      project.reload
      iteration3.card_type_name = type_release.name
      assert_false iteration3.save
      message = iteration3.errors.full_messages.join
      plvs_in_message = message.gsub(/Cannot change card type because card is being used as the value of project variables: /, '').split(',').collect(&:strip)
      assert_equal ['(current iteration)'.bold, '(non current iteration)'.bold].sort, plvs_in_message.sort
    end
  end

  def test_destroy_card_should_remove_value_but_not_property_associations_from_project_variable_that_use_that_card
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_story)
      cp_iteration = project.find_property_definition('planning iteration')

      current_iteration = create_plv!(project, :name => 'current iteration', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      project.reload
      iteration3.reload
      assert iteration3.destroy
      current_iteration.reload
      assert_equal [cp_iteration.name], current_iteration.property_definitions.collect(&:name)
      assert_equal nil, current_iteration.value
    end
  end

  def test_all_available_property_definitions_for_card_data_type_should_be_compact
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      release_configure = project.tree_configurations.create!(:name => 'release planning tree')
      release_configure.update_card_types({
        type_release => {:position => 0, :relationship_name => 'planning release'},
        type_iteration => {:position => 1, :relationship_name => 'planning iteration'},
        type_story => {:position => 2}
      })
      iteration_configure = project.tree_configurations.create!(:name => 'iteration planning tree')
      iteration_configure.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1},
      })
      current_iteration = create_plv!(project, :name => 'curernt iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration)
      assert_equal ['planning iteration'], current_iteration.all_available_property_definitions.collect(&:name)
    end
  end

  def test_rename_normal_plv_should_rename_card_list_view_that_use_it
    with_new_project do |project|
      iteration = setup_numeric_property_definition 'iteration', ['1', '2']
      current_iteration = create_plv!(project, :name => 'current it', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id] )
      project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current it)]"])
      project.reload
      current_iteration.update_attribute(:name, 'current iteration')
      view = project.card_list_views.find_by_name('story wall')
      assert_equal ["[Type][is][story]", "[iteration][is][(current iteration)]"], view.to_params[:filters]
    end
  end

  def test_rename_card_plv_should_rename_card_list_view_that_use_it
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      cp_iteration = project.find_property_definition('planning iteration')
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      current_iteration = create_plv!(project, :name => 'current it', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'tree', :tree_name => 'three level tree', :tf_release => [], :tf_iteration => ["[planning iteration][is][(current it)]"]).save!
      project.reload
      current_iteration.update_attribute(:name, 'current iteration')
      view = project.card_list_views.find_by_name('story wall')
      assert_equal ["[Planning iteration][is][(current iteration)]"], view.to_params[:tf_iteration]
    end
  end

  def test_rename_plv_should_rename_transition_values_using_it
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[@iteration.id] )
    transition_using = create_transition(@project, 'set to current iteration',
                                            :set_properties => {:iteration => current_iteration.display_name})
    current_iteration.name = 'current it'
    current_iteration.save!

    transition_using.reload
    assert_equal '(current it)', transition_using.value_set_for(@iteration)
  end

  def test_reame_plv_should_always_be_smooth_update
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[@iteration.id] )
    transition_using = create_transition(@project, 'set to current iteration',
                                            :set_properties => {:iteration => current_iteration.display_name})
    view_using = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    @project.reload
    current_iteration.reload
    current_iteration.name = 'current it'
    current_iteration.property_definition_ids = [@iteration.id]
    assert current_iteration.smooth_update?
  end

  def test_rename_of_plv_should_update_any_plvs_used_in_aggregate_conditions
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      current_iteration = create_plv!(project, :name => 'current_iteration', :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :value => nil, :property_definition_ids => [project.find_property_definition('iteration').id])

      some_agg = setup_aggregate_property_definition('aggregate',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      some_agg.aggregate_condition = "iteration = (current_iteration)"
      some_agg.save!
      current_iteration.project.all_property_definitions.reload

      current_iteration.name = "present_iteration"
      current_iteration.save!

      assert_equal "iteration = (present_iteration)", some_agg.reload.aggregate_condition
    end
  end

  def test_rename_of_plv_should_not_update_any_plvs_used_in_invalid_aggregate_conditions
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      current_iteration = create_plv!(project, :name => 'current_iteration', :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :value => nil, :property_definition_ids => [project.find_property_definition('iteration').id])
      favourite_iteration = create_plv!(project, :name => 'favourite_iteration', :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :value => nil, :property_definition_ids => [project.find_property_definition('iteration').id])

      some_agg = setup_aggregate_property_definition('aggregate',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      some_agg.aggregate_condition = "iteration = (current_iteration) OR iteration = (favourite_iteration)"
      some_agg.save!
      current_iteration.project.all_property_definitions.reload

      favourite_iteration.destroy

      current_iteration.name = "present_iteration"
      current_iteration.save!

      assert_equal "iteration = (current_iteration) OR iteration = (favourite_iteration)", some_agg.reload.aggregate_condition
    end
  end

  def test_can_tell_whether_is_using_a_card
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      cp_iteration = project.find_property_definition('planning iteration')
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      current_iteration = create_plv!(project, :name => 'current it', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      assert current_iteration.uses_card?(iteration3)
      assert !current_iteration.uses_card?(project.cards.build)
      null_it = create_plv!(project, :name => 'null it', :value => nil, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      assert !null_it.uses_card?(iteration3)
      assert !null_it.uses_card?(project.cards.build)
    end
  end

  def test_destroy_a_plv_should_view_has_tree_filters_that_use_this_plv
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      cp_iteration = project.find_property_definition('planning iteration')
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      current_iteration = create_plv!(project, :name => 'current it', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'tree', :tree_name => 'three level tree', :tf_release => [], :tf_iteration => ["[planning iteration][is][(current it)]"]).save!
      current_iteration.project.reload
      current_iteration.destroy
      assert_nil project.card_list_views.find_by_name('story wall')
    end
  end

  def test_destroy_a_plv_should_destroy_all_normal_views_use_this_plv
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ @iteration.id] )
    final_status = create_plv!(@project, :name => 'final status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'close', :property_definition_ids =>[ @iteration.id] )
    view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    view_use_another_plv = @project.card_list_views.create_or_update(:view => {:name => 'final delivered'}, :style => 'list', :filters => ["[Type][is][story]", "[status][is][(final status)]"])
    [view_use_plv, view_use_another_plv].each(&:save!)
    [current_iteration, final_status].each{ |plv| plv.project.reload }
    current_iteration.destroy

    assert_record_deleted view_use_plv
    assert_record_not_deleted view_use_another_plv
  end

  def test_change_plv_type_should_destroy_all_views_use_this_plv
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ @iteration.id] )
    view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    view_use_plv.save!
    current_iteration.project.reload
    current_iteration.update_attribute(:data_type, ProjectVariable::NUMERIC_DATA_TYPE)
    assert_record_deleted view_use_plv
  end

  def test_plv_should_be_able_to_smooth_update_when_there_nothing_to_lost
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ @iteration.id] )
    assert current_iteration.smooth_update?
    current_iteration.data_type = ProjectVariable::DATE_DATA_TYPE
    assert current_iteration.smooth_update?
    view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    view_use_plv.save!
    current_iteration.project.reload
    current_iteration.data_type = ProjectVariable::NUMERIC_DATA_TYPE
    assert !current_iteration.smooth_update?
  end

  def test_should_treat_any_not_perserved_name_in_quotes_as_plv
    assert ProjectVariable.is_a_plv_name?('(new)')
    assert ProjectVariable.is_a_plv_name?('(current iteration)')
    assert !ProjectVariable.is_a_plv_name?('(today)')
    assert !ProjectVariable.is_a_plv_name?('(TODAY)')
    assert !ProjectVariable.is_a_plv_name?('(any)')
    assert !ProjectVariable.is_a_plv_name?('(not set)')
  end

  def test_update_attributes_for_property_definition_ids_without_save_should_not_destroy_or_add_any_variable_binding_to_database
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[@iteration.id] )
    assert_equal 1, binding_count_in_db(current_iteration)
    current_iteration.property_definition_ids = [@iteration.id, @status.id]
    assert_equal 2, current_iteration.variable_bindings.size
    assert_equal 1, binding_count_in_db(current_iteration)
    current_iteration.save!
    assert_equal 2, binding_count_in_db(current_iteration)

    current_iteration.property_definition_ids = [@status.id]
    assert_equal [@status.id], current_iteration.property_definition_ids
    assert_equal 2, binding_count_in_db(current_iteration)
    current_iteration.save!
    assert_equal 1, binding_count_in_db(current_iteration)
  end

  def test_transitions_using_this_should_be_destroyed_when_bindings_updated
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[@iteration.id] )
    transition_using = create_transition(@project, 'set to current iteration',
                                            :set_properties => {:iteration => current_iteration.display_name})
    transition_not_use = create_transition(@project, 'close',
                                            :set_properties => {:status => 'close'})
    current_iteration.update_attributes(:property_definition_ids => [@status.id])

    assert_record_not_deleted transition_not_use
    assert_record_deleted transition_using
  end

  def test_only_team_views_should_appear_in_warnings_when_a_binding_will_be_destroyed_on_update
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ @iteration.id] )
    saved_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall sv'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"], :user_id => User.current.id)

    tab_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall tv'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    tab_view_use_plv.update_attributes(:tab_view => true)
    tab_view_use_plv.save!

    current_iteration.property_definition_ids = []

    assert_equal ['story wall tv'], current_iteration.team_views_needing_deletion_on_update.map(&:name)
  end

  def test_all_views_using_a_deletable_binding_should_be_destroyed_on_update
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ @iteration.id] )
    saved_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall sv'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"], :user_id => User.current.id)

    tab_view_use_plv = @project.card_list_views.create_or_update(:view => {:name => 'story wall tv'}, :style => 'grid', :filters => ["[Type][is][story]", "[iteration][is][(current iteration)]"])
    tab_view_use_plv.update_attributes(:tab_view => true)
    tab_view_use_plv.save!

    current_iteration.property_definition_ids = []
    current_iteration.save!
    assert_record_deleted tab_view_use_plv
    assert_record_deleted saved_view_use_plv
  end

  def test_should_restrict_plv_by_property_definition_when_create_property_value_from_url_identifier
    current_iteration = create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[@iteration.id] )
    current_iteration.property_definition_ids = [@status.id]
    current_iteration.save!
    @status.reload
    assert_equal VariableBinding, PropertyValue.create_from_url_identifier(@status, current_iteration.display_name).class
    assert_equal PropertyValue, PropertyValue.create_from_url_identifier(@iteration, current_iteration.display_name).class
  end

  def test_remove_from_transition_actions_should_not_use_project_variables
    with_three_level_tree_project do |project|
      type_release = project.card_types.find_by_name('release')
      planning_release = project.find_property_definition('Planning release')
      release1 = project.cards.find_by_name('release1')
      current_release = create_plv!(project, :name => 'current release', :value => release1.id, :card_type => type_release,
                                    :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_release.id])
      three_level_tree = project.tree_configurations.find_by_name('three level tree')
      transition = create_transition(project, 'remove from three level tree', :card_type => type_release, :remove_from_trees => [three_level_tree])
      assert_equal [], current_release.used_by_transitions
    end
  end

  def test_that_project_level_variables_cannot_be_named_the_optional_user_input_value
    illegal_plv = create_plv(@project, :name => "user input - optional", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'hi')
    assert_equal ["Name #{'user input - optional'.bold} is a reserved property value."], illegal_plv.errors.full_messages
  end

  def test_that_project_level_variables_cannot_be_named_set
    illegal_plv = create_plv(@project, :name => "set", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'hi')
    assert_equal ["Name #{'set'.bold} is a reserved property value."], illegal_plv.errors.full_messages
  end

  def test_cannot_display_card_link_if_variable_is_card_type_and_value_is_blank
    plv = create_plv(@project, :name => "Foo", :data_type => ProjectVariable::CARD_DATA_TYPE, :value => "")
    assert_false plv.display_card_link?
  end

  def test_can_display_card_link_if_variable_is_card_type_but_value_is_not_blank
    plv = create_plv(@project, :name => "Foo", :data_type => ProjectVariable::CARD_DATA_TYPE, :value => "not_blank")
    assert plv.display_card_link?
  end

  def test_should_find_current_project_variable_by_name
    plv = create_plv(@project, :name => "Foo", :data_type => ProjectVariable::CARD_DATA_TYPE, :value => "not_blank")
    assert_equal plv, ProjectVariable.find_plv_in_current_project('Foo')
    assert_equal plv, ProjectVariable.find_plv_in_current_project('foo')
    assert_equal nil, ProjectVariable.find_plv_in_current_project('bla')
  end

  # bug 4194
  def test_that_views_to_delete_on_update_are_not_named_twice
    with_new_project do |project|
      status1, status2 = setup_property_definitions(:status1 => ['high', 'low'], :status2 => ['high', 'low'])
      plv = create_plv!(project, :name => 'current status', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status1.id, status2.id], :value => 'high')

      CardListView.find_or_construct(project, {:name => 'sweet view', :filters => ["[status1][is][(current status)]", "[status2][is][(current status)]"]}).save!

      plv.property_definition_ids = []
      assert_equal ['sweet view'], plv.views_needing_deletion_on_update.collect(&:name)
    end
  end

  # bug 6924
  def test_unassociated_property_warning_can_generate_warning_messages_when_nil_property_definition_is_passed
    plv = create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
    assert_equal "Project variable #{'(Variable)'.bold} is not valid for the property.", plv.unassociated_property_warning(nil)
  end

  # Bug 7258
  def test_numeric_plvs_should_have_project_precision
    with_new_project do |project|
      project.update_attribute :precision, 1
      plv = create_plv!(project, :name => 'numeric', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :property_definition_ids => [], :value => '2.33')
      assert_equal '2.3', plv.value
    end
  end

  # Bug 7258
  def test_nonnumeric_plvs_should_not_have_project_precision
    with_new_project do |project|
      project.update_attribute :precision, 1
      plv = create_plv!(project, :name => 'nonnumeric', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [], :value => '2.33')
      assert_equal '2.33', plv.value
    end
  end

  def test_should_know_project_variables_which_use_user
    user = @project.users.first
    variable = create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::USER_DATA_TYPE, :value => user.id)
    assert_equal [variable], ProjectVariable.variables_that_use_user(@project, user)
  end

  def test_should_give_property_definition_description
    with_new_project do |project|
      variable = create_plv!(project, :name => 'status', :data_type => ProjectVariable::STRING_DATA_TYPE)

      assert_equal 'Text', variable.data_type_description
    end
  end

  def test_should_give_property_definition_description_with_card_identifier_with_card_type
    with_new_project do |project|
      release = project.card_types.create(:name => 'release')
      card_plv = create_plv!(project, :name => 'Timmy', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => release )

      assert_equal 'Card: release', card_plv.data_type_description
    end
  end

  def test_should_give_property_definition_description_with_card_identifier_without_card_type
    with_new_project do |project|
      card_plv = create_plv!(project, :name => 'Timmy', :data_type => ProjectVariable::CARD_DATA_TYPE )

      assert_equal 'Card', card_plv.data_type_description
    end
  end

  def test_should_return_comma_seperated_property_definition_names
    with_new_project do |project|
      status_prop_def = setup_managed_text_definition('Status', %w(new done))
      test_prop_def = setup_managed_text_definition('Test', %w(new done))
      plv = create_plv!(project, :name => 'test', :data_type => ProjectVariable::STRING_DATA_TYPE, property_definitions: [status_prop_def, test_prop_def] )

      assert_equal ['Status', 'Test'].sort, plv.property_definition_names.sort
    end
  end

  def test_export_value_should_give_value
    with_new_project do |project|
      string_data_type_PV = create_plv!(project, :name => 'status', :value =>'done', :data_type => ProjectVariable::STRING_DATA_TYPE)
      date_data_type_PV = create_plv!(project, :name => 'date', :value =>'25-07-2018', :data_type => ProjectVariable::DATE_DATA_TYPE)

      assert_equal 'done', string_data_type_PV.export_value
      assert_equal '25-07-2018', date_data_type_PV.export_value
    end
  end

  def test_export_value_for_card_type_project_variable_should_fetch_card_number_and_name
    with_new_project do |project|
      card = create_card!(:name => 'First card')
      project_variable = create_plv!(project, :name => 'CardTypePV', :data_type => ProjectVariable::CARD_DATA_TYPE, value: card.id)

      assert_equal '#1 First card', project_variable.export_value
    end

  end

  private

  def binding_count_in_db(plv)
    VariableBinding.count(:conditions => {:project_variable_id => plv.id})
  end
end
