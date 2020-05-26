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

class EnumerationValueTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
  end

  def test_gets_random_color_on_create_when_assign_colors
    with_new_project do |project|
      enum_feature = project.create_text_list_definition!(:name  => 'feature')
      api = enum_feature.create_enumeration_value!(:value  => 'api')
      assert Color.valid?(api.color)
    end
  end

  def test_position_should_auto_increased_when_new_value_comes
    with_new_project do |project|
      enum_feature = project.create_text_list_definition!(:name  => 'feature')
      api = enum_feature.create_enumeration_value!(:value  => 'api')
      assert_not_nil api.position
      wiki = enum_feature.create_enumeration_value!(:value  => 'wiki')
      assert_equal wiki.position, api.position + 1
    end
  end

  def test_value_should_be_unique_in_same_property_definition
    with_new_project do |project|
      enum_feature = project.create_text_list_definition!(:name  => 'feature')
      api = enum_feature.create_enumeration_value!(:value  => 'api')
      assert !EnumerationValue.new(:value  => 'api', :property_definition => enum_feature).valid?
      assert EnumerationValue.new(:value  => 'wiki', :property_definition => enum_feature).valid?
      enum_function = project.create_text_list_definition!(:name  => 'function')
      assert EnumerationValue.new(:value  => 'api', :property_definition => enum_function).valid?
    end
  end

  def test_update_value_updates_card_defaults
    with_new_project do |project|
      setup_property_definitions :status => ['open', 'closed']
      card = create_card!(:name => 'first card')

      card_defaults = card.card_type.card_defaults
      card_defaults.update_properties(:status => 'closed')
      card_defaults.save!

      project.find_enumeration_value('status', 'closed').update_attribute(:value, 'closed (new name)')
      assert_equal 'closed (new name)', project.reload.find_enumeration_value('status', 'closed (new name)').value

      assert_equal 'closed (new name)', card.reload.card_type.card_defaults.property_value_for('status').db_identifier
    end
  end

  def test_update_value_updates_matching_transition_prereq_and_action_values_belonging_to_same_property
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'open']
      open = create_transition project, 'open', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open'}

      project.find_enumeration_value('status', 'new').update_attribute(:value, 'Really New')
      project.find_enumeration_value('status', 'open').update_attribute(:value, 'Really Open')

      open.reload
      assert_equal 'Really New', open.prerequisites[0].value
      assert_equal 'Really Open', open.actions[0].value
    end
  end

  def test_update_value_does_not_update_matching_transition_prereq_and_action_values_belonging_to_other_property
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open'], :kind => ['new', 'open']
      open = create_transition project, 'open', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open'}

      project.find_enumeration_value('kind', 'new').update_attribute(:value, 'Really New')
      project.find_enumeration_value('kind', 'open').update_attribute(:value, 'Really Open')

      open.reload
      assert_equal 'new', open.prerequisites[0].value
      assert_equal 'open', open.actions[0].value
    end
  end

  def test_update_value_updates_saved_views
    with_new_project do |project|
      setup_property_definitions :feature => ['cerds', 'api'], :status => []
      view = CardListView.find_or_construct(project, :tagged_with => 'rss', :sort => 'status',
        :order => 'asc', :filters => ['[feature][is][cerds]'])
      view.name = 'API Stories'
      view.save!
      project.reload

      misspelled_value = project.find_enumeration_value('feature', 'cerds')
      misspelled_value.update_attribute :value, 'cards'

      view = CardListView.find_or_construct(project, :view => 'API Stories')
      assert_equal 'status', view.sort
      assert_equal 'asc', view.order
      assert_equal ['rss'], view.tagged_with
      assert_equal(['[feature][is][cards]'], view.filters.to_params)
    end
  end

  def test_find_existing_should_find_existing_value
    with_first_project do |project|
      enumeration_value = project.find_enumeration_value('Status', 'new')
      property_definition = project.find_property_definition('Status')
      assert_equal enumeration_value, EnumerationValue.find_existing(:property_definition_id => property_definition.id, :value => 'new')
    end
  end

  def test_find_existing_should_find_return_nil_if_not_found
    with_first_project do |project|
      enumeration_value = project.find_enumeration_value('Status', 'new')
      property_definition = project.find_property_definition('Status')
      assert_nil EnumerationValue.find_existing(:property_definition_id => property_definition.id, :value => 'fake')
    end
  end

  def test_find_existing_should_find_return_not_set_for_blank
    with_first_project do |project|
      property_definition = project.find_property_definition('Status')
      assert_equal EnumerationValue.not_set, EnumerationValue.find_existing(:property_definition_id => property_definition.id, :value => '')
    end
  end

  def test_find_or_construct_should_find_existing_value
    with_first_project do |project|
      enumeration_value = project.find_enumeration_value('Status', 'new')
      property_definition = project.find_property_definition('Status')
      assert_equal enumeration_value, EnumerationValue.find_or_construct(:property_definition_id => property_definition.id, :value => 'new')
    end
  end

  def test_find_or_construct_should_create_new_value
    with_first_project do |project|
      property_definition = project.find_property_definition('Status')
      actual_value = EnumerationValue.find_or_construct(:property_definition_id => property_definition.id, :value => 'newlycreated')
      expected_value = project.find_enumeration_value('Status', 'newlycreated')
      assert actual_value
      assert_equal expected_value, actual_value
    end
  end

  def test_find_or_contstruct_should_return_a_dummy_value_for_not_set
    with_first_project do |project|
      property_definition = project.find_property_definition('Status')
      actual_value = EnumerationValue.find_or_construct(:property_definition_id => property_definition.id, :value => '')
      assert_equal ' ', actual_value.value
      assert actual_value.errors.empty?
    end
  end

  def test_destroy_raises_error_if_still_in_use_by_card
    with_new_project do |project|
      setup_property_definitions 'status' => ['new']
      card1 =create_card!(:name => 'first card', :status => 'new')
      new_value = project.find_enumeration_value('status', 'new')

      begin
        new_value.destroy
        fail "destroy should not have succeeded"
      rescue ValueStillInUseError => e
        # good!
      end
    end
  end

  def test_destroy_raises_error_if_still_in_use_by_transition
    with_new_project do |project|
      setup_property_definitions 'status' => ['new']
      open = create_transition project, 'open', :required_properties => {:status => 'new'}, :set_properties => {:status => nil}
      new_value = project.find_enumeration_value('status', 'new')

      begin
        new_value.destroy
        fail "destroy should not have succeeded"
      rescue ValueStillInUseError => e
        # good!
      end
    end
  end

  def test_destroy_works_when_value_not_in_use
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'old']
      card1 =create_card!(:name => 'first card', :status => 'new')
      old_value = project.find_enumeration_value('status', 'old')
      old_value.destroy
      assert_equal 1, project.reload.find_property_definition('status').enumeration_values.size
      assert_equal 'new', project.find_property_definition('status').enumeration_values[0].value
    end
  end

  def test_values_should_in_nature_order_if_no_order_specified
    with_new_project do |project|
      setup_property_definitions 'material'  => []
      material = project.find_property_definition('material')
      material.create_enumeration_value!(:value => 'sand')
      material.create_enumeration_value!(:value => 'wood')
      material.create_enumeration_value!(:value => 'gold')
      assert_equal %w{gold sand wood}, material.reload.enumeration_values.collect(&:value)
      material.enumeration_values.detect{|ev| ev.value == 'sand'}.update_attribute(:value, 'earth')
      assert_equal %w{earth gold wood}, material.reload.enumeration_values.collect(&:value)
      material.reorder(%w{wood earth gold}) {|enum| enum.value}
      assert_equal %w{wood earth gold}, material.reload.enumeration_values.collect(&:value)
      material.create_enumeration_value!(:value => 'plastic')
      assert_equal %w{wood earth gold plastic}, material.reload.enumeration_values.collect(&:value)
    end
  end

  #bug 1782
  def test_should_not_reorder_after_order_specified
    with_new_project do |project|
      setup_property_definitions 'material'  => []
      material = project.find_property_definition('material')
      sand = material.create_enumeration_value!(:value => 'sand')
      wood = material.create_enumeration_value!(:value => 'wood')
      gold = material.create_enumeration_value!(:value => 'gold')

      material.reorder([sand, wood, gold])

      assert_equal %w{sand wood gold}, material.reload.enumeration_values.collect(&:value)

      gold.update_attribute :color, '#111111'
      assert_equal %w{sand wood gold}, material.reload.enumeration_values.collect(&:value)
    end
  end

  def test_should_update_history_subscriptions_when_value_changes
    with_new_project(:users => [User.find_by_email('member@email.com')]) do |project|
      UnitTestDataLoader.setup_property_definitions(
        :Status => ['open', 'closed'],
        :Iteration => ['1', '2']
      )

      enum_feature = project.create_text_list_definition!(:name  => 'feature')
      api = enum_feature.create_enumeration_value!(:value  => 'api')
      wiki = enum_feature.create_enumeration_value!(:value  => 'wiki')

      user = User.current
      hash_params = {'involved_filter_properties' => {'Status' => 'open',   'feature' => 'api',  'Iteration' => '1'},
                     'acquired_filter_properties' => {'Status' => 'closed', 'feature' => 'wiki', 'Iteration' => '2'},
                     'involved_filter_tags' => 'apple',
                     'acquired_filter_tags' => 'orange',
                     'filter_user' => user.id.to_s}
      input_params = HistoryFilterParams.new(hash_params)
      history_subscription = project.create_history_subscription(user, input_params.serialize)
      project.reload.history_subscriptions
      api.value = 'new_api'
      api.save
      wiki.value = 'new_wiki'
      wiki.save

      history_subscription.reload
      params = history_subscription.to_history_filter_params
      # verify that Status params were renamed to Steve
      assert_equal 'new_api', params.involved_filter_properties['feature']
      assert_equal 'new_wiki', params.acquired_filter_properties['feature']
      # verify that all other params were not messed up.
      assert_equal 'open', params.involved_filter_properties['Status']
      assert_equal '1', params.involved_filter_properties['Iteration']
      assert_equal 'closed', params.acquired_filter_properties['Status']
      assert_equal '2', params.acquired_filter_properties['Iteration']
      assert_equal ['apple'], params.involved_filter_tags
      assert_equal ['orange'], params.acquired_filter_tags
    end
  end

  def test_should_destroy_history_subscriptions_when_value_deleted
    with_new_project(:users => [User.find_by_email('member@email.com')]) do |project|
      UnitTestDataLoader.setup_property_definitions(
        :Status => ['open', 'closed'],
        :Iteration => ['1', '2']
      )

      enum_feature = project.create_text_list_definition!(:name  => 'feature')
      api = enum_feature.create_enumeration_value!(:value  => 'api')
      wiki = enum_feature.create_enumeration_value!(:value  => 'wiki')

      user = User.current
      hash_params = {'involved_filter_properties' => {'Status' => 'open',   'feature' => 'api',  'Iteration' => '1'},
                     'acquired_filter_properties' => {'Status' => 'closed', 'feature' => 'wiki', 'Iteration' => '2'},
                     'involved_filter_tags' => 'apple',
                     'acquired_filter_tags' => 'orange',
                     'filter_user' => user.id.to_s}
      input_params = HistoryFilterParams.new(hash_params)
      history_subscription = project.create_history_subscription(user, input_params.serialize)

      api.destroy
      wiki.destroy

      assert_equal [], project.reload.history_subscriptions
    end
  end

  def test_should_destroy_card_list_views_when_value_deleted
    with_new_project do |project|
      setup_property_definitions :status => ['new']
      view = CardListView.find_or_construct project, {:filters => ["[status][is][new]"]}
      view.name = 'test_should_destroy_card_list_views_when_value_deleted-1'
      view.save!

      view = CardListView.find_or_construct(project, {:style => 'grid', :group_by => 'status', :lanes => 'new'})
      view.name = 'test_should_destroy_card_list_views_when_value_deleted-2'
      view.save!

      project.reload

      enum_new = project.find_property_definition('status').values.first
      enum_new.destroy

      assert_equal [], project.reload.card_list_views
    end
  end

  def test_should_set_relevant_card_defaults_to_not_set_when_value_destroyed
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'old']
      status = project.find_property_definition('status')
      card1 = create_card!(:name => 'first card', :status => 'new')

      old_value = project.find_enumeration_value('status', 'old')

      type_card = project.card_types.find_by_name('Card')
      type_bug = project.card_types.create!(:name => 'Bug')
      type_bug.property_definitions = [status]

      card_defaults = type_card.card_defaults
      card_defaults.update_properties(:status => 'old')
      card_defaults.save!

      bug_defaults = type_bug.card_defaults
      bug_defaults.update_properties(:status => 'new')
      bug_defaults.save!

      old_value.destroy

      assert !type_card.card_defaults.actions.any? { |action| action.property_definition == status }
      assert type_bug.card_defaults.actions.detect { |action| action.property_definition == status }
    end
  end

  def test_should_not_allow_values_to_begin_with_opening_parenthesis_and_end_with_closing_parenthesis
    with_new_project do |project|
      status_property = project.create_text_list_definition!(:name  => 'status')
      assert !EnumerationValue.new(:value  => '(*)', :property_definition => status_property).valid?
      assert !EnumerationValue.new(:value  => ' (*) ', :property_definition => status_property).valid?
      assert !EnumerationValue.new(:value => Transition::USER_INPUT_OPTIONAL, :property_definition => status_property).valid?
      assert EnumerationValue.new(:value  => ')*(', :property_definition => status_property).valid?
      assert EnumerationValue.new(:value  => '(:', :property_definition => status_property).valid?
      assert EnumerationValue.new(:value  => ':)', :property_definition => status_property).valid?
      assert EnumerationValue.new(:value  => 'this is (super)', :property_definition => status_property).valid?
      assert EnumerationValue.new(:value  => '(this) is super', :property_definition => status_property).valid?
    end
  end

  def test_should_be_able_to_create_a_project_variable_using_an_existing_value
    with_new_project do |project|
      release = setup_numeric_property_definition 'release', [1, 2, 3]
      three_value = release.enumeration_values.detect { |value| value.value == '3' }

      current_release = create_plv!(project, :name => 'current release',
                                                          :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => three_value.value, :property_definition_ids => [release.id])

      assert_equal ['current release'], three_value.project_variables.collect(&:name)
    end
  end

  def test_should_rename_a_plv_value_when_renaming_an_enum_value_if_the_plv_is_associated_with_just_the_one_property_definition
    with_new_project do |project|
      release = setup_numeric_property_definition('release', [1,2,3])
      release_3 = release.enumeration_values.detect{|value| value.value == '3'}
      current_release = create_plv!(project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => release_3.value, :property_definition_ids => [release.id])
      release_3.value = '30'
      release_3.save!
      assert_equal '30', current_release.reload.value
    end
  end

  def test_should_create_a_new_plv_with_renamed_value_when_renaming_an_enum_value_if_the_plv_is_associated_with_more_than_one_property_definition
    with_new_project do |project|
      release = setup_numeric_property_definition('release', [1,2,3])
      free_number = setup_numeric_text_property_definition 'free number'
      release_3 = release.enumeration_values.detect{|value| value.value == '3'}
      current_release = create_plv!(project, :name => 'current rELEAse', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => release_3.value, :property_definition_ids => [release.id, free_number.id])
      project_variable_count_before_rename = project.project_variables.size
      release_3.value = '30'
      release_3.save!
      project_variable_count_after_rename = project.project_variables.reload.size

      assert_equal 1, (project_variable_count_after_rename - project_variable_count_before_rename)

      assert_equal '3', current_release.reload.value
      assert_equal [free_number], current_release.reload.property_definitions

      new_plv = project.project_variables.find_by_name('current rELEAse 1')
      assert_equal '30', new_plv.value
      assert_equal [release], new_plv.property_definitions
    end
  end

  def test_should_move_transitions_using_a_plv_which_gets_recreated_due_to_a_enum_value_rename_to_the_newly_created_plv
    with_new_project do |project|
      release = setup_numeric_property_definition('release', [1,2,3])
      free_number = setup_numeric_text_property_definition 'free number'
      release_3 = release.enumeration_values.detect{|value| value.value == '3'}

      current_release = create_plv!(project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => release_3.value, :property_definition_ids => [release.id, free_number.id])
      project.all_property_definitions.reload
      transition_use_current_release = create_transition(project, 'set to current release', :set_properties => {:release => current_release.display_name})
      assert_equal [transition_use_current_release.name], current_release.reload.used_by_transitions.collect(&:name)

      release_3.value = '30'
      release_3.save!
      assert_equal '30', project.transitions.find_by_name('set to current release').actions.first.variable_binding.project_variable.value
    end
  end

  def test_should_not_remove_project_variable_association_with_the_property_definition_when_destroy_value
    with_new_project do |project|
      release = setup_numeric_property_definition('release', [1,2,3])
      release_3 = release.enumeration_values.detect{|value| value.value == '3'}
      current_release = create_plv!(project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => release_3.value, :property_definition_ids => [release.id])
      release_3.destroy
      assert_equal [release.name], current_release.reload.property_definitions.collect(&:name)
    end
  end

  # bug4165
  def test_enum_value_should_be_rename_when_it_is_used_by_the_PLV
    with_new_project do |project|
      setup_property_definitions(:status => ['open', 'close'])
      status = project.find_property_definition('status')
      foo = create_plv(project, :name => 'FOO', :value => 'close', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
      close = status.find_enumeration_value('close')
      close.value = 'closexx'
      close.save!
      assert_equal [], close.errors.full_messages
      assert_equal 'closexx', close.reload.value
      assert_equal 'closexx', foo.reload.value
    end
  end

  def test_renaming_enum_value_will_rename_it_in_aggregate_mql_condition
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      todo = setup_managed_text_definition('todo', ['coloncleanse'])
      todo.card_types = [type_story]
      todo.save!

      value = EnumerationValue.find_by_value('coloncleanse')

      some_agg = setup_aggregate_property_definition('count of stories',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      some_agg.aggregate_condition = "todo = 'coloncleanse'"
      some_agg.save!
      project.all_property_definitions.reload

      value.value = 'purifycolon'
      value.save!

      assert_equal "todo = purifycolon", some_agg.reload.aggregate_condition
    end
  end

  def test_rename_of_enumerated_value_should_not_rename_usages_in_dependent_invalid_aggregate_conditions
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types

      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      some_agg = setup_aggregate_property_definition('aggregate',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      status = setup_property_definitions(:status => ['fixed']).first
      importance = setup_property_definitions(:importance => ['very']).first

      some_agg.aggregate_condition = "importance = very OR status = fixed"
      some_agg.save!

      importance.destroy

      project.reload

      enum = status.enumeration_values.first
      enum.value = "fixed_good"
      enum.save!

      assert_equal "importance = very OR status = fixed", some_agg.reload.aggregate_condition
    end
  end


end
