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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportCardDefaultsAndTransitionsTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_export_import_card_defaults_that_point_to_card_ids_should_be_updated_with_the_new_card_ids
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')

      card_defaults = type_story.card_defaults
      card_defaults.update_properties 'Planning iteration' => iteration1.id
      card_defaults.save!

      @export_file = create_project_exporter!(project, @user).export
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!

      iteration1 = imported_project.cards.find_by_name('iteration1')
      type_story = imported_project.card_types.find_by_name('story')
      cp_iteration = imported_project.find_property_definition('Planning iteration')

      iteration_action = type_story.card_defaults.actions.detect { |action| action.target_id == cp_iteration.id }
      assert_equal iteration1.id.to_s, iteration_action.value
    end
  end

  def test_export_import_transitions_that_point_to_card_ids_should_be_updated_with_the_new_card_ids
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')

      transition = create_transition(project, 'hi', :required_properties => {'Planning iteration' => iteration2.id}, :set_properties => {'Planning iteration' => iteration1.id})

      @export_file = create_project_exporter!(project, @user).export
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!

      iteration1 = imported_project.cards.find_by_name('iteration1')
      iteration2 = imported_project.cards.find_by_name('iteration2')
      transition = imported_project.transitions.find_by_name('hi')
      cp_iteration = imported_project.find_property_definition('Planning iteration')

      prerequisite = transition.prerequisites.detect { |prereq| prereq.property_definition_id == cp_iteration.id }
      action = transition.actions.detect { |action| action.target_id == cp_iteration.id }

      assert_equal iteration2.id.to_s, prerequisite.value
      assert_equal iteration1.id.to_s, action.value
    end
  end

  #  Bug 2285
  def test_set_user_property_as_current_user_in_transition_should_not_be_lost_when_export_and_import_project
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_property_definitions :status => ['new', 'open', 'fixed']
    setup_user_definition('owner')

    start_a_bug = create_transition(@project, 'start a bug', :set_properties => {:Status => 'in progress', :owner => PropertyType::UserType:: CURRENT_USER})
    owner_action = start_a_bug.actions.select{|action|action.property_definition.name == 'owner'}.first
    assert_equal PropertyType::UserType::CURRENT_USER, owner_action.value

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    start_a_bug = imported_project.transitions.find_by_name('start a bug')
    owner_action = start_a_bug.actions.select{|action|action.property_definition.name == 'owner'}.first
    status_action = start_a_bug.actions.select{|action|action.property_definition.name == 'status'}.first
    assert_equal 'in progress', status_action.value
    assert_equal PropertyType::UserType:: CURRENT_USER, owner_action.value
  end

  def test_set_user_property_as_current_user_in_transition_should_not_be_lost_when_export_and_import_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_property_definitions :status => ['new', 'open', 'fixed']
    setup_user_definition('owner')

    start_a_bug = create_transition(@project, 'start a bug', :set_properties => {:Status => 'in progress', :owner => PropertyType::UserType:: CURRENT_USER})
    owner_action = start_a_bug.actions.select{|action|action.property_definition.name == 'owner'}.first
    assert_equal PropertyType::UserType::CURRENT_USER, owner_action.value

    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    start_a_bug = imported_project.transitions.find_by_name('start a bug')
    owner_action = start_a_bug.actions.select{|action|action.property_definition.name == 'owner'}.first
    status_action = start_a_bug.actions.select{|action|action.property_definition.name == 'status'}.first
    assert_equal 'in progress', status_action.value
    assert_equal PropertyType::UserType:: CURRENT_USER, owner_action.value
  end

  def test_set_user_property_as_current_user_in_card_defaults_should_not_be_lost_when_export_and_import_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_user_definition('owner')
    card_type_defaults = @project.card_types.first.card_defaults
    card_type_defaults.update_properties('owner' => PropertyType::UserType::CURRENT_USER)
    card_type_defaults.save!
    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    assert_equal(PropertyType::UserType::CURRENT_USER, imported_project.card_types.first.card_defaults.property_value_for('owner').db_identifier)
  end

  def test_set_user_property_as_current_user_in_card_defaults_should_not_be_lost_when_export_and_import_project
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_user_definition('owner')
    card_type_defaults = @project.card_types.first.card_defaults
    card_type_defaults.update_properties('owner' => PropertyType::UserType::CURRENT_USER)
    card_type_defaults.save!
    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    assert_equal(PropertyType::UserType::CURRENT_USER, imported_project.card_types.first.card_defaults.property_value_for('owner').db_identifier)
  end

  def test_set_user_property_as_NOT_SET_in_card_defaults_should_not_change_to_random_value_when_export_and_import_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_user_definition('owner')
    card_type_defaults = @project.card_types.first.card_defaults
    card_type_defaults.update_properties('owner' => nil)
    card_type_defaults.save!
    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    assert_equal(nil, imported_project.card_types.first.card_defaults.property_value_for('owner').db_identifier)
  end

  def test_set_user_property_as_NOT_SET_in_card_defaults_should_not_change_to_random_value_when_export_and_import_project
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_user_definition('owner')
    card_type_defaults = @project.card_types.first.card_defaults
    card_type_defaults.update_properties('owner' => nil)
    card_type_defaults.save!
    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    assert_equal(nil, imported_project.card_types.first.card_defaults.property_value_for('owner').db_identifier)
  end

  #  Bug 2386
  def test_should_set_action_value_to_require_user_input_if_the_action_is_targeting_a_user_property_when_exporting_project_as_template
    user = login_as_member
    project = create_project(:users => [user])
    setup_user_definition('owner')
    set_owner = create_transition(project, 'set_owner', :set_properties => {:owner => user.id})

    export_file = create_project_exporter!(project, User.current, :template => true).export
    imported_project = create_project_importer!(User.current, export_file).process!

    set_owner = imported_project.transitions.find_by_name('set_owner')
    assert_equal 1, set_owner.actions.size
    assert_equal 'owner', set_owner.actions.first.property_definition.name
    assert_equal nil, set_owner.actions.first.value
    assert set_owner.actions.first.require_user_to_enter
    assert_equal 0, set_owner.prerequisites.size
  end

  #  Bug 2386
  def test_should_keep_action_value_as_it_is_if_the_action_is_targeting_a_user_property_and_action_value_is_NOT_SET_when_exporting_project_as_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_user_definition('owner')
    set_owner = create_transition(@project, 'set_owner', :set_properties => {:owner => nil})

    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    set_owner = imported_project.transitions.find_by_name('set_owner')
    assert_equal 1, set_owner.actions.size
    assert_equal 'owner', set_owner.actions.first.property_definition.name
    assert_equal nil, set_owner.actions.first.value
    assert !set_owner.actions.first.require_user_to_enter
    assert_equal 0, set_owner.prerequisites.size
  end

  #  Bug 2386
  def test_should_delete_required_properties_which_are_related_with_user_property_and_set_as_spcified_team_member_if_exporting_project_as_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_property_definitions :status => ['new', 'open', 'fixed']
    setup_user_definition('owner')
    set_status_and_require_owner = create_transition(@project, 'set_status_and_require_owner', :set_properties => {:status => 'in progress'}, :required_properties => {:owner => @user.id})
    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    @set_status_and_require_owner = imported_project.transitions.find_by_name('set_status_and_require_owner')
    assert_equal 1, @set_status_and_require_owner.actions.size
    assert_equal 'status', @set_status_and_require_owner.actions.first.property_definition.name
    assert_equal 0, @set_status_and_require_owner.prerequisites.size
  end

  def test_transition_action_value_should_be_nil_after_imported_when_the_action_sets_project_variable_to_user_property
    @user = login_as_member
    @project = with_new_project(:users => [@user]) do |project|
      owner = setup_user_definition('owner')
      plv = create_plv!(project, :name => 'plv_user', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user.id, :property_definitions => [owner])
      create_transition(project, 'set_owner', :set_properties => {:owner => plv.display_name})
      project
    end
    @export_file = create_project_exporter!(@project, User.current).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    transition = imported_project.transitions.find_by_name('set_owner')
    plv = imported_project.project_variables.find_by_name('plv_user')
    assert_equal 1, transition.actions.size
    assert transition.actions.first.uses_project_variable?(plv)
    assert_equal nil, transition.actions.first.value
  end

  def test_export_import_transitions_that_point_to_tree_configuration_ids_should_be_updated_with_the_new_tree_configuration_ids
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      create_transition(project, 'hi', :card_type => type_release, :remove_from_trees => [configuration])

      imported_project = export_and_reimport(project)
      imported_transition = imported_project.transitions.first
      imported_project_tree = imported_project.tree_configurations.first
      tree_belonging_action = imported_transition.actions.select { |action| action.is_a?(RemoveFromTreeTransitionAction) }.first

      assert_equal imported_project_tree.id, tree_belonging_action.target_id
    end
  end

  def test_should_clear_tree_relationship_properties_on_transitions_when_importing_template
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1, iteration2 = ['iteration1', 'iteration2'].collect { |card_name| project.cards.find_by_name(card_name) }
      create_transition(project, transition_name = 'iteration 1 to iteration 2', :required_properties => {'Planning iteration' => iteration1.id}, :set_properties => {'Planning iteration' => iteration2.id})

      imported_project = export_and_reimport(project, :template => true)
      imported_transition = imported_project.transitions.first
      assert_equal(0, imported_transition.prerequisites.size)
      assert_nil imported_transition.actions.first.value
    end
  end

  def test_should_clear_card_relationship_properties_on_transitions_when_importing_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_card_relationship_property_definition('related card')
    card1, card2 = ['card 1', 'card 2'].collect { |card_name| create_card!(:name => card_name) }
    transition = create_transition(@project, transition_name = 'card 1 to card 2', :required_properties => {'related card' => card1.id}, :set_properties => {'related card' => card2.id})

    imported_project = export_and_reimport(@project, :template => true)
    imported_transition = imported_project.transitions.first
    assert_equal(0, imported_transition.prerequisites.size)
    assert_nil imported_transition.actions.first.value
  end

  # Bug #4743
  def test_remove_from_tree_transition_should_retain_value_when_importing_template
    @user = login_as_member

    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      remove_from_tree_transition = create_transition(project, 'hi', :card_type => type_release, :remove_from_trees => [configuration])

      imported_project = export_and_reimport(project, :template => true)
      imported_transition = imported_project.transitions.first
      tree_belonging_action = imported_transition.actions.first

      assert_equal TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE, tree_belonging_action.value
    end
  end

  # Bug 5083
  def test_should_add_card_defaults_to_import_when_missing_from_export
    @user = login_as_member
    @project = create_project(:users => [@user])
    @project.with_active_project do |project|
      project.card_types.each { |card_type| card_type.card_defaults.destroy }
    end

    export_and_reimport(@project).with_active_project do |imported_project|
      imported_project.card_types.each { |card_type| assert_not_nil(card_type.card_defaults) }
    end
  end

  def test_should_not_have_any_zombie_card_defaults_on_import
    @user = login_as_member
    @project = create_project(:users => [@user])

    export_and_reimport(@project).with_active_project do |imported_project|
      imported_project.card_defaults.each do |card_defaults|
        assert !card_defaults.card_type.nil?, "card_defaults with nil card_type exists"
      end
    end
  end

  def test_should_carry_over_user_property_values_in_prerequisites_and_actions_for_full_project_export
    @user = login_as_member
    with_new_project do |project|
      setup_property_definitions :status => ['in progress', 'fixed']
      setup_user_definition 'Developer'
      setup_user_definition 'Tester'

      dev = create_user!
      tester = create_user!
      project.add_member(dev)
      project.add_member(tester)

      fix_bug = project.transitions.new(:name => 'mark fixed', :project_id => project.id)
      fix_bug.add_value_prerequisite('Developer', dev.id)
      fix_bug.add_value_prerequisite('Status', 'in progress')
      fix_bug.add_set_value_action('Tester', tester.id)
      fix_bug.add_set_value_action('Status', 'fixed')
      fix_bug.save!

      exported_project = create_project_exporter!(project, User.current, :template => false).export

      dev.destroy_without_callbacks
      tester.destroy_without_callbacks

      new_dev = User.create!(:login => dev.login, :name => dev.name, :email => dev.email, :password => 'foo123.', :password_confirmation => 'foo123.')
      new_tester = User.create!(:login => tester.login, :name => tester.name, :email => tester.email, :password => 'foo123.', :password_confirmation => 'foo123.')

      login(dev.email)

      create_project_importer!(User.current, exported_project).process!.reload.with_active_project do |imported_project|
        new_mark_fixed = imported_project.transitions.find_by_name('mark fixed')
        assert new_mark_fixed.uses?(imported_project.property_value('Developer', new_dev.id))
        assert new_mark_fixed.uses?(imported_project.property_value('Tester', new_tester.id))
      end
    end
  end
end
