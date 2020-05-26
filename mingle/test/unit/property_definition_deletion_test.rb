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

class PropertyDefinitionDeletionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
  end

  def test_deletion_effects_should_include_card_count
    with_new_project do |project|
      cp_to_delete = setup_text_property_definition('foo')
      create_card!(:name => 'jimmy', :foo => 'bar')
      create_card!(:name => 'timmy', :foo => 'bar')
      card_usage_effect = cp_to_delete.deletion.effects.first
      assert_equal Card, card_usage_effect.target_model
      assert_equal 2, card_usage_effect.count
      assert_equal "#{"Important".bold}: values for this property cannot be recovered and will no longer be displayed in history. If you wish to maintain history related to this property please use the hide property feature instead of continuing with this deletion.", card_usage_effect.additional_notes
    end
  end

  def test_deletion_effects_should_include_transition_deletion
    with_first_project do |project|
      transition = create_transition(project, 'close', :set_properties => {:status => 'closed'})
      status = project.find_property_definition('status')
      usage_effect = status.deletion.effects.first
      assert_equal Transition, usage_effect.target_model
      assert_equal [transition], usage_effect.collection
    end
  end

  def test_deletion_effects_should_include_other_static_deletion
    with_first_project do |project|
      status = project.find_property_definition('status')
      other_effects = status.deletion.effects
      assert_equal [
        "Pages and tables/charts that use this property will no longer work.",
        "Previously subscribed atom feeds that use this property will no longer provide new data.",
        "Card versions previously containing only changes to this property will no longer appear in history.",
        "Any personal favorites using this property will be deleted too."
      ], other_effects.collect(&:render)
    end
  end

  def test_deletion_effects_should_not_include_card_usage_information_when_not_used_by_cards
    with_new_project do |project|
      cp_to_delete = setup_text_property_definition('foo')
      assert_equal [], cp_to_delete.deletion.effects.reject{|effect| effect.is_a? Deletion::StaticEffect }
    end
  end

  def test_deletion_effects_should_include_plv
    with_first_project do |project|
      status = project.find_property_definition('status')
      play_status = create_plv!(project, :name => 'PLAY STATUS', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'play', :property_definition_ids => [status.id])
      status.reload
      assert_equal "Used by #{'1 ProjectVariable'.bold}: #{'PLAY STATUS'.bold}. This will be disassociated.", status.deletion.effects.first.render
    end
  end

  def test_deletion_should_be_blocked_on_being_used_by_formula
    with_new_project do |project|
      dev_size = setup_numeric_text_property_definition('dev size')
      dave_size = setup_formula_property_definition('dave size', "3 * 'dev size'")

      deletion = dev_size.deletion

      assert deletion.blocked?
      assert_equal 1, deletion.blockings.size
      assert_equal "is used as a component property of #{'dave size'.bold}", deletion.blockings.first.description
      assert_equal "is used as a component property of #{'dave size'.bold}. To manage #{'dave size'.bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{dave_size.id}\" target=\"blocking\">card property management page</a>.", deletion.blockings.first.render(view_helper)
    end
  end

  def test_deletion_should_be_blocked_when_used_by_aggregate_target
    with_new_project do |project|
      cp_target, cp_aggregate = setup_property_that_is_the_target_property_of_an_aggregate(project)
      deletion = cp_target.deletion
      assert deletion.blocked?
      assert_equal 1, deletion.blockings.size
      assert_equal "is used as the target property of #{cp_aggregate.name.bold}", deletion.blockings.first.description
      assert_equal "is used as the target property of #{cp_aggregate.name.bold}. To manage #{"sum size".bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{cp_aggregate.id}\" target=\"blocking\">configure aggregate properties page</a>.", deletion.blockings.first.render(view_helper)
    end
  end

  def test_deletion_should_be_blocked_when_used_by_aggregate_condition
    with_new_project do |project|
      cp_in_condition, cp_aggregate = setup_property_that_is_in_the_condition_of_an_aggregate(project)
      deletion = cp_in_condition.deletion
      assert deletion.blocked?
      assert_equal 1, deletion.blockings.size
      assert_equal "is used in the condition of #{cp_aggregate.name.bold}", deletion.blockings.first.description
      assert_equal "is used in the condition of #{cp_aggregate.name.bold}. To manage #{"some_aggregate".bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{cp_aggregate.id}\" target=\"blocking\">configure aggregate properties page</a>.", deletion.blockings.first.render(view_helper)
    end
  end

  def test_deletion_blocking_should_be_set_for_favorites_that_use_the_property_definition
    with_first_project do |project|
      cp_status = project.find_property_definition('status')
      view_params = { :name => 'timmy', :columns => 'status' }
      view = CardListView.find_or_construct(project, view_params)
      view.save!
      blockings = cp_status.deletion_blockings
      assert_equal 1, blockings.size
      assert_equal "is used in team favorite #{'timmy'.bold}", blockings.first.description
    end
  end

  def test_deletion_blocking_should_be_set_for_favorites_which_use_it_in_mql
    with_first_project do |project|
      status = project.find_property_definition('status')
      view = CardListView.construct_from_params(project, {:style => 'list', :name => 'timmy', :filters => {:mql => 'type = story and status = open'}} )
      view.save!
      blockings = status.deletion_blockings
      assert_equal 1, blockings.size
      assert_equal "is used in team favorite #{'timmy'.bold}. To manage #{'timmy'.bold}, please go to <a href=\"/projects/#{project.identifier}/favorites/list?id=#{view.id}\" target=\"blocking\">team favorites &amp; tabs management page</a>.", blockings.first.render(view_helper)
    end
  end

  def test_deletion_blocking_should_be_set_for_tabs_that_use_the_property_definition
    with_first_project do |project|
      cp_status = project.find_property_definition('status')
      view_params = { :name => 'favorite timmy tab', :columns => 'status' }
      view = CardListView.find_or_construct(project, view_params)
      view.save!
      view.tab_view = true
      view.save!

      blockings = cp_status.deletion_blockings
      assert_equal 1, blockings.size
      assert_equal "is used in tab #{'favorite timmy tab'.bold}. To manage #{'favorite timmy tab'.bold}, please go to <a href=\"/projects/#{project.identifier}/favorites/list?id=#{view.id}\" target=\"blocking\">team favorites &amp; tabs management page</a>.", blockings.first.render(view_helper)
    end
  end

  def test_deletion_blocking_when_the_property_type_is_used_as_aggregates_target
    with_new_project do |project|
      cp_in_condition, cp_aggregate = setup_property_that_is_the_target_property_of_an_aggregate(project)
      type_release = project.card_types.find_by_name('release')
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')

      assert !cp_in_condition.blockings_when_dissociate_card_types([type_iteration]).empty?
    end
  end

  def test_deletion_blocking_when_the_property_type_is_used_as_aggregates_condition
    with_new_project do |project|
      cp_in_condition, cp_aggregate = setup_property_that_is_in_the_condition_of_an_aggregate(project)
      type_release = project.card_types.find_by_name('release')
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')

      assert !cp_in_condition.blockings_when_dissociate_card_types([type_iteration]).empty?
    end
  end

  def test_should_blocking_when_diassociation_formula_which_used_by_aggregate_in_target
    with_new_project do |project|
      tree_config = project.tree_configurations.create(:name => 'Release tree')
      type_release, type_iteration, type_story = init_planning_tree_types
      estimate = setup_numeric_text_property_definition('estimate')
      double_estimate = setup_formula_property_definition('double estimate', "estimate * 2")
      init_three_level_tree(tree_config)
      aggregate_def = setup_aggregate_property_definition('sum double estimate', AggregateType::SUM, double_estimate, tree_config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      assert_equal 1, double_estimate.blockings_when_dissociate_card_types([type_release, type_iteration, type_story]).size
      assert_equal "#{double_estimate.name.bold} is used as the target property of #{aggregate_def.name.bold}", double_estimate.blockings_when_dissociate_card_types([type_release, type_iteration, type_story]).first.description
    end
  end

  def test_should_blocking_when_diassociation_formula_which_used_by_aggregate_in_condition
    with_new_project do |project|
      tree_config = project.tree_configurations.create(:name => 'Release tree')
      type_release, type_iteration, type_story = init_planning_tree_types
      estimate = setup_numeric_text_property_definition('estimate')
      double_estimate = setup_formula_property_definition('double estimate', "estimate * 2")
      init_three_level_tree(tree_config)

      aggregate_options = { :name => 'sum of double estimate bigger than four', :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                            :aggregate_type => AggregateType::COUNT, :aggregate_card_type_id => type_release.id,
                            :tree_configuration_id => tree_config.id, :aggregate_condition => "'double estimate' > 4" }
      aggregate_def = project.property_definitions_with_hidden.create_aggregate_property_definition(aggregate_options)
      project.reload.update_card_schema

      assert_equal 1, double_estimate.blockings_when_dissociate_card_types([type_release, type_iteration, type_story]).size
      assert_equal "#{double_estimate.name.bold} is used in the condition of #{aggregate_def.name.bold}", double_estimate.blockings_when_dissociate_card_types([type_release, type_iteration, type_story]).first.description
    end
  end

  def test_should_delete_personal_favorite_using_this_after_destroy
    with_new_project do |project|
      pd = setup_text_property_definition('status')
      view_params = { :name => 'favorite timmy', :columns => 'status', :user_id => User.current.id }
      view = CardListView.find_or_construct(project, view_params)
      view.save!
      pd.destroy
      assert_nil project.reload.card_list_views.find_by_name('favorite timmy')
    end
  end

  def test_should_delete_an_enumeration_property_thats_used_in_a_card
    with_new_project do |project|
      pd = setup_managed_text_definition('status', ['new', 'open'])
      create_card!(:name => 'card1', :status => 'new')
      pd.destroy

      assert_false project.property_definitions.any? { |pd| pd.name == 'status'}
    end
  end

  private
  def setup_property_that_is_the_target_property_of_an_aggregate(project)
    tree_config = project.tree_configurations.create(:name => 'Release tree')
    type_release, type_iteration, type_story = init_planning_tree_types
    dev_size = setup_numeric_text_property_definition('dev size')
    init_three_level_tree(tree_config)

    aggregate_def = setup_aggregate_property_definition('sum size', AggregateType::SUM, dev_size, tree_config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
    return dev_size, aggregate_def
  end

  def setup_property_that_is_in_the_condition_of_an_aggregate(project)
    tree_config = project.tree_configurations.create(:name => 'Release tree')
    type_release, type_iteration, type_story = init_planning_tree_types
    dev_size = setup_numeric_text_property_definition('dev_size')
    init_three_level_tree(tree_config)

    aggregate_options = { :name => 'some_aggregate', :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                          :aggregate_type => AggregateType::COUNT, :aggregate_card_type_id => type_release.id,
                          :tree_configuration_id => tree_config.id, :aggregate_condition => "dev_size > 1" }
    aggregate_def = project.property_definitions_with_hidden.create_aggregate_property_definition(aggregate_options)
    project.reload.update_card_schema
    return dev_size, aggregate_def
  end
end
