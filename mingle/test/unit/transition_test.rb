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

class TransitionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, TreeFixtures::FeatureTree

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  #bug 2510
  def test_available_to_should_work_with_hidden_property
    card = create_card!(:name => 'card status is open', :status => 'open' )
    @project.find_property_definition('status').update_attribute(:hidden, true)

    transition = create_transition(@project, 'close', :set_properties => {:status => 'closed'})
    assert transition.available_to?(card)

    transition = create_transition(@project, 'release 1', :required_properties => {:status => 'open'}, :set_properties => {:release => '1'})
    assert transition.available_to?(card)

    transition = create_transition(@project, 'new status to release 1', :required_properties => {:status => 'new'}, :set_properties => {:release => '1'})
    assert !transition.available_to?(card)
  end

  def test_set_value_action_should_require_user_to_enter_when_the_property_has_that_value
    transition = create_transition(@project, 'open', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    assert transition.actions.first.require_user_to_enter
    assert_equal nil, transition.actions.first.value
  end

  def test_should_not_allow_creation_of_parenthesised_values_through_inline_addition_from_pre_reqs
    transition = create_transition_without_save(@project, 'open', :required_properties => {:status => '(foo)'}, :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    transition.validate
    assert_equal "Status: #{'(foo)'.bold} is an invalid value. Value cannot both start with '(' and end with ')'", transition.errors.full_messages.join
  end

  def test_should_not_allow_creation_of_parenthesised_values_through_inline_addition_from_actions
    transition = create_transition_without_save(@project, 'open', :set_properties => {:status => '(bar)'})
    transition.validate
    assert_equal "Status: #{'(bar)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.", transition.errors.full_messages.join
  end

  def test_set_value_action_should_require_user_to_enter_when_the_user_property_has_that_value
    user_property_definition = @project.find_property_definition('dev')
    fix_bug = create_transition(@project, 'fix bug', :set_properties => {:dev => Transition::USER_INPUT_REQUIRED})
    assert fix_bug.actions.first.require_user_to_enter
  end

  def test_creating_user_input_required_transitions_creates_correct_action_type
    transition = create_transition(@project, 'user input req', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    assert_equal UserInputRequiredTransitionAction, transition.actions.first.class
  end

  def test_creating_user_input_optional_transitions_creates_correct_action_type
    transition = create_transition(@project, 'user input opt', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    assert_equal UserInputOptionalTransitionAction, transition.actions.first.class
  end

  def test_require_user_to_enter
    transition = create_transition(@project, 'open and need user input', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    assert transition.require_user_to_enter?
    transition = create_transition(@project, 'open', :set_properties => {:status => 'open'})
    assert !transition.require_user_to_enter?
  end

  def test_require_user_to_enter_property_definitions
    open_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :iteration => '1'})

    assert_equal 1, open_with_user_input.require_user_to_enter_property_definitions_in_smart_order.size
    assert_equal 'Status', open_with_user_input.require_user_to_enter_property_definitions_in_smart_order.first.name
  end

  def test_require_user_to_enter_property_definitions_returns_array_in_smart_order
    open_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :Release => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_REQUIRED})
    assert_equal ['Priority', 'Release', 'Status'], open_with_user_input.require_user_to_enter_property_definitions_in_smart_order.collect(&:name)
  end

  def test_accepts_user_input_property_definitions_returns_array_in_smart_order
    transition = create_transition(@project, 'can have user input', :set_properties => {:status => 'open', :Release => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_OPTIONAL})
    assert_equal ['Priority', 'Release'], transition.accepts_user_input_property_definitions_in_smart_order.collect(&:name)
  end

  def test_execute_transition_with_property_definitions_that_require_user_to_enter
    open_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:Status => Transition::USER_INPUT_REQUIRED})

    card = create_card!(:name => 'card')
    open_with_user_input.execute(card, {'Status' => 'open'})
    assert_equal 'open', card.reload.cp_status

    close = create_transition(@project, 'close', :set_properties => {:Status => 'closed'})
    close.execute(card, {'Status' => 'open'})
    assert_equal 'closed', card.reload.cp_status
  end

  def test_execute_transition_with_property_definitions_that_have_optional_user_input
    optional_user_input = create_transition(@project, 'optional user input', :set_properties => {:Status => Transition::USER_INPUT_OPTIONAL})

    card = create_card!(:name => 'card1')
    optional_user_input.execute(card, {'Status' => 'open'})
    assert_equal 'open', card.reload.cp_status

    card2 = @project.cards.create!(:name => 'card2', :card_type_name => 'Card', :cp_status => 'closed')
    optional_user_input.execute(card)
    assert_equal 'closed', card2.reload.cp_status
  end

  def test_execute_transition_with_property_definitions_that_require_user_to_enter_ignores_case
    open_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:Status => Transition::USER_INPUT_REQUIRED})
    card = create_card!(:name => 'card')
    open_with_user_input.execute(card, {'status' => 'open'})
    assert_equal 'open', card.reload.cp_status
  end

  def test_execute_transition_with_hidden_property_definitions_that_require_user_to_enter_ignores_case
    @project.find_property_definition(:status).update_attribute :hidden, true
    @project.reload

    open_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:Status => Transition::USER_INPUT_REQUIRED})
    card = create_card!(:name => 'card')
    open_with_user_input.execute(card, {'status' => 'open'})
    assert_equal 'open', card.reload.cp_status

    open_with_user_input.execute(card, {'status' => 'new open'})
    assert_equal 'new open', card.reload.cp_status
  end

  def test_value_set_for_require_user_enter_property_definition
    status_with_user_input = create_transition(@project, 'open and need user input', :set_properties => {:Status => Transition::USER_INPUT_REQUIRED})
    assert_equal Transition::USER_INPUT_REQUIRED, status_with_user_input.value_set_for(@project.find_property_definition('Status'))

    set_release_to_one = create_transition(@project, 'set release to one', :set_properties => {:Iteration => 1, :Status => Transition::USER_INPUT_REQUIRED})
    assert_equal Transition::USER_INPUT_REQUIRED, set_release_to_one.value_set_for(@project.find_property_definition('Status'))
    assert_equal '1', set_release_to_one.value_set_for(@project.find_property_definition('Iteration'))

    status_with_optional_user_input = create_transition(@project, 'open and want user input', :set_properties => {:Status => Transition::USER_INPUT_OPTIONAL})
    assert_equal Transition::USER_INPUT_OPTIONAL, status_with_optional_user_input.value_set_for(@project.find_property_definition('Status'))
  end

  def test_value_set_for_tree_belongings_should_recognize_children_option
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')
      tree_belongings_with_children = create_transition(@project, 'tree belongings with children', :card_type => iteration_type, :remove_from_trees_with_children => [tree])
      assert_equal TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE, tree_belongings_with_children.value_set_for(TreeBelongingPropertyDefinition.new(tree))
    end
  end

  def test_value_set_for_tree_belongings_should_recognize_just_this_card_option
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')
      tree_belongings_just_this_card = create_transition(@project, 'tree belongings just this card', :card_type => iteration_type, :remove_from_trees => [tree])
      assert_equal ':just_this_card', tree_belongings_just_this_card.value_set_for(TreeBelongingPropertyDefinition.new(tree))
    end
  end

  def test_should_save_comment_on_transition_execution_if_require_comment
    open_with_comment = create_transition(@project, 'open with comment', :set_properties => {:Status => 'open'}, :require_comment => true)
    card = create_card!(:name => 'I am card')
    open_with_comment.execute(card, nil, {:content => "I want to open it"})
    card.reload
    assert_equal 'open', card.cp_status
    assert_equal "I want to open it", card.discussion.first.murmur
  end

  def test_should_show_errors_when_the_comment_is_empty_if_require_comment
    open_with_comment = create_transition(@project, 'open with comment', :set_properties => {:Status => 'open'}, :require_comment => true)
    card = create_card!(:name => 'I am card')
    open_with_comment.execute_with_validation(card, nil, "")
    assert !open_with_comment.errors.empty?
    assert_equal nil , card.reload.cp_status
  end

  def test_should_save_comment_on_transition_execution_when_the_comment_inputed_whether_require_comment_or_not
    open_with_comment = create_transition(@project, 'open with comment', :set_properties => {:Status => 'open'})
    card = create_card!(:name => 'I am card')
    open_with_comment.execute_with_validation(card, nil, {:content => "I want to open it"})
    card.reload
    assert_equal 'open', card.cp_status
    assert_equal "I want to open it", card.discussion.first.murmur
  end

  def test_should_not_save_comment_and_not_record_error_on_transition_execution_when_the_comment_is_empty_and_comment_not_required
    open_with_comment = create_transition(@project, 'open with comment', :set_properties => {:Status => 'open'})
    card = create_card!(:name => 'I am card')
    open_with_comment.execute_with_validation(card, nil, {:content => ""})
    card.reload
    assert_equal 'open', card.cp_status
    assert_equal 0, card.discussion.size
  end

  def test_should_not_allow_creation_of_invalid_values_using_inline_create_of_either_pre_requisites_or_actions
    with_new_project do |project|
      int = setup_numeric_property_definition 'int', []
      transition = project.transitions.new(:name => 'numeric', :card_type => project.card_types.first)
      transition.add_set_value_action('int', 'foo')
      transition.add_value_prerequisite('int', 'bar')

      assert !transition.save
      assert_include "Property to set #{'int'.bold}: #{'foo'.bold} is an invalid numeric value", transition.errors.full_messages.join
      assert_match "Required property #{'int'.bold}: #{'bar'.bold} is an invalid numeric value", transition.errors.full_messages.join
    end
  end

  # bug 2790
  def test_should_not_allow_creation_or_update_of_transitions_with_same_name
    testo_transition = create_transition(@project, 'testo', :set_properties => {:Status => 'open'})

    big_testo_transition = create_transition_without_save(@project, 'TESTO', :set_properties => {:iteration => '1'})
    big_testo_transition.save

    assert !big_testo_transition.errors.empty?
    assert_equal ['Name has already been taken'], big_testo_transition.errors.full_messages

    matic_transition = create_transition(@project, 'matic', :set_properties => {:Status => 'open'})
    matic_transition.name = 'tEsTo'
    matic_transition.save

    assert !matic_transition.errors.empty?
    assert_equal ['Name has already been taken'], matic_transition.errors.full_messages
  end

  def test_should_allow_remove_from_tree_as_the_only_action
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')
      remove_tree_transition = create_transition_without_save(project, 'remove from tree', :card_type => iteration_type, :remove_from_trees_with_children => [tree])
      remove_tree_transition.save
      assert remove_tree_transition.errors.empty?
    end
  end

  def test_should_not_allow_tree_belongings_to_be_used_when_card_type_is_missing
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      remove_tree_transition = create_transition_without_save(project, 'remove from tree', :remove_from_trees_with_children => [tree])
      remove_tree_transition.save
      assert !remove_tree_transition.errors.empty?
      assert_equal ['Tree card type must be present when removing cards from trees'], remove_tree_transition.errors.full_messages
    end
  end

  def test_should_not_allow_tree_belongings_to_be_used_when_card_type_is_not_in_tree
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      card_type = project.card_types.find_by_name('Card')
      remove_tree_transition = create_transition_without_save(project, 'remove from tree', :card_type => card_type, :remove_from_trees_with_children => [tree])
      remove_tree_transition.save
      assert !remove_tree_transition.errors.empty?
      assert_equal ["Card type #{card_type.name.bold} must be a valid type for the tree #{tree.name.bold}"], remove_tree_transition.errors.full_messages
    end
  end

  def test_required_properties_should_support_project_variables
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [@project.find_property_definition('Release')]
    current_release.save!
    @project.reload
    transition = create_transition(@project, 'open story in the current release',
                                              :required_properties => {:release => current_release.display_name},
                                              :set_properties => {:status => 'open'})
    card_1 = create_card!(:name => 'I am card', :status => 'closed')
    card_2 = create_card!(:name => 'I am card', :release => '5', :status => 'closed')
    assert !transition.available_to?(card_1)
    assert transition.available_to?(card_2)
    transition.execute(card_2)
    assert_equal 'open', card_2.reload.cp_status
  end

  def test_set_properties_should_support_project_variables
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [@project.find_property_definition('Release')]
    current_release.save!
    @project.reload
    transition = create_transition(@project, 'set to current release',
                                              :set_properties => {:release => current_release.display_name})
    card = create_card!(:name => 'I am card', :release => '1')
    transition.execute(card)
    assert_equal '5', card.reload.cp_release
  end

  def test_value_set_for_returns_project_variable_name
    release = @project.find_property_definition('Release')
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [release]
    current_release.save!
    transition = create_transition(@project, 'set to current release',
                                              :set_properties => {:release => current_release.display_name})

    assert_equal '(current release)', transition.value_set_for(release)
  end

  def test_uses_project_variable
    release = @project.find_property_definition('Release')
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [release]
    current_release.save!
    transition = create_transition(@project, 'set to closed', :set_properties => {:status => 'closed'})
    assert !transition.uses_project_variable?(current_release)

    transition_uses_project_variable = create_transition(@project, 'set to current release', :set_properties => {:release => current_release.display_name})
    assert transition_uses_project_variable.uses_project_variable?(current_release)
  end

  def test_uses_method_detects_usages_via_project_variables
    release = @project.find_property_definition('Release')
    release_2 = release.enumeration_values.detect { |ev| ev.value == '2' }
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2', :property_definition_ids => [release.id.to_s])

    transition = create_transition(@project, 'set to current release', :set_properties => {:release => current_release.display_name})

    assert transition.uses?(release_2.as_property_value)
  end

  def test_uses_member
    member = find_member
    transition = create_transition(@project, 'set to member', :set_properties => {:dev => member.id})
    assert uses_member?(transition, member)
    assert !uses_member?(transition, find_project_admin)

    transition = create_transition(@project, 'set to closed', :required_properties => {:dev => member.id}, :set_properties => {:status => 'closed'})
    assert uses_member?(transition, member)
    assert !uses_member?(transition, find_project_admin)

    transition = create_transition(@project, 'user input req', :set_properties => {:dev => Transition::USER_INPUT_REQUIRED})
    assert !uses_member?(transition, member)

    transition = create_transition(@project, 'user input opt', :set_properties => {:dev => Transition::USER_INPUT_OPTIONAL})
    assert !uses_member?(transition, member)

    transition = create_transition(@project, 'has to be current user', :required_properties => {:dev => PropertyType::UserType::CURRENT_USER}, :set_properties => {:status => 'closed'})
    assert !uses_member?(transition, member)
    assert !uses_member?(transition, find_project_admin)

    transition = create_transition(@project, 'set to current user', :set_properties => {:dev => PropertyType::UserType::CURRENT_USER})
    assert !uses_member?(transition, member)
    assert !uses_member?(transition, find_project_admin)
  end

  def test_specifies_member
    member = find_member
    transition = create_transition(@project, 'set to member', :set_properties => {:dev => member.id}, :user_prerequisites => [member.id])
    assert transition.specified_to_user?(member)
    assert !transition.specified_to_user?(find_project_admin)
  end

  def test_should_not_be_available_to_a_card_if_defined_as_being_available_to_an_empty_group
    group = create_group('group')
    assert_equal 0, group.user_memberships.count
    transition = create_transition(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    assert_equal false, transition.available_to?(@project.cards.first)
  end

  def test_should_be_available_to_a_card_if_defined_as_being_available_to_a_group_which_has_current_user
    assert @project.member?(User.current)
    group = create_group('group', [User.current])
    assert_equal 1, group.user_memberships.count
    transition = create_transition(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    assert_equal true, transition.available_to?(@project.cards.first)
  end

  def test_should_be_avaialable_to_a_card_if_defined_as_being_available_to_multiple_groups_any_of_which_has_the_current_user
    assert @project.member?(User.current)
    group = create_group('group', [User.current])
    other_group = create_group('othergroup')
    assert_equal 1, group.user_memberships.count
    assert_equal 0, other_group.user_memberships.count
    transition = create_transition(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id, other_group.id])
    assert_equal true, transition.available_to?(@project.cards.first)
  end

  def test_should_not_be_able_to_specify_both_is_user_and_in_group_prerequisite
    group = create_group('group')
    member = find_member
    transition = create_transition_without_save(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :user_prerequisites => [member.id], :group_prerequisites => [group.id])
    assert !transition.save
    assert_include "Transition can't have both is user and in group prerequisites", transition.errors.full_messages.join
  end

  def test_should_know_if_transition_has_in_group_prerequisite
    transition_without_in_group = create_transition(@project, 'without group', :set_properties => {:status => 'fix'})
    assert_equal false, transition_without_in_group.has_group_prerequisites?
    group = create_group('group')
    transition_with_in_group = create_transition(@project, 'with group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    assert_equal true, transition_with_in_group.has_group_prerequisites?
  end

  def test_should_know_if_transition_specifies_group_as_prerequisite
    group = create_group('group')
    another_group = create_group('another_group')
    transition_with_in_group = create_transition(@project, 'with group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    assert_equal true, transition_with_in_group.uses_group?(group)
    assert_equal false, transition_with_in_group.uses_group?(another_group)
  end

  def test_should_be_available_to_all_users_upon_deletion_of_the_last_group_that_it_is_available_to
    group = create_group('group')
    another_group = create_group('another_group')
    transition_with_in_group = create_transition(@project, 'with group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id, another_group.id])

    group.destroy
    assert_equal false, transition_with_in_group.reload.available_to_all_users?

    another_group.destroy
    assert_equal true, transition_with_in_group.reload.available_to_all_users?
  end

  def test_should_know_if_any_transition_specifies_user
    member = find_member
    transition = create_transition(@project, 'set to member', :set_properties => {:dev => member.id}, :user_prerequisites => [member.id])
    assert Transition.find_any_specifying_user(member, :project => @project).any?
    assert !Transition.find_any_specifying_user(find_project_admin, :project => @project).any?
  end

  def test_should_know_if_any_transitions_for_a_project_use_a_member
    member = find_member

    transition = create_transition(@project, 'set to member', :set_properties => {:dev => member.id})
    assert Transition.find_all_using_member(member, :project => @project).any?
    assert !Transition.find_all_using_member(find_project_admin, :project => @project).any?
    transition.destroy

    transition = create_transition(@project, 'set to closed', :required_properties => {:dev => member.id}, :set_properties => {:status => 'closed'})
    assert Transition.find_all_using_member(member, :project => @project).any?
    assert !Transition.find_all_using_member(find_project_admin, :project => @project).any?
    transition.destroy

    transition = create_transition(@project, 'user input req', :set_properties => {:dev => Transition::USER_INPUT_REQUIRED})
    assert !Transition.find_all_using_member(member, :project => @project).any?

    transition = create_transition(@project, 'user input opt', :set_properties => {:dev => Transition::USER_INPUT_OPTIONAL})
    assert !Transition.find_all_using_member(member, :project => @project).any?

    transition = create_transition(@project, 'has to be current user', :required_properties => {:dev => PropertyType::UserType::CURRENT_USER}, :set_properties => {:status => 'closed'})
    assert !Transition.find_all_using_member(member, :project => @project).any?
    assert !Transition.find_all_using_member(find_project_admin, :project => @project).any?

    transition = create_transition(@project, 'set to current user', :set_properties => {:dev => PropertyType::UserType::CURRENT_USER})
    assert !Transition.find_all_using_member(member, :project => @project).any?
    assert !Transition.find_all_using_member(find_project_admin, :project => @project).any?
  end

  def test_create_transition_that_set_value_as_date_project_variable
    start_date = @project.find_property_definition('start date')
    deadline_date = create_plv!(@project, :name => 'deadline date', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '03 Jun 1982', :property_definition_ids => [start_date.id.to_s])
    transition = create_transition(@project, 'set start date to deadline date', :set_properties => {'start date' => deadline_date.display_name})
    card = create_card!(:name => 'I am card')
    transition.execute(card)
    assert_equal '1982-06-03', start_date.value(card.reload).to_s
  end

  # bug 3202
  def test_can_use_require_user_to_enter_with_relationship_properties
    login_as_member
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      transition = create_transition(project, 'hi', :set_properties => {'Planning iteration' => Transition::USER_INPUT_REQUIRED})
      planning_iteration = project.find_property_definition('Planning iteration')

      assert_equal 1, transition.actions.size
      assert transition.actions.first.property_definition == planning_iteration
      assert transition.actions.first.require_user_to_enter
    end
  end

  def test_should_not_allow_transition_to_have_multiple_relationship_actions_per_tree
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')

      cp_iteration = project.find_property_definition('planning iteration')
      cp_release = project.find_property_definition('planning release')

      transition = create_transition_without_save(project, 'oh yeah', :set_properties => {'Planning iteration' => iteration1.id, 'Planning release' => release1.id})
      transition.save

      assert !transition.errors.empty?
      assert_equal ['Transition cannot set more than one relationship property per tree.'], transition.errors.full_messages
    end
  end

  def test_should_not_allow_card_type_to_be_changed_for_a_card_that_is_used_as_a_transition_prerequisite_or_action
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')

      oh_yeah = create_transition_without_save(project, 'oh yeah', :set_properties => {'Planning release' => release1.id})
      oh_yeah.save!

      oh_no = create_transition_without_save(project, 'oh no!', :set_properties => {'Planning release' => release1.id})
      oh_no.save!

      release1.card_type_name = 'iteration'
      assert_false release1.save

      assert_equal ["Cannot change card type because card is being used in transitions: #{'oh no!'.bold}, #{'oh yeah'.bold}"], release1.errors.full_messages
    end
  end

  def test_should_delete_a_transition_that_uses_a_card_as_the_value_of_a_card_relationship_property_in_either_prerequisutes_or_actions
    with_card_query_project do |project|
      first_card = project.cards.first

      create_transition_without_save(project, 'require first card', :required_properties => {'related card' => first_card.id}, :set_properties => {'status' => 'open'}).save!
      create_transition_without_save(project, 'set first card', :set_properties => {'related card' => first_card.id}).save!

      assert_equal ['require first card', 'set first card'], project.transitions.collect(&:name).sort

      first_card.destroy

      assert_equal [], project.reload.transitions
    end
  end

  def test_should_fill_in_release_when_transition_with_iteration_action_is_executed
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')

      cp_iteration = project.find_property_definition('planning iteration')
      cp_release = project.find_property_definition('planning release')

      transition = create_transition(project, 'oh yeah', :set_properties => {'Planning iteration' => iteration1.id})

      card_not_on_tree = project.cards.create!(:name => 'not on tree yet', :card_type_name => 'story')
      transition.execute(card_not_on_tree)

      assert_equal iteration1.name, cp_iteration.value(card_not_on_tree.reload).name
      assert_equal release1.name, cp_release.value(card_not_on_tree).name
    end
  end

  def test_should_create_transition_with_card_type_project_variable_when_it_is_not_set
    login_as_member
    create_tree_project(:init_five_level_tree) do |project, tree, config|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      cp_iteration = project.find_property_definition('planning iteration')
      current_iteration = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :property_definition_ids => [cp_iteration.id], :value => '')
      transition = create_transition(project, 'the man in capri pants', :set_properties => {'Planning iteration' => current_iteration.display_name})
      assert_equal current_iteration.display_name, transition.actions.first.target_property.display_value
    end
  end

  def test_should_create_transition_with_card_type_project_variable_as_a_required_value
    login_as_member
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types

      iteration1 = project.cards.find_by_name('iteration1')
      cp_iteration = project.find_property_definition('planning iteration')
      current_iteration = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :property_definition_ids => [cp_iteration.id], :value => iteration1.id)
      transition = create_transition(project, 'the man in capri pants', :required_properties => {'Planning iteration' => current_iteration.display_name}, :set_properties => {'Planning iteration' => current_iteration.display_name})
      assert_equal current_iteration.display_name, transition.prerequisites.first.required_property.display_value

      assert_equal 1, transition.actions.size
      assert_equal 1, transition.prerequisites.size

      story = create_card!(:name => 'I am story', :card_type => type_story)
      assert !transition.available_to?(story)
      cp_iteration.update_card(story, iteration1)
      story.save
      assert transition.available_to?(story)
    end
  end

  #bug1390
  def test_should_remove_user_from_the_transition_that_assigned_to_them_when_remove_user_from_team_memeber
    bob = User.find_by_login('bob')
    @project.add_member(bob)
    @project.save!
    @project.reload
    transition = create_transition(@project, 'for bob', :set_properties => {'status' => 'closed'}, :user_prerequisites => [bob.id])
    assert_equal 1, transition.prerequisites.size
    @project.remove_member(bob)
    assert transition.reload.prerequisites.empty?
  end

  #4218
  def test_should_not_fail_transition_creation_even_if_the_file_has_been_loaded_twice
    assert_nothing_raised do
      new_path_to_transition_file = File.join(File.dirname(__FILE__), '..', '..', 'app', 'models', 'transition.rb')
      require new_path_to_transition_file
      create_transition(@project, 'close', :set_properties => {:status => 'closed'})
      $:.delete(File.dirname(new_path_to_transition_file))
    end
  end

  def test_should_completable_on_card_when_available_to_card_but_no_user_input_required
    card = create_card!(:name => 'card status is open', :status => 'open' )
    assert create_transition(@project, 'close', :set_properties => {:status => 'closed'}).completable_on?(card)
    assert !create_transition(@project, 'close new card', :required_properties => {:status => 'new'}, :set_properties => {:status => 'closed'}).completable_on?(card)
  end

  def test_should_completable_on_card_when_user_input_required_is_not_blank
    card = create_card!(:name => 'card status is open', :status => 'open')
    card.comment = {:content => 'comment'}
    change_status = create_transition(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_REQUIRED}, :require_comment => true)
    assert change_status.completable_on?(card)

    card = create_card!(:name => 'card status is open')
    card.comment = {:content => 'comment'}
    assert !change_status.completable_on?(card)

    card = create_card!(:name => 'card status is open', :status => 'open')
    assert !change_status.completable_on?(card)

    card = create_card!(:name => 'card status is open')
    assert !change_status.completable_on?(card)
  end

  def test_completable_on_card_which_is_nil
    assert create_transition(@project, 'close', :set_properties => {:status => 'closed'}).completable_on?

    change_status = create_transition(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_REQUIRED}, :require_comment => true)
    assert !change_status.completable_on?
  end

  def test_can_add_remove_card_from_tree_to_actions_list
    with_three_level_tree_project do |project|
      tree = project.find_tree_configuration('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')
      transition = create_transition(@project, 'close card', :card_type => iteration_type, :set_properties => {:status => 'closed'})
      assert_equal PropertyDefinitionTransitionAction, transition.actions.first.class

      transition.add_remove_card_from_tree_action(tree, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE)
      assert_equal ['PropertyDefinitionTransitionAction', 'RemoveFromTreeTransitionAction'].sort, transition.actions.collect(&:class).collect(&:name).sort
    end
  end

  # Bug 4950.
  def test_tree_belonging_actions_should_also_return_relationship_property_actions_only_for_types_above_in_the_order_they_are_in_the_tree
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      story_type = project.card_types.find_by_name('story')
      transition = create_transition(project, name = 'say now', :card_type => story_type, :remove_from_trees => [tree])
      assert_equal ['three level tree', 'Planning release', 'Planning iteration'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_actions_should_order_non_tree_properties_before_tree_properties
    with_new_project do |project|
      init_planning_tree_types
      # planning tree should be created before status so that card type position should not be considered.
      planning_tree = create_three_level_tree.configuration
      story_type = project.card_types.find_by_name('story')
      setup_property_definitions(:status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      story_type.property_definitions += [status]
      story_type.save!

      iteration1 = project.cards.find_by_name('iteration1')
      transition = create_transition(project, 'hi there', :card_type => story_type, :set_properties => {:status => 'closed', 'Planning iteration' => iteration1.id})

      assert_equal ['status', 'Planning iteration'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_actions_should_order_non_tree_properties_by_their_position_for_the_card_type
    with_new_project do |project|
      init_planning_tree_types
      # add status to story type before material to show that ordering is not alphabetical.
      story_type = project.card_types.find_by_name('story')
      setup_property_definitions(:status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      story_type.property_definitions += [status]
      story_type.save!

      setup_property_definitions(:material => ['wood', 'gold'])
      material = project.find_property_definition('material')
      story_type.property_definitions += [material]
      story_type.save!

      transition = create_transition(project, 'hi there', :card_type => story_type, :set_properties => {:status => 'closed', :material => 'wood'})

      assert_equal ['status', 'material'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_actions_should_order_tree_properties_before_tree_belongings
    with_new_project do |project|
      # Order of tree creation should be planning tree (named "three_level_tree") and then feature tree (named "System breakdown") to show that creation order doesn't matter.
      init_planning_tree_types
      planning_tree = create_three_level_tree
      feature_tree = create_three_level_feature_tree

      story_type = project.card_types.find_by_name('story')
      iteration1, reporting = ['iteration1', 'reporting'].collect { |card_name| project.cards.find_by_name(card_name) }
      transition = create_transition(project, 'hi there', :card_type => story_type, :set_properties => {'Planning iteration' => reporting.id}, :remove_from_trees => [feature_tree])

      assert_equal ['Planning iteration', 'System breakdown', 'System breakdown module', 'System breakdown feature'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_actions_should_order_tree_properties_by_their_tree_names_for_tree_properties
    with_new_project do |project|
      # Order of tree creation should be planning tree (named "three_level_tree") and then feature tree (named "System breakdown") to show that creation order doesn't matter.
      init_planning_tree_types
      planning_tree = create_three_level_tree
      feature_tree = create_three_level_feature_tree

      story_type = project.card_types.find_by_name('story')
      iteration1, reporting = ['iteration1', 'reporting'].collect { |card_name| project.cards.find_by_name(card_name) }
      transition = create_transition(project, 'hi there', :card_type => story_type, :set_properties => {'Planning iteration' => iteration1.id, 'System breakdown feature' => reporting.id})

      assert_equal ['System breakdown feature', 'Planning iteration'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_actions_order_of_trees_using_top_level_card_type_should_show_trees_in_alpha_order
    with_new_project do |project|
      release_type, iteration_type, story_type = init_planning_tree_types
      a_tree, b_tree, c_tree = ['c', 'A', 'b'].collect { |tree_name| create_ris_tree(tree_name) }

      transition = create_transition(project, 'hi there', :card_type => release_type, :remove_from_trees => [c_tree, b_tree, a_tree])

      assert_equal ['A', 'b', 'c'], transition.display_actions.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_required_properties_should_order_non_tree_properties_before_tree_properties
    with_new_project do |project|
      init_planning_tree_types
      # planning tree should be created before status so that card type position should not be considered.
      planning_tree = create_three_level_tree.configuration
      story_type = project.card_types.find_by_name('story')
      setup_property_definitions(:status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      story_type.property_definitions += [status]
      story_type.save!

      iteration1 = project.cards.find_by_name('iteration1')
      transition = create_transition(project, 'hi there', :card_type => story_type, :required_properties => {:status => 'closed', 'Planning iteration' => iteration1.id}, :set_properties => {:status => 'open'})

      assert_equal ['status', 'Planning iteration'], transition.display_required_properties.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_required_properties_should_order_non_tree_properties_by_card_type_property_order
    with_new_project do |project|
      init_planning_tree_types
      # add status to story type before material to show that ordering is not alphabetical.
      story_type = project.card_types.find_by_name('story')
      setup_property_definitions(:status => ['fixed', 'new', 'open', 'closed','in progress'])
      status = project.find_property_definition('status')
      story_type.property_definitions += [status]
      story_type.save!

      setup_property_definitions(:material => ['wood', 'gold'])
      material = project.find_property_definition('material')
      story_type.property_definitions += [material]
      story_type.save!

      transition = create_transition(project, 'hi there', :card_type => story_type, :required_properties => {:status => 'closed', :material => 'wood'}, :set_properties => {:status => 'open'})

      assert_equal ['status', 'material'], transition.display_required_properties.collect(&:property_definition).collect(&:name)
    end
  end

  # Bug 4950.
  def test_display_required_properties_should_order_tree_properties_alphabetically
    with_new_project do |project|
      init_planning_tree_types
      feature_tree = create_three_level_feature_tree
      planning_tree = create_three_level_tree

      story_type = project.card_types.find_by_name('story')
      iteration1, reporting = ['iteration1', 'reporting'].collect { |card_name| project.cards.find_by_name(card_name) }
      transition = create_transition(project, 'hi there', :card_type => story_type, :required_properties => {'Planning iteration' => iteration1.id, 'System breakdown feature' => reporting.id}, :set_properties => {'Planning iteration' => nil})

      assert_equal ['Planning iteration', 'System breakdown feature'], transition.display_required_properties.collect(&:property_definition).collect(&:name)
    end
  end

  def test_accepts_user_input_method
    transitions = []
    transitions << create_transition(@project, 'user input required', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    transitions << create_transition(@project, 'user input optional', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    transitions << create_transition(@project, 'comment required', :set_properties => {:status => 'open'}, :require_comment => true)

    transitions.each do |transition|
      assert transition.accepts_user_input?, "transition #{transition.name} should accept user input but doesn't"
    end

    regular_transition = create_transition(@project, 'regular transition', :set_properties => {:status => 'open'})
    assert !regular_transition.accepts_user_input?
  end

  def test_transition_with_only_user_input_optional_action_is_considered_valid
    transition = create_transition_without_save(@project, 'user input optional', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    transition.save
    assert transition.valid?
  end

  def test_user_input_required_transitions_cannot_be_executed_if_required_property_values_are_not_provided
    transition = create_transition(@project, 'user input required', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'open')

    transition.execute_with_validation(card, {'status' => 'closed'})
    assert_equal 'closed', card.reload.cp_status

    transition.execute_with_validation(card)
    assert_equal 'closed', card.reload.cp_status
    assert_equal ["Value of Status property for this transition must not be empty."], transition.errors.full_messages
  end

  def test_user_input_optional_transitions_do_not_overwrite_property_with_nil_if_it_is_not_provided
    transition = create_transition(@project, 'user input required', :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_OPTIONAL})
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'open', :cp_priority => 'high')
    transition.execute_with_validation(card, {'status' => 'closed'})
    assert_equal 'closed', card.reload.cp_status
    assert_equal 'high', card.cp_priority  # priority was not provided and so should remain 'high'
  end

  def test_cannot_set_required_properties_to_nil
    transition = create_transition(@project, 'user input required', :set_properties => {:status => Transition::USER_INPUT_REQUIRED, :priority => Transition::USER_INPUT_OPTIONAL, :material => Transition::USER_INPUT_OPTIONAL})
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'open')

    transition.execute_with_validation(card, {'status' => nil})
    assert_equal ["Value of Status property for this transition must not be empty."], transition.errors.full_messages
    assert_equal 'open', card.cp_status
  end

  def test_can_set_optional_properties_to_nil
    transition = create_transition(@project, 'user input required', :set_properties => {:status => Transition::USER_INPUT_REQUIRED,:material => Transition::USER_INPUT_OPTIONAL})
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'open', :cp_material => 'wood')
    transition.execute_with_validation(card, {'status' => 'closed', 'material' => nil})
    assert_nil card.cp_material # make sure we can set optional properties to nil
  end

  def test_card_is_not_saved_on_execution_if_nothing_was_changed
    # manual verification for this works on mysql, yet the test itself doesn't -- am not sure why and don't care much
    for_postgresql do
      transition1 = create_transition(@project, 'user input optional', :set_properties => {:material => Transition::USER_INPUT_OPTIONAL})
      transition2 = create_transition(@project, 'regular transition', :set_properties => {:material => 'wood'})
      card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_material => 'wood')

      original_latest_version = card.version
      transition2.execute_with_validation(card)
      assert_equal original_latest_version, card.reload.version

      original_latest_version = card.version
      transition1.execute_with_validation(card, {'material' => 'wood'})
      assert_equal original_latest_version, card.reload.version

      original_latest_version = card.version
      transition2.execute_with_validation(card, {}, {:content => "some comment"})
      assert_not_equal original_latest_version, card.reload.version
    end
  end

  def test_execute_with_validation_traps_transition_not_available_exception
    transition = create_transition(@project, 'hello', :required_properties => {:status => 'open'}, :set_properties => {:material => 'wood'})
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'closed')
    transition.execute_with_validation(card)
    assert_equal ["#{'hello'.bold} is not applicable to Card ##{card.number}."], transition.errors.full_messages
  end

  def test_uses_should_work_for_transition_with_set_value
    status = @project.find_property_definition('status')
    transition = create_transition(@project, 'hello', :required_properties => {:status => '(set)'}, :set_properties => {:material => 'wood'})
    assert !transition.uses?(PropertyValue.create_from_url_identifier(status,'open'))
  end

  def test_uses_member_should_work_for_transition_with_set_value
    transition = create_transition(@project, 'hello', :required_properties => {:dev => '(set)'}, :set_properties => {:material => 'wood'})
    assert !uses_member?(transition, User.find_by_login('bob'))
  end

  def test_should_map_transition_id_to_card_type
    with_three_level_tree_project do |project|
      card_type = project.card_types.first
      transition = create_transition(project, 'close', :set_properties => {:status => 'closed'}, :card_type => card_type)
      @transitions = [transition]

      assert_equal transition.id, Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:transition_id]
      assert_equal transition.card_type.name, Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:card_type]
    end
  end

  def test_should_map_transition_id_to_transition_actions
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name("story")
      status = project.find_property_definition('status')
      transition = create_transition(project, 'close', :set_properties => {:status => 'closed'}, :card_type => type_story)
      @transitions = [transition]

      assert_equal transition.id, Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:transition_id]
      assert_equal [{:id => status.id, :name => 'status', :to => 2}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions]
    end
  end

  def test_should_map_transition_id_to_transition_prerequisite
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name("story")
      size = project.find_property_definition('size')
      status = project.find_property_definition('status')
      transition = create_transition(project, 'close', :required_properties => {:status => 'closed'},:set_properties => {:size => 5}, :card_type => type_story)
      @transitions = [transition]

      assert_equal transition.id, Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:transition_id]
      assert_equal [{:id => size.id, :name=>"size"}, {:id => status.id, :name=>"status", :from=>2}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions]
    end
  end

  def test_should_map_enumerated_required_property_value_and_enumerated_sets_property_value_of_transition
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name("story")
      transition = create_transition(project, 'close', :required_properties => {:status => 'open'}, :set_properties => {:status => 'closed'}, :card_type => type_story)

      @transitions = [transition]
      status = type_story.property_definitions.find{ |prop_def| prop_def.name == 'status'}
      open_value = status.enumeration_values.find{ |enum_value| enum_value.value == 'open'}
      closed_value = status.enumeration_values.find{ |enum_value| enum_value.value == 'closed'}
      assert_equal([{:id => status.id, :name => 'status', :from => open_value.position, :to => closed_value.position}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_free_numeric_property_value
    with_three_level_tree_project do |project|
      login_as_admin
      free_number_prop_def = project.create_numeric_free_property_definition(:name => 'lucky_number')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(free_number_prop_def)
      transition = create_transition(project, 'resize to 4', :required_properties => {:lucky_number => 2}, :set_properties => {:lucky_number => 4}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => free_number_prop_def.id, :name => 'lucky_number', :from => 2, :to => 4}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_free_text_property_value
    with_three_level_tree_project do |project|
      login_as_admin
      free_text_prop_def = project.create_text_definition(:name => 'lucky_text')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(free_text_prop_def)
      transition = create_transition(project, 'change to phoenix', :required_properties => {:lucky_text => 'tin'}, :set_properties => {:lucky_text => 'phoenix'}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => free_text_prop_def.id, :name => 'lucky_text', :from => 'tin', :to => 'phoenix'}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_plv_property_value
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name("story")
      prop_def_of_size = type_story.property_definitions.find{ |prop_def| prop_def.name == 'size' };
      to_numeric_plv = create_plv!(project, :name => 'lucky_number', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :property_definition_ids => [prop_def_of_size.id])
      from_numeric_plv = create_plv!(project, :name => 'from_lucky_number', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2', :property_definition_ids => [prop_def_of_size.id])

      transition = create_transition(project, 'plv transition', :required_properties => {:size => from_numeric_plv.display_name}, :set_properties => {:size => to_numeric_plv.display_name}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => prop_def_of_size.id, :name => 'size', :from => from_numeric_plv.display_name, :to => to_numeric_plv.display_name}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_special_value_on_free_text_property
    with_three_level_tree_project do |project|
      login_as_admin
      free_text_prop_def = project.create_text_definition(:name => 'lucky_text')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(free_text_prop_def)
      transition = create_transition(project, 'change to phoenix', :required_properties => {:lucky_text => 'tin'}, :set_properties => {:lucky_text => Transition::USER_INPUT_REQUIRED}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => free_text_prop_def.id, :name => 'lucky_text', :from => 'tin', :to => '(user input - required)'}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_special_value_on_free_numeric_property
    with_three_level_tree_project do |project|
      login_as_admin
      lucky_number = project.create_numeric_free_property_definition(:name => 'lucky_number')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(lucky_number)
      transition = create_transition(project, 'change to lucky_number', :required_properties => {:lucky_number => 2}, :set_properties => {:lucky_number => Transition::USER_INPUT_REQUIRED}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => lucky_number.id, :name => 'lucky_number', :from => 2, :to => '(user input - required)'}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_date_property_value
    with_three_level_tree_project do |project|
      login_as_admin
      birth_day = project.create_date_definition(:name => 'birth_day')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(birth_day)
      transition = create_transition(project, 'set birth day', :required_properties => {:birth_day => nil}, :set_properties => {:birth_day => '03 Jun 1982'}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => birth_day.id, :name => 'birth_day',:from => '(not set)', :to => '03 Jun 1982'.to_date}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_special_today_date_property_value
    with_three_level_tree_project do |project|
      login_as_admin
      birth_day = project.create_date_definition(:name => 'birth_day')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(birth_day)
      transition = create_transition(project, 'set birth day', :set_properties => {:birth_day => '(today)'}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => birth_day.id, :name => 'birth_day', :to => '(today)'}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_special_user_input_required_property_value_when_property_type_is_date
    with_three_level_tree_project do |project|
      login_as_admin
      birth_day = project.create_date_definition(:name => 'birth_day')
      type_story = project.card_types.find_by_name("story")
      type_story.add_property_definition(birth_day)
      transition = create_transition(project, 'set birth day', :set_properties => {:birth_day => Transition::USER_INPUT_REQUIRED}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => birth_day.id, :name => 'birth_day', :to => Transition::USER_INPUT_REQUIRED}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_user_property_value
    login_as_admin
    with_new_project do |project|
      lucky_guy = project.create_user_definition!(:name => 'lucky_guy')
      type_story = project.card_types.create!(:name => 'story')
      type_story.add_property_definition(lucky_guy)
      transition = create_transition(project, 'change lucky guy', :set_properties => {:lucky_guy => User.current.id}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => lucky_guy.id, :name => 'lucky_guy', :to => User.current.name}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_card_property_value
    with_three_level_tree_project do |project|
      related_card = project.property_definitions.select{|prop| prop.name == "related card"}.first
      type_story = project.card_types.find_by_name("story")
      card = project.cards.first
      transition = create_transition(project, 'related to', :set_properties => {'related card' => card.id}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => related_card.id, :name => 'related card', :to => card.number}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_tree_relationship_property_value
    with_three_level_tree_project do |project|
      release_property = project.property_definitions.select{|prop| prop.name == 'Planning release'}.first
      type_story = project.card_types.find_by_name("story")
      release = project.cards.find_by_name('release1')
      transition = create_transition(project, 'to be finished in release1', :set_properties => {'Planning release' => release.id}, :card_type => type_story)

      @transitions = [transition]
      assert_equal([{:id => release_property.id, :name => 'Planning release', :to => release.number}], Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first[:property_definitions])
    end
  end

  def test_should_map_transition_name
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name("story")
      prop_def_of_size = type_story.property_definitions.find{ |prop_def| prop_def.name == 'size' };

      transition = create_transition(project, 'a transition', :required_properties => {:size => 2}, :set_properties => {:size => 4}, :card_type => type_story)

      @transitions = [transition]
      assert_equal(
      {
        :transition_name      =>"a transition",
        :card_type            =>"story",
        :card_type_id         => type_story.id,
        :property_definitions =>[ { :to => 4, :from => 2, :id => prop_def_of_size.id, :name => "size" } ],
        :transition_id        => transition.id
        },
      Transition.map_from_transition_id_to_card_type_and_property_definitions(@transitions).first)
    end
  end

  def test_should_describe_availability_of_transition_to_various_groups_appropriately
    jimmy_group = create_group('jimmy')
    timmy_group = create_group('timmy')
    timmy_boy_group = create_group('timmy boy')

    trans1 = create_transition(@project, 'eins', :set_properties => {:status => 'fix'}, :group_prerequisites => [jimmy_group.id])
    trans2 = create_transition(@project, 'zwei', :set_properties => {:status => 'fix'}, :group_prerequisites => [jimmy_group.id, timmy_group.id])
    trans3 = create_transition(@project, 'drei', :set_properties => {:status => 'fix'}, :group_prerequisites => [jimmy_group.id, timmy_group.id, timmy_boy_group.id])

    assert_equal_ignoring_mingle_formatting "This transition can be used by members of the following user group: jimmy", trans1.describe_usability
    assert_equal_ignoring_mingle_formatting "This transition can be used by members of the following user groups: jimmy and timmy", trans2.describe_usability
    assert_equal_ignoring_mingle_formatting "This transition can be used by members of the following user groups: jimmy, timmy, and timmy boy", trans3.describe_usability
  end

  def test_should_describe_availability_of_transition_to_various_users_appropriately
    bob = User.find_by_login('bob')
    member = User.find_by_login('member')
    first = User.find_by_login('first')
    trans1 = create_transition(@project, 'eins', :set_properties => {:status => 'fix'}, :user_prerequisites => [bob.id])
    trans2 = create_transition(@project, 'zwei', :set_properties => {:status => 'fix'}, :user_prerequisites => [bob.id, member.id])
    trans3 = create_transition(@project, 'drei', :set_properties => {:status => 'fix'}, :user_prerequisites => [bob.id, member.id, first.id])

    assert_equal_ignoring_mingle_formatting "This transition can be used by the following user: #{bob.name.bold}", trans1.describe_usability
    assert_equal_ignoring_mingle_formatting "This transition can be used by the following users: #{bob.name} and #{member.name}", trans2.describe_usability
    assert_equal_ignoring_mingle_formatting "This transition can be used by the following users: #{bob.name}, #{first.name}, and #{member.name}", trans3.describe_usability
  end

  def test_should_skip_user_based_prerequisites_when_param_set_to_true
    group = create_group('group')
    transition = create_transition(@project, 'some transition', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
    assert_equal true, transition.available_to?(@project.cards.first, true)
  end

  private

  def uses_member?(transition, member)
    Transition.find_all_using_member(member, :project => transition.project).include?(transition)
  end

  def find_member
    User.find_by_login('member')
  end

  def find_project_admin
    User.find_by_login('proj_admin')
  end

  def create_ris_tree(name)
    release_type, iteration_type, story_type = find_planning_tree_types
    configuration = Project.current.tree_configurations.create!(:name => name)
    configuration.update_card_types({
      release_type => {:position => 0, :relationship_name => "#{name} release"},
      iteration_type => {:position => 1, :relationship_name => "#{name} iteration"},
      story_type => {:position => 2}
    })
    configuration
  end
end
