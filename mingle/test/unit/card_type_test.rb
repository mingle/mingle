# coding: utf-8

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
require File.expand_path(File.dirname(__FILE__) + '/../../db/migrate/20120312200419_add_not_null_constraint_to_property_type_mapping')

class CardTypeTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = create_project
    @project.activate
    login_as_proj_admin
  end

  def teardown
    @project.deactivate
  end

  def test_card_type_name_exist
    @project.card_types.create :name => 'bug'
    assert @project.card_types.exists?('bug')
    assert @project.card_types.exists?('bUG')
    assert @project.card_types.exists?('')
    assert @project.card_types.exists?(nil)
    assert !@project.card_types.exists?('story')

    assert !create_project.card_types.exists?('bug')
  end

  def test_property_definitions_should_be_uniq
    setup_property_definitions :status => []
    status_def = @project.find_property_definition(:status)
    card_type = @project.card_types.first
    card_type.property_definitions = []
    card_type.save!
    card_type.add_property_definition status_def
    card_type.add_property_definition status_def
    assert_raise ActiveRecord::RecordInvalid do
      card_type.save!
    end
  end

  def test_property_definitions_should_not_contain_hidden_property_definitions
    setup_property_definitions :status => []
    card_type = @project.card_types.first
    status_def = @project.find_property_definition(:status)
    assert_equal [status_def], card_type.property_definitions

    status_def.update_attribute(:hidden, true)
    assert_equal [], card_type.property_definitions
  end

  def test_card_type_is_dissociated
    first_type = @project.card_types.first
    assert 1, @project.card_types.size
    assert first_type.is_dissociated?

    card = create_card!(:name => "foo", :card_type => first_type)
    assert !first_type.is_dissociated?
  end


  def test_card_type_can_not_be_destroy_when_it_is_the_last_one
    first_type = @project.card_types.first
    assert 1, @project.card_types.size
    assert !first_type.can_be_destroy?
    defect = @project.card_types.create(:name => 'defect')
    assert first_type.can_be_destroy?
  end

  def test_destroy_with_validate
    defect = @project.card_types.create(:name => 'defect')
    defect.destroy_with_validate
    assert_nil @project.card_types.find_by_name('defect')

    @project.card_types.reload

    first_type = @project.card_types.first
    first_type.destroy_with_validate
    assert_equal "#{first_type.name} cannot be deleted because it is being used or is the last card type.",
      first_type.errors.full_messages.join
    assert_equal 1, @project.reload.card_types.size
  end

  def test_destroy_with_validate_can_delete_if_card_version_exist
    story = @project.card_types.create(:name => 'story')
    defect = @project.card_types.create(:name => 'defect')
    card = create_card!(:name => "foo", :card_type => defect)
    card.card_type = story
    card.save

    assert defect.can_be_destroy?
    defect.destroy_with_validate
    assert_false @project.reload.card_types.map(&:name).include?('defect')
  end

  def test_destroy_and_add_back_does_not_link_versions_back
    story = @project.card_types.create(:name => 'story')
    defect = @project.card_types.create(:name => 'defect')
    card = create_card!(:name => "foo", :card_type => defect)
    card.card_type = story
    card.save

    defect.destroy_with_validate
    defect = @project.card_types.create(:name => 'defect')
    assert_not_equal defect.name, card.versions.first.card_type_name
  end

  def test_card_type_can_be_destroyed_when_there_is_no_card_related
    setup_property_definitions :status => ['open', 'close']
    defect = @project.card_types.create(:name => 'defect')
    assert defect.can_be_destroy?
    defect.add_property_definition @project.find_property_definition('status')
    assert defect.can_be_destroy?

    create_card!(:name => "I am a defect", :card_type => defect)
    assert !defect.can_be_destroy?
  end

  def test_card_defaults_are_destroyed_when_card_type_is_destroyed
    defect = @project.card_types.create(:name => 'defect')
    defect.destroy
    assert_nil @project.card_types.find_by_name('defect')
    assert_nil defect.card_defaults
  end

  # Bug 5550.
  def test_should_not_delete_aggregate_properties_for_other_card_types
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types

      property_to_disassociate = setup_numeric_text_property_definition('size')
      property_to_disassociate.card_types = [type_iteration, type_story]
      property_to_disassociate.save!

      release_story_size = setup_aggregate_property_definition('story size',
                                                            AggregateType::SUM,
                                                            property_to_disassociate,
                                                            configuration.id,
                                                            type_release.id,
                                                            type_story)

      type_iteration.property_definitions = type_iteration.property_definitions - [property_to_disassociate]
      type_iteration.save!

      assert project.reload.find_property_definition_or_nil(release_story_size.name)
    end
  end

  def test_rename_of_card_type_should_update_any_card_types_used_in_aggregate_conditions
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

      defect_type, task_type = %w{defect task}.collect { |card_type_name| project.card_types.create :name => card_type_name }

      some_agg.aggregate_condition = "type = task"
      some_agg.save!
      task_type.project.all_property_definitions.reload

      task_type.name = "tasklet"
      task_type.save!

      assert_equal "Type = tasklet", some_agg.reload.aggregate_condition
    end
  end

  # we are not sure why the rename works in this case -- if you rename a property, for example, we expect the rename to not go through in the conditions
  def test_rename_of_card_type_should_unexpectedly_update_any_card_types_used_in_invalid_aggregate_conditions
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

      defect_type, task_type = %w{defect task}.collect { |card_type_name| project.card_types.create :name => card_type_name }

      some_agg.aggregate_condition = "type = defect or type = task"
      some_agg.save!
      task_type.project.all_property_definitions.reload

      defect_type.destroy

      project.reload

      task_type.name = "tasklet"
      task_type.save!

      assert_equal "((Type = defect) OR (Type = tasklet))", some_agg.reload.aggregate_condition
    end
  end


  def test_card_and_card_version_table_should_be_updated_when_the_card_type_name_was_changed
    defect = @project.card_types.create(:name => 'Defect')
    card = create_card!(:name => 'I am a defect', :card_type => defect)
    defect.update_attribute(:name, 'Bug')
    assert_equal 'Bug', card.reload.card_type_name
    card.versions.each do |card_version|
      assert_equal 'Bug', card_version.card_type_name
    end
  end

  def test_should_update_card_list_view_when_change_card_type_name
    card_type = @project.card_types.first
    view = CardListView.find_or_construct @project, {:filters => ["[type][is][#{card_type.name}]"]}
    view.name = 'type view'
    view.save!

    @project.reload
    card_type.reload
    card_type.update_attribute :name, 'bug'

    view = @project.card_list_views.find_by_name 'type view'
    assert_equal ['[Type][is][bug]'], view.to_params[:filters]
  end

  def test_should_not_lose_group_by_when_change_card_type_name
    with_first_project do |project|
      story_type = project.card_types.create!(:name => 'story')
      status = project.find_property_definition('status')
      status.card_types = [story_type]
      status.save!
      project.reload
      view = project.card_list_views.create_or_update(:view => { :name => "group by status" }, :filters => ['[type][is][story]'], :style => 'grid', :group_by => {:lane=>"status"})
      view.save!
      assert_equal({:lane=>"status"}, view.to_params[:group_by])
    end
    with_first_project do |project|
      story_type = project.card_types.find_by_name 'story'
      story_type.update_attributes(:name => 'story123')
      assert_equal({:lane=>"status"}, project.card_list_views.find_by_name('group by status').to_params[:group_by])
    end
  end

  def test_reorder_by_card_type_definition
    card_type = @project.card_types.find_by_name('Card')
    story_type = @project.card_types.create :name => 'story'
    bug_type = @project.card_types.create :name => 'bug'

    expected_order = [bug_type, story_type, card_type]
    Project.card_type_definition.reorder(expected_order)

    assert_equal expected_order.collect(&:name), @project.reload.card_types.collect(&:name)
  end

  def test_bug_2204_sql_injection_with_card_type_name
    type_with_single_quote = @project.card_types.create(:name => "hacker's type name")
    assert_equal 0, type_with_single_quote.card_count
  end

  # Bug #3218
  def test_tree_configurations_should_be__in_alphabetical_order_by_name_and_ignore_case
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      ['Release Planning', 'a release plan', 'story breakdown'].each do |tree_name|
        tree_config = project.tree_configurations.create!(:name => tree_name)
        tree_config.update_card_types({
          type_release   => {:position => 0, :relationship_name => "#{tree_name} release"},
          type_iteration => {:position => 1, :relationship_name => "#{tree_name} iteration"},
          type_story     => {:position => 2}
        })
      end
      assert_equal(['a release plan', 'Release Planning', 'story breakdown'], type_release.tree_configurations.collect(&:name))
    end
  end

  def test_not_applicable_values_not_removed_when_property_definitions_not_deleted
    @project.with_active_project do |project|
      setup_property_definitions(:release => ['1','2'], :status => ['new', 'open'], :priority => ['low', 'high'])
      setup_card_type(project, 'story', :properties => ['release', 'status', 'priority'])
      release = project.find_property_definition('release')
      status = project.find_property_definition('status')
      priority = project.find_property_definition('priority')
      assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, 'story', [],[])
      assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, 'story', [release],[release])
      assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, 'story', [release],[release, status])
      assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, 'story', [release, status], [release, status])
      assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, 'story', [release, status],[release, status, priority])
    end
  end

  def assert_not_applicable_values_not_removed_when_property_defs_not_deleted(project, card_type, initial_property_defs, new_property_defs)
    project.reload
    story =  project.find_card_type(card_type)
    story.property_definitions = initial_property_defs
    def story.remove_not_applicable_card_values(deleted_property_definitions)
      fail("should not remove not applicable values")
    end
    story.property_definitions = new_property_defs
  end

  def test_comment_is_singular_when_one_property_removed
    @project.with_active_project do |project|
      setup_property_definitions(:release => ['1','2'])
      setup_card_type(project, 'story', :properties => ['release'])
      story = @project.cards.create!(:card_type_name => 'story', :name => 'story', :cp_release => '1')
      story_type = project.find_card_type('story')
      story_type.property_definitions = []
      story_type.save!

      assert_nil story.reload.versions.last.comment
      assert_equal "Property release is no longer applicable to card type story.", story.reload.versions.last.system_generated_comment
     end
  end

  def test_comment_is_plural_when_one_property_removed
    @project.with_active_project do |project|
      setup_property_definitions(:release => ['1','2'], :status => ['open', 'new'])
      setup_card_type(project, 'story', :properties => ['release', 'status'])
      story = @project.cards.create!(:card_type_name => 'story', :name => 'story', :cp_release => '1', :cp_status => 'new')
      story_type = project.find_card_type('story')
      story_type.property_definitions = []
      story_type.save!

      assert_nil story.reload.versions.last.comment
      assert_equal "Properties release, status are no longer applicable to card type story.", story.reload.versions.last.system_generated_comment
     end
  end

  def test_text_properties_should_not_be_included_in_filters
    @project.with_active_project do |project|
      story = project.card_types.create!(:name => 'story')
      story_status = project.create_text_list_definition!(:name => 'story status')
      story_status.update_attributes(:card_types => [story])
      estimate = project.create_any_text_definition!(:name => 'estimate')
      estimate.update_attributes(:card_types => [story])

      assert_equal [story_status], story.reload.filterable_property_definitions_in_smart_order
    end
  end

  def test_relationship_properties_should_not_include_filterable_properties_not_in_specified_tree
    with_new_project do |p|
      types = ['Release', 'Iteration', 'Story', 'Task'].collect { |ct| p.card_types.create!(:name => ct) }

      setup_property_definitions :status => ['open'], :priority => ['low']
      status = p.find_property_definition('status')
      priority = p.find_property_definition('priority')

      status.card_types = types[1..2]
      priority.card_types = types[2..3]

      t1 = p.tree_configurations.create!(:name => 't1')
      t2 = p.tree_configurations.create!(:name => 't2')

      t1.update_card_types({
        types[0] => {:position => 0, :relationship_name => 't1 release'},
        types[1] => {:position => 1, :relationship_name => 't1 iteration'},
        types[2] => {:position => 2, :relationship_name => 't1 story'},
        types[3] => {:position => 3}
      })

      t2.update_card_types({
        types[0] => {:position => 0, :relationship_name => 't2 release'},
        types[1] => {:position => 1, :relationship_name => 't2 iteration'},
        types[2] => {:position => 2}
      })

      types.each{|t| t.clear_cached_results_for :property_definitions_with_hidden}
      assert_equal ['status', 't1 release', 't2 release'], types[1].filterable_property_definitions_in_smart_order.collect(&:name)
      assert_equal ['status', 't1 release'], types[1].filterable_property_definitions_in_smart_order(:tree => t1).collect(&:name)
      assert_equal ['status', 't2 release'], types[1].filterable_property_definitions_in_smart_order(:tree => t2).collect(&:name)
      assert_equal [], types[0].filterable_property_definitions_in_smart_order(:tree => t2).collect(&:name)
      assert_equal ['status', 't2 release'], types[1].filterable_property_definitions_in_smart_order(:tree => t2).collect(&:name)
      assert_equal ['priority', 'status', 't2 iteration'], types[2].filterable_property_definitions_in_smart_order(:tree => t2).collect(&:name)
    end
  end

  def test_removing_property_definitions_deletes_any_transitions_using_those_properties
    @project.with_active_project do |project|
      setup_property_definitions(:release => ['1','2'], :status => ['new', 'open'], :priority => ['low', 'high'])

      story = setup_card_type(project, 'story', :properties => ['release', 'status', 'priority'])

      requires_story_and_priority = create_transition(project, 'requires_story_and_priority', :card_type => story,
        :required_properties => {:priority => 'high'}, :set_properties => {:release => '1'})
      requires_story_and_sets_status = create_transition(project, 'requires_story_and_sets_status',
        :card_type => story, :set_properties => {:status => 'open'})

      # decoys
      requires_story_and_sets_release = create_transition(project, 'requires_story_and_sets_release',
        :card_type => story, :set_properties => {:release => '1'})

      story = project.find_card_type('story')
      story.property_definitions = [project.find_property_definition('release')]
      story.save!

      assert_equal ['requires_story_and_sets_release'], project.reload.transitions.collect(&:name).sort
    end
  end

  # bug 4538
  def test_removing_hidden_property_definitions_deletes_transitions_using_those_properties
    cake = setup_property_definitions(:cake => ['chocolate', 'cheese']).first
    cake.hidden = true
    cake.save!

    type_dessert = @project.card_types.create!(:name => 'dessert')
    type_dessert.property_definitions = [cake]
    make_chocolate = create_transition(@project, 'make chocolate', :card_type => type_dessert, :set_properties => {:cake => 'chocolate'})

    type_dessert.property_definitions = []
    type_dessert.save!

    assert_equal [], @project.reload.transitions.collect(&:name)
  end

  def test_history_subscriptions_should_be_updated_when_card_type_is_renamed
    with_new_project do |project|
      @story_type = project.card_types.create! :name => 'story'
      project.add_member(User.find_by_login('first'))
      involved_history_subscription = project.create_history_subscription(project.users.first, 'involved_filter_properties[Type]=story')
      acquired_history_subscription = project.create_history_subscription(project.users.first, 'acquired_filter_properties[Type]=story')

      @story_type.update_attribute(:name, "bug")

      involved_history_subscription.reload
      acquired_history_subscription.reload

      assert_equal({'Type' => 'bug'}, involved_history_subscription.to_history_filter_params.involved_filter_properties)
      assert_equal({'Type' => 'bug'}, acquired_history_subscription.to_history_filter_params.acquired_filter_properties)
    end
  end

  def test_history_subscriptions_should_be_deleted_when_card_type_is_deleted
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      setup_managed_text_definition 'status', %w{open closed}
      story_type = setup_card_type(project, 'story', :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=story")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=story")

      story_type.destroy

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 0, history_subscriptions.size
    end
  end

  def test_history_subscriptions_should_be_not_be_deleted_when_another_card_type_is_deleted
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      setup_managed_text_definition 'status', %w{open closed}
      story_type, unrelated_type = setup_card_types(project, :names => %w{story unrelated}, :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=unrelated")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=unrelated")

      story_type.destroy

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 2, history_subscriptions.size
    end
  end

  # Bug 7385
  def test_history_subscriptions_should_delete_history_subscriptions_when_a_property_is_disassociated_with_a_card_type
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      setup_managed_text_definition 'status', %w{open closed}
      story_type = setup_card_type(project, 'story', :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=story&involved_filter_properties[status]=closed")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=story&acquired_filter_properties[status]=closed")

      story_type.update_attribute :property_definitions, []

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 0, history_subscriptions.size
    end
  end

  # Bug 7385
  def test_should_not_delete_history_subscriptions_when_disassociated_property_and_card_type_are_not_part_of_same_filter
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      setup_managed_text_definition 'status', %w{open closed}
      story_type, unrelated_type = setup_card_types(project, :names => %w{story unrelated}, :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=story&acquired_filter_properties[status]=closed")
      project.create_history_subscription(user, "involved_filter_properties[status]=closed&acquired_filter_properties[Type]=story")

      story_type.update_attribute :property_definitions, []

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 2, history_subscriptions.size
    end
  end

  # Bug 7385
  def test_history_subscriptions_should_ignore_unrelated_card_types_when_disassociating_properties_from_card_types
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      setup_managed_text_definition 'status', %w{open closed}
      story_type, unrelated_type = setup_card_types(project, :names => %w{story unrelated}, :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=unrelated&involved_filter_properties[status]=closed")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=unrelated&acquired_filter_properties[status]=closed")

      story_type.update_attribute :property_definitions, []

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 2, history_subscriptions.size
    end
  end

  # Bug 7385
  def test_history_subscriptions_should_ignore_unrelated_properties_when_disassociating_properties_from_card_types
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      cp_priority, cp_status = setup_property_definitions('priority' => %w{high low},
                                                          'status'   => %w{open closed}).sort_by(&:name)
      story_type = setup_card_type(project, 'story', :properties => ['status', 'priority'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=story&involved_filter_properties[priority]=high")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=story&acquired_filter_properties[priority]=high")

      story_type.update_attribute :property_definitions, [cp_priority]

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 2, history_subscriptions.size
    end
  end

  def test_disassociating_property_definitions_should_also_remove_corresponding_card_default_actions
    setup_managed_text_definition 'status', %w{open closed}
    story_type = setup_card_types(@project, :names => ['story'], :properties => ['status']).first
    story_type.card_defaults.update_properties(:status => 'open')
    story_type.update_attributes :property_definitions => []
    assert_equal 1, @project.all_property_definitions.size
    assert_equal [], story_type.card_defaults.actions
  end

  def test_creating_card_type_creates_corresponding_card_defaults
    @project.with_active_project do |project|
      new_card_type = project.card_types.create!(:name => 'new card type')
      assert !new_card_type.card_defaults.nil?
    end
  end

  def test_order_property_definitions_by_position
    @project.with_active_project do |project|
      # set these property defs up individually to ensure proper ordering on any version of ruby
      setup_property_definitions :iteration => ['1', '2']
      setup_property_definitions :status => ['new', 'open']
      card_type = project.card_types.first
      prop_iteration = project.find_property_definition(:iteration)
      prop_status = project.find_property_definition(:status)
      assert_equal ['iteration', 'status'], card_type.property_definitions.collect(&:name)
      card_type.property_definitions = [prop_status, prop_iteration]
      card_type.save!
      card_type.reload
      assert_equal ['status', 'iteration'], card_type.property_definitions.collect(&:name)
    end
  end

  def test_position_of_property_definition
    @project.with_active_project do |project|
      setup_property_definitions :iteration => ['1', '2']
      setup_property_definitions :status => ['new', 'open']
      card_type = project.card_types.first
      prop_iteration = project.find_property_definition(:iteration)
      prop_status = project.find_property_definition(:status)

      prop_new = setup_numeric_text_property_definition('new')
      prop_new.card_types = []
      prop_new.save!

      assert_equal ['iteration', 'status'], card_type.property_definitions.collect(&:name)

      card_type.property_definitions = [prop_status, prop_new, prop_iteration]
      card_type.save!
      card_type.reload
      assert_equal 1, card_type.position_of(prop_status)
      assert_equal 2, card_type.position_of(prop_new)
      assert_equal 3, card_type.position_of(prop_iteration)
    end
  end

  def test_position_of_property_definition_including_relationship_properties
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      setup_property_definitions :estimate => ['1', '2']
      setup_property_definitions :status => ['new', 'open']
      card_type = find_planning_tree_types.last
      prop_estimate = project.find_property_definition(:estimate)
      prop_status = project.find_property_definition(:status)
      prop_iteration = project.find_property_definition('Planning iteration')
      prop_release = project.find_property_definition('Planning release')

      card_type.add_property_definition(prop_estimate)
      card_type.add_property_definition(prop_status)
      assert_equal ['estimate', 'status', 'Planning release', 'Planning iteration'], card_type.property_definitions.collect(&:name)

      prop_new = setup_numeric_text_property_definition('new')
      card_type.property_definitions = [prop_status, prop_new, prop_iteration, prop_estimate, prop_release]
      card_type.save!
      card_type.reload

      assert_equal 1, card_type.position_of(prop_status)
      assert_equal 2, card_type.position_of(prop_new)
      assert_equal 3, card_type.position_of(prop_estimate)
      assert_equal 4, card_type.position_of(prop_iteration)
      assert_equal 5, card_type.position_of(prop_release)
    end
  end

  def test_card_type_should_not_be_deletable_when_used_in_some_tree
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'},
      type_iteration => {:position => 1, :relationship_name => 'iteration'},
      type_story => {:position => 2}
    })
    assert !type_release.can_be_destroy?
    assert !type_iteration.can_be_destroy?
    assert !type_story.can_be_destroy?
  end

  def test_card_type_that_has_a_formula_property_definition_but_not_its_components_is_invalid
    story = @project.card_types.create!(:name => 'story')

    numeric_text = setup_numeric_text_property_definition('numeric_text')
    some_formula = setup_formula_property_definition('some formula', 'numeric_text + 1')

    assert !some_formula.update_attributes(:card_types => [story])

    assert numeric_text.update_attributes(:card_types => [story])

    # This is a fix for oracle after the rails upgrade, not sure why it started failing.
    some_formula.card_types.map(&:reload)

    assert some_formula.update_attributes(:card_types => [story])
    assert story.reload.valid?
  end

  def test_removing_a_property_definition_from_card_type_will_remove_card_type_from_relevant_formulas
    size = setup_numeric_text_property_definition('size')
    size_times_two = setup_formula_property_definition('size times two', 'size * 2')

    story = setup_card_type(@project, 'story', :properties => ['size', 'size times two'])
    story.property_definitions = [size_times_two]
    story.clear_cache

    assert_equal [], story.property_definitions
  end

  def test_the_order_of_relationships_and_aggregate_property_definitions_should_be_the_last_in_property_defintions_with_hidden
    type_release, type_iteration, type_story = init_planning_tree_types
    create_three_level_tree
    setup_property_definitions('status' => ['open', 'close'])
    setup_numeric_property_definition('estimate', [1,2,8])
    status = @project.find_property_definition('status')
    estimate = @project.find_property_definition('estimate')
    type_story.add_property_definition(status)
    type_story.add_property_definition(estimate)
    type_story.save!

    assert_equal ["status", "estimate", "Planning release", "Planning iteration"], type_story.reload.property_definitions_with_hidden.collect(&:name)
  end

  def test_cannot_create_card_type_name_with_spaces_at_beginning_or_end
    card_type = @project.card_types.create!(:name => ' some name ')
    assert_equal 'some name', card_type.name
  end

  # bug 3608
  def test_aggregates_are_not_deleted_when_setting_property_definitions_on_card_type
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types

      size = setup_numeric_text_property_definition('size')
      size.card_types = [type_iteration, type_story]
      size.save!

      iteration_size = setup_aggregate_property_definition('iteration size',
                                                            AggregateType::SUM,
                                                            size,
                                                            configuration.id,
                                                            type_iteration.id,
                                                            type_story)

      type_story.property_definitions = [size]
      type_story.save!

      assert project.reload.find_property_definition_or_nil(iteration_size.name)
    end
  end

  # Bug 5339.
  def test_card_type_position_number_cannot_follow_the_correct_sequence_and_causes_the_filters_does_not_work
    with_new_project do |project|
      type_card = project.card_types.find_by_name('Card')
      assert_equal(1, type_card.position)
      # Create story.
      type_story = CardType.new(:project_id => project.id, :name => 'Story')
      type_story.save_and_set_property_definitions([])
      assert_equal(1, type_card.reload.position)
      assert_equal(2, type_story.reload.position)
      # Order by card then story.
      project.card_type_definition.reorder([type_card.id, type_story.id]) { |card_type| card_type.id }
      assert_equal(1, type_card.reload.position)
      assert_equal(2, type_story.reload.position)
      # Create defect.
      type_defect = CardType.new(:project_id => project.id, :name => 'Defect')
      type_defect.save_and_set_property_definitions([])
      assert_equal(1, type_card.reload.position)
      # Bug that is being fixed ended up putting defect and story both at position 3.
      assert_equal(2, type_defect.reload.position)
      assert_equal(3, type_story.reload.position)
    end
  end

  #bug 5597
  def test_card_type_name_should_be_strip
    assert_equal 'hello world', @project.card_types.build(:name => ' hello world   ').name
    assert_equal 'hello world', @project.card_types.build(:name => ' hello      world   ').name
  end

  def test_enumerable_property_definitions_returns_only_properties_with_managed_list_of_values_sorted_by_position
    unmanaged_property = setup_numeric_text_property_definition('bacon quality')
    managed_numeric    = setup_managed_number_list_definition('bacon fattiness', ['1', '100'])
    managed_text       = setup_property_definitions('bacon thickness' => ['thick', 'thin'])
    hidden             = setup_managed_number_list_definition('bacon hidden', ['42'], :hidden => true)
    card_type = setup_card_type @project, 'canadian', :properties => ['bacon thickness', 'bacon quality', 'bacon fattiness']
    assert_equal ['bacon thickness', 'bacon fattiness'], card_type.enumerable_property_definitions.map(&:name)
  end

  def test_error_raised_when_available_property_definitions_make_aggregate_invalid
    tree_config = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    tree_config.update_card_types({
      type_release => {:position => 0, :relationship_name => 'release'},
      type_iteration => {:position => 1, :relationship_name => 'iteration'},
      type_story => {:position => 2}
    })

    size = setup_numeric_text_property_definition('size')
    size.card_types = [type_story]
    size.save!

    type_story.clear_cache
    type_story.reload

    some_agg = setup_aggregate_property_definition('some agg',
                                                    AggregateType::SUM,
                                                    size,
                                                    tree_config.id,
                                                    type_iteration.id,
                                                    type_story)


    assert_raise(RuntimeError) do
      type_story.property_definitions = []
    end
  end

  def test_find_by_name_should_be_case_insensitive
    @project.card_types.first.update_attribute :name, 'Card'
    @project.card_types.create!(:name => 'Épico')
    assert_equal 'Card', @project.card_types.find_by_name('card').name
    assert_equal 'Card', @project.card_types.find_by_name('CARD').name
    assert_equal 'Épico', @project.card_types.find_by_name('Épico').name
    assert_nil @project.card_types.find_by_name(nil)
  end

  def test_to_xml_should_include_static_fields
    with_first_project do |project|
      xml = project.card_types.first.to_xml(:version => 'v1')
      assert_include 'id', xml
      assert_include 'name', xml
      assert_include 'color', xml
      assert_include 'position', xml
    end
  end

  def test_to_xml_should_not_include_project_id
    with_first_project do |project|
      xml = project.card_types.first.to_xml(:version => 'v1')
      assert_equal 0, get_number_of_elements(xml, "//card_type/project_id")
    end
  end

  def test_to_xml_should_include_properties
    with_first_project do |project|
      card_type = project.card_types.first
      xml = card_type.to_xml(:version => 'v1')

      assert_include 'property_definitions', xml

      properties = card_type.property_definitions_with_hiden_without_tree
      properties.each do |property|
        assert_include property.name, xml
      end
    end
  end

  def test_to_xml_should_be_version_agnostic
    with_first_project do |project|
      card_type = project.card_types.first
      assert_not_nil card_type.to_xml(:version => 'v99')
    end
  end

  def test_gets_random_color_on_create_when_assign_colors
    with_new_project do |project|
      feature = project.card_types.create!(:name  => 'feature')
      assert Color.valid?(feature.color)
    end
  end
end
