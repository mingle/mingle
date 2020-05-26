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

class DropListOptionsHelperTest < ActiveSupport::TestCase
  include DropListOptionsHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_plv_options_should_be_in_smart_sort
    status = @project.find_property_definition('status')
    create_plv!(@project, :name => 'item1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
    create_plv!(@project, :name => 'item2', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
    create_plv!(@project, :name => 'item10', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
    assert_equal ['(item1)', '(item2)', '(item10)'], plv_options_for_droplist(status.reload).collect(&:first)
  end

  def test_plv_options_are_plv_display_name_pairs
    release = @project.find_property_definition('Release')
    plv = create_plv!(@project, :name => 'item1', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :property_definition_ids => [release.id])
    assert_equal ['(item1)', '(item1)'], plv_options_for_droplist(release.reload).first
  end

  def test_plv_options_should_include_current_user_for_user_property
    dev = @project.find_property_definition('dev')
    assert_equal [['(current user)', '(current user)']], plv_options_for_droplist(dev)
  end

  def test_current_user_should_be_the_last_of_plv_options
    dev = @project.find_property_definition('dev')
    create_plv!(@project, :name => 'my plv', :data_type => ProjectVariable::USER_DATA_TYPE, :property_definition_ids => [dev.id])
    assert_equal([["(my plv)", "(my plv)"], ['(current user)', '(current user)']], plv_options_for_droplist(dev.reload))
  end

  def test_plv_options_should_include_today_for_date_property
    start_date = @project.find_property_definition('start date')
    assert_equal([['(today)', '(today)']], plv_options_for_droplist(start_date))
  end

  def test_options_for_lane_droplist_should_include_not_set
    status = @project.find_property_definition('status')
    assert_include ["(not set)", ""], options_for_lane_droplist(status)
  end

  def test_options_for_lane_droplist_should_include_lane_values_of_an_enum_prop
    status = @project.find_property_definition('status')
    options = options_for_lane_droplist(status)
    status.lane_values.each do |option|
      assert_include(option, options)
    end
  end

  def test_options_for_lane_droplist_should_include_lane_values_of_a_user_prop
    dev = @project.find_property_definition('dev')
    options = options_for_lane_droplist(dev)
    dev.lane_values.each do |option|
      assert_include(option, options)
    end
  end

  def test_options_for_lane_droplist_for_a_tree_prop_should_only_include_all_values
    with_three_level_tree_project do |project|
      iteration = project.find_property_definition('Planning iteration')
      assert_include ["(not set)", ""], options_for_lane_droplist(iteration)
      assert_equal iteration.values.size + 1, options_for_lane_droplist(iteration).size
    end
  end

  def test_plv_options_of_tree_belonging_property_definition_should_be_empty
    assert_equal [], plv_options_for_droplist(TreeBelongingPropertyDefinition.new(nil))
  end

  def test_options_for_droplist_should_include_property_definition_name_values
    status = @project.find_property_definition('status')
    options = options_for_droplist(status)
    assert status.name_values.size > 0
    status.name_values.each do |option|
      assert_include(option, options)
    end
  end

  def test_options_for_droplist_should_include_not_set_for_nullable_property
    status = @project.find_property_definition('status')
    assert status.nullable?
    options = options_for_droplist(status)
    assert_include PropertyValue::NOT_SET_VALUE_PAIR, options
  end

  def test_options_for_droplist_should_not_contain_not_set_when_property_def_is_not_nullable
    assert !Project.card_type_definition.nullable?
    assert_equal [["Card", "Card"]], options_for_droplist(Project.card_type_definition)
  end

  def test_options_droplist_should_include_plv_related
    iteration = @project.find_property_definition('iteration')
    create_plv!(@project, :name => 'my plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [iteration.id] )
    assert_equal([['(not set)', ''], ['(my plv)', '(my plv)'], ['1', '1'], ['2', '2']], options_for_droplist(iteration.reload))
  end

  def test_text_property_prerequisite_dropdown_contains_current_value
    status = @project.find_property_definition('status')
    transition = create_transition(@project, 'close bug', :required_properties => { 'status' => 'open' }, :set_properties => { 'status' => 'closed' })
    options = droplist_options_for_transition_prerequisite(transition, status)

    assert_include ['open', 'open'], options
  end

  def test_droplist_options_for_transition_prerequisite_should_include_igore_and_not_set_and_name_values
    iteration = @project.find_property_definition('iteration')
    transition = create_transition(@project, 'open story in the current release',
                                              :required_project_variables => {:iteration => '1'},
                                              :set_properties => {:iteration => '2'})
    options = droplist_options_for_transition_prerequisite(transition, iteration)
    assert_equal [["(any)", ":ignore"], ['(set)', '(set)'], ['(not set)', ''], ['1', '1'], ['2', '2']], options
  end

  def test_droplist_options_for_transition_prerequisite_should_include_current_user_for_user_prop
    dev = @project.find_property_definition('dev')
    whatever_transition = create_transition(@project, 'sign up', :set_properties => { 'status' => 'in progress' })
    options = droplist_options_for_transition_prerequisite(whatever_transition, dev)
    assert options.include?(UserPropertyDefinition.current)
  end

  def test_text_free_property_prerequisite_options_contains_current_entered_value_in_transition
    text_free_prop = @project.find_property_definition('id')
    transition = create_transition(@project, 'id 3 => 1', :required_properties => { 'id' => '3' }, :set_properties => { 'id' => '1' })
    options = droplist_options_for_transition_prerequisite(transition, text_free_prop)

    assert_equal [["(any)", ":ignore"], ['3', '3'], ['(set)', '(set)'], ['(not set)', '']], options
  end

  def test_text_free_property_prerequisite_options_with_a_transition_unrelated_in_required_properties
    text_free_prop = @project.find_property_definition('id')
    transition = create_transition(@project, 'status new => open', :required_properties => { 'status' => 'new' }, :set_properties => { 'status' => 'open' })
    options = droplist_options_for_transition_prerequisite(transition, text_free_prop)

    assert_equal [["(any)", ":ignore"], ['(set)', '(set)'], ['(not set)', '']], options
  end

  def test_formula_property_prerequisite_options_should_include_current_entered_value_in_transition
    with_new_project do |project|
      num_property = setup_numeric_property_definition('estimate', [1, 2, 3])
      formula_property = setup_formula_property_definition('final estimate', "estimate * 2")

      transition = create_transition(@project, 'final estimate 1 => estimate 2', :required_properties => { 'final estimate' => '1' }, :set_properties => { 'estimate' => '2' })
      options = droplist_options_for_transition_prerequisite(transition, formula_property)

      assert_equal [["(any)", ":ignore"], ['1', '1'], ['(set)', '(set)'], ['(not set)', '']], options
    end
  end

  def test_formula_property_prerequisite_options_with_a_transition_unrelated_in_required_properties
    with_new_project do |project|
      num_property = setup_numeric_property_definition('estimate', [1, 2, 3])
      formula_property = setup_formula_property_definition('final estimate', "estimate * 2")

      transition = create_transition(@project, 'estimate 1 => 2', :required_properties => { 'estimate' => '1' }, :set_properties => { 'estimate' => '2' })
      options = droplist_options_for_transition_prerequisite(transition, formula_property)

      assert_equal [["(any)", ":ignore"], ['(set)', '(set)'], ['(not set)', '']], options
    end
  end

  def test_user_property_prerequisite_options_include_current_user
    dev = @project.find_property_definition('dev')
    bob = User.find_by_login('bob')
    member = User.find_by_login('member')

    transition = create_transition(@project, 'bob => member', :required_properties => { 'dev' => bob.id }, :set_properties => { 'dev' => member.id })
    options = droplist_options_for_transition_prerequisite(transition, dev)
    expected = [["(any)", ":ignore"], ['(set)', '(set)'], ['(not set)', ''], ['(current user)', '(current user)']].concat(dev.name_values)
    assert_equal expected, options
  end

  def test_date_property_prerequisite_options_should_include_today
    start_date = @project.find_property_definition('start date')
    transition = create_transition(@project, 'change start date', :required_properties => { 'start date' => '1982-06-03' }, :set_properties => { 'status' => 'open' })
    options = droplist_options_for_transition_prerequisite(transition, start_date)
    expected = [["(any)", ":ignore"], ['(set)', '(set)'], ['(not set)', ''], ['(today)', '(today)']]
    assert_equal expected, options
  end

  def test_droplist_options_for_transition_action_should_include_current_user_for_user_prop
    dev = @project.find_property_definition('dev')
    transition = create_transition(@project, 'sign up', :required_properties => { 'status' => 'open' }, :set_properties => { 'status' => 'in progress' })
    options = droplist_options_for_transition_action(transition, dev)
    assert options.include?(UserPropertyDefinition.current)
  end

  def test_droplist_options_for_transition_action_does_not_return_optional_input_value_twice_for_numeric_text_properties
    with_new_project do |project|
      numeric_text_property_definition = setup_numeric_text_property_definition('hello')
      transition = create_transition(project, 'whoa jeez', :set_properties => { 'hello' => Transition::USER_INPUT_OPTIONAL })

      expected_options = [["(no change)", ":ignore"],
                          ["(not set)", ""],
                          ["(user input - optional)", "(user input - optional)"],
                          ["(user input - required)", "(user input - required)"]]
      assert_equal expected_options, droplist_options_for_transition_action(transition, numeric_text_property_definition)
    end
  end

  # bug 7816
  def test_droplist_options_for_allow_any_number_property_transition_prerequisite_should_not_return_set_value_twice
    with_value_macro_test_project do |project|
      freesize = project.find_property_definition('freesize')
      transition = create_transition(project, 'some transition', :required_properties => { 'freesize' => '(set)' }, :set_properties => { 'freesize' => '1' })
      assert_equal 1, droplist_options_for_transition_prerequisite(transition, freesize).select { |option| option == ['(set)', '(set)'] }.size, "Should only have one '(set)' in the options list."
    end
  end

  def test_should_have_today_prerequisite_and_action_conditions_for_date_properties
    start_date = @project.find_property_definition('start date')
    transition = create_transition(@project, 'finish', :required_properties  => { 'status'  => 'open' }, :set_properties => { 'start date' => PropertyType::DateType::TODAY } )

    options = droplist_options_for_transition_action(transition, start_date)
    assert options.include?(DatePropertyDefinition.today)
  end

  def test_should_not_try_to_load_a_user_for_an_empty_value
    dev = @project.find_property_definition('dev')
    transition = create_transition(@project, 'sign up', :required_properties => { 'status' => 'open' }, :set_properties => { 'status' => 'in progress', 'dev' => nil })

    options = droplist_options_for_transition_action(transition, dev)
    assert options.include?(PropertyValue::NOT_SET_VALUE_PAIR)
  end

  def test_text_property_action_dropdown_contains_current_value
    status = @project.find_property_definition('status')
    transition = create_transition(@project, 'close bug', :required_properties => { 'status' => 'open' }, :set_properties => { 'status' => 'closed' })
    options = droplist_options_for_transition_action(transition, status)

    assert options.include?(['closed', 'closed'])
    assert options.include?(['(no change)', PropertyValue::IGNORED_IDENTIFIER])
    assert options.include?(['(not set)', ''])
  end

  def transition_user_input_options
    Transition::USER_INPUT_VALUES.collect { |value| [value, value] }
  end

  def test_text_free_property_action_options_contains_current_entered_value_in_transition
    text_free_prop = @project.find_property_definition('id')
    transition = create_transition(@project, 'id 3 => 1', :required_properties => { 'id' => '3' }, :set_properties => { 'id' => '1' })
    options = droplist_options_for_transition_action(transition, text_free_prop)

    assert_equal [["(no change)", ":ignore"], ['1', '1'], ['(not set)', '']].concat(transition_user_input_options), options
  end

  def test_text_free_property_action_options_with_a_transition_unrelated_in_required_properties
    text_free_prop = @project.find_property_definition('id')
    transition = create_transition(@project, 'status new => open', :required_properties => { 'status' => 'new' }, :set_properties => { 'status' => 'open' })
    options = droplist_options_for_transition_action(transition, text_free_prop)

    assert_equal [["(no change)", ":ignore"], ['(not set)', '']].concat(transition_user_input_options), options
  end

  def test_formula_property_action_options_should_include_current_entered_value_in_transition
    with_new_project do |project|
      num_property = setup_numeric_property_definition('estimate', [1, 2, 3])
      formula_property = setup_formula_property_definition('final estimate', "estimate * 2")

      transition = create_transition(@project, 'estimate 1 => final estimate 2', :required_properties => { 'estimate' => '1' }, :set_properties => { 'final estimate' => '2' })
      options = droplist_options_for_transition_action(transition, formula_property)

      assert_equal [["(no change)", ":ignore"], ['2', '2'], ['(not set)', '']].concat(transition_user_input_options), options
    end
  end

  def test_formula_property_action_options_with_a_transition_unrelated_in_set_properties
    with_new_project do |project|
      num_property = setup_numeric_property_definition('estimate', [1, 2, 3])
      formula_property = setup_formula_property_definition('final estimate', "estimate * 2")

      transition = create_transition(@project, 'estimate 1 => 2', :required_properties => { 'estimate' => '1' }, :set_properties => { 'estimate' => '2' })
      options = droplist_options_for_transition_action(transition, formula_property)

      assert_equal [["(no change)", ":ignore"], ['(not set)', '']].concat(transition_user_input_options), options
    end
  end

  # def test_card_property_transition_options_contain_appropriate_meta_values
  #   status = @project.find_property_definition('status')
  #   plv = create_plv!(@project, :name => 'plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'hello')
  #   plv.property_definitions = [status]
  #   plv.save!
  #   status.reload
  #
  #   assert_equal [['(any)', ":ignore"], ['(not set)', ''], ['(plv)', '(plv)']], extra_options_for_transition_prerequisite_card_property_editor(status)
  #   assert_equal [['(no change)', ":ignore"], ['(not set)', ''], ['(user input - optional)', '(user input - optional)'], ['(user input - required)', '(user input - required)'], ['(plv)', '(plv)']], extra_options_for_transition_action_card_property_editor(status)
  # end


  def test_options_for_droplist_for_enumeration_property_definition
    assert_equal([["(not set)", ""], ["fixed", "fixed"], ["new", "new"], ["open", "open"], ["closed", "closed"], ["in progress", "in progress"]],       options_for_droplist(@project.find_property_definition('status')))
  end

  def test_options_for_droplist_for_cards_filter_should_include_plv
    iteration = @project.find_property_definition('iteration')
    create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::STRING_DATA_TYPE)
    create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [iteration.id] )
    iteration.reload
    assert_equal([["(any)", ":ignore"], ['(not set)', ''], ['(current iteration)', '(current iteration)'], ['1', '1'], ['2', '2']],
      options_for_droplist_for_cards_filter(iteration))
  end

  # Bug 4679.
  def test_options_for_droplist_for_plvs_should_be_alphabetical_order
    status_property_definition = @project.find_property_definition('status')
    # Using "New" rather than "new" to show that case does not matter.
    %w(New open closed).each { |status| create_plv!(@project, :name => "#{status} status", :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status_property_definition.id] ) }
    status_property_definition.reload
    assert_equal([
                    ['(any)'          , ':ignore'        ],
                    ['(not set)'      , ''               ],
                    # Project variables
                    ['(closed status)', '(closed status)'],
                    ['(New status)'   , '(New status)'   ],
                    ['(open status)'  , '(open status)'  ],
                    # Property values
                    ["fixed", "fixed"], ["new", "new"], ["open", "open"], ["closed", "closed"], ["in progress", "in progress"]
                 ],
                 options_for_droplist_for_cards_filter(status_property_definition))
  end

  def test_transition_popup_property_editor_options_for_enum_text_property
    status = @project.find_property_definition('status')
    options = transition_popup_property_editor_options(status)
    assert_equal [['(not set)', ''], ['fixed', 'fixed'], ['new', 'new'], ['open', 'open'], ['closed', 'closed'],['in progress', 'in progress']], options
  end

  def test_should_get_transition_popup_options_with_select_instead_of_not_set_for_required_non_card_property
    not_card_prop = @project.find_property_definition('status')
    options = transition_popup_property_editor_options(not_card_prop, true)
    assert_equal [['fixed', 'fixed'], ['new', 'new'], ['open', 'open'], ['closed', 'closed'],['in progress', 'in progress']], options
  end

  def test_should_be_empty_options_for_required_card_property
    with_new_project do |project|
      card_prop = setup_card_relationship_property_definition("related_card")
      options = transition_popup_property_editor_options(card_prop, true)
      assert_equal [], options
    end
  end

  def test_transition_popup_options_should_include_plv_related_for_required_card_relationship_property
    with_new_project do |project|
      card_prop = setup_card_relationship_property_definition("related_card")

      plv = create_plv!(project, :name => 'card variable', :data_type => ProjectVariable::CARD_DATA_TYPE)
      plv.property_definitions = [card_prop]
      plv.save!

      options = transition_popup_property_editor_options(card_prop, true)
      assert_equal [['(card variable)', '(card variable)']], options
    end
  end

  def test_transition_popup_options_should_include_plv_related_for_option_card_relationship_property
    with_new_project do |project|
      card_prop = setup_card_relationship_property_definition("related_card")

      plv = create_plv!(project, :name => 'card variable', :data_type => ProjectVariable::CARD_DATA_TYPE)
      plv.property_definitions = [card_prop]
      plv.save!

      options = transition_popup_property_editor_options(card_prop, false)
      assert_equal [['(not set)', ''], ['(card variable)', '(card variable)']], options
    end
  end

  def test_transition_popup_property_editor_options_should_not_show_select_for_required_card_properties
    with_three_level_tree_project do |project|
      iteration = project.find_property_definition('Planning iteration')
      iteration_select_options = transition_popup_property_editor_options(iteration, true)
      assert_equal [], iteration_select_options
    end
  end

  def test_transition_popup_options_should_include_plv_related
    status = @project.find_property_definition('status')
    plv = create_plv!(@project, :name => 'text variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open')
    plv.property_definitions = [status]
    plv.save!
    status.reload

    options = transition_popup_property_editor_options(status)
    assert_equal [['(not set)', ''], ['(text variable)', '(text variable)'], ['fixed', 'fixed'], ['new', 'new'], ['open', 'open'], ['closed', 'closed'],['in progress', 'in progress']], options
  end

  def test_transition_popup_options_should_include_today_for_date_property
    date_prop = @project.find_property_definition('start date')
    options = transition_popup_property_editor_options(date_prop)
    assert_equal [['(not set)', ''], ['(today)', '(today)']], options
  end

  def test_transition_popup_options_including_plv_related_for_date_property
    date_prop = @project.find_property_definition('start date')
    plv = create_plv!(@project, :name => 'date variable', :data_type => ProjectVariable::DATE_DATA_TYPE)
    plv.property_definitions = [date_prop]
    plv.save!
    date_prop.reload

    options = transition_popup_property_editor_options(date_prop)
    assert_equal [['(not set)', ''], ['(date variable)', '(date variable)'], ['(today)', '(today)']], options
  end

  def test_transition_popup_options_including_plv_related_for_user_property
    user_prop = @project.find_property_definition('dev')
    plv = create_plv!(@project, :name => 'user variable', :data_type => ProjectVariable::USER_DATA_TYPE)
    plv.property_definitions = [user_prop]
    plv.save!
    user_prop.reload

    options = transition_popup_property_editor_options(user_prop)

    expected_user_option_list = @project.users.sort_by(&:name).collect{|u| [u.name, u.id.to_s]}
    expected = [['(not set)', ''], ['(user variable)', '(user variable)'], ['(current user)', '(current user)']]
    assert_equal expected, options
  end

  def test_droplist_options_for_tree_without_cascading_delete
    assert_equal [['(no change)', ':ignore'], [TreeBelongingPropertyDefinition::JUST_THIS_CARD_TEXT, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE]], droplist_options_for_tree_without_cascading_delete
  end

  def test_droplist_options_for_tree_with_cascading_delete
    assert_equal [['(no change)', ':ignore'], [TreeBelongingPropertyDefinition::JUST_THIS_CARD_TEXT, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE], [TreeBelongingPropertyDefinition::WITH_CHILDREN_TEXT, TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE]], droplist_options_for_tree_with_cascading_delete
  end

end
