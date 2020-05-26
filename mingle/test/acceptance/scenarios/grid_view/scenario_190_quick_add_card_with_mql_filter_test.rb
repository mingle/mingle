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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../scenario_support/tree_setup')

# Tags: scenario, gridview, filters, mql, cards
class Scenario190QuickAddCardWithMqlFilterTest < ActiveSupport::TestCase
  include TreeSetup

  fixtures :users

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = login_as_proj_admin_user
    @mingle_admin, @team_member = users(:admin), users(:project_member)
    @project = create_project(:prefix => 'scenario_190', :users => [@team_member, @mingle_admin], :admins => [@project_admin_user])
  end

  # Story 12576

  def test_mql_should_override_card_defaulted_values
    setup_property_definitions(:Status => ['New', 'Open', 'Closed'])
    story_type = setup_card_type(@project, :Story, :properties => ['Status'])
    set_card_default(:Story, :Status => 'Open')
    create_card!(:name => "Testing Card", :card_type => "Story", :Status => "Closed")

    navigate_to_grid_view_for(@project)
    set_mql_filter_for("Type IS Story AND Status = Closed")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card("Story")
    assert_properties_set_on_quick_add_card(:Status => "(not set)")

    set_properties_on_quick_add_card(:Status => "Closed")
    submit_card_name_and_type("Newly Created Card")
    newly_created_card = @project.cards.find_by_name("Newly Created Card")
    assert_cards_present_in_grid_view(newly_created_card)
  end

  def test_dropping_to_columns_and_rows_populates_values_on_lightbox
    setup_property_definitions(:Status => ['New', 'Open', 'Closed'])
    story_type = setup_card_type(@project, :Story, :properties => ['Status'])
    bug_type   = setup_card_type(@project, :Bug, :properties => ['Status'])
    create_card!(:name => "Testing Card", :Status => "Closed")

    navigate_to_grid_view_for(@project)
    group_columns_by('Status')
    group_rows_by('Type')
    add_lanes(@project, 'Status', ['Open'])
    set_mql_filter_for("status > New")
    drag_and_drop_quick_add_card_to('Bug', 'Open')

    assert_card_type_set_on_quick_add_card('Bug')
    assert_properties_set_on_quick_add_card(:Status => 'Open')
    submit_card_name_and_type("Newly Created Card")
    assert_card_in_lane_and_row(@project.cards.find_by_name('Newly Created Card'), 'Open', 'Bug')
  end

  def test_changing_preselected_card_type_should_see_properties_and_values_correctly
    setup_property_definitions(:'Bug Status' => ['Bug New'], :'Story Status' => ['Story New'])
    story_type = setup_card_type(@project, :Story, :properties => ['Story Status'])
    set_card_default(:Story, :'Story Status' => 'Story New')
    bug_type   = setup_card_type(@project, :Bug, :properties => ['Bug Status'])

    create_card!(:name => "First Card")
    navigate_to_grid_view_for(@project)
    group_columns_by('Type')
    set_mql_filter_for("Type IS Bug OR Type IS Story")
    drag_and_drop_quick_add_card_to('', 'Bug')

    assert_card_type_set_on_quick_add_card('Bug')
    assert_properties_not_present_on_quick_add_card('Bug Status')

    set_quick_add_card_type_to('Story')
    assert_properties_set_on_quick_add_card('Story Status' => 'Story New')
    submit_card_name_and_type("New Story Card")

    open_card_via_card_link_in_message
    assert_properties_set_on_card_show(:'Story Status' => 'Story New', :Type => 'Story')
  end

  # bug 12918
  def test_card_type_defaults_to_available_valid_type_from_mql
    setup_property_definitions(:'Bug Status' => ['Bug New'], :'Story Status' => ['Story New'])
    story_type = setup_card_type(@project, :Story, :properties => ['Story Status'])
    set_card_default(:Story, :'Story Status' => 'Story New')
    bug_type   = setup_card_type(@project, :Bug, :properties => ['Bug Status'])

    create_card!(:name => "First Card")
    navigate_to_grid_view_for(@project)
    set_mql_filter_for("Type IS Bug OR Type IS Story")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view

    assert_card_type_set_on_quick_add_card('Bug')

    set_quick_add_card_type_to('Story')
    submit_card_name_and_type("New Story Card")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Bug')

    set_quick_add_card_type_to('Card')
    submit_card_name_and_type("card card")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Bug')
  end


  def test_using_TAGGED_WITH
    create_card!(:name => "Testing Card", :tags => ["from support case", "merge needed", "branch installer"])
    navigate_to_grid_view_for(@project)
    set_mql_filter_for("tagged with 'from support case' or tagged with 'merge needed' and not tagged with 'feature request'")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_tags_present_on_quick_add_card("from support case", "merge needed")
    assert_tags_not_present_on_quick_add_card("feature request")
  end

  def test_using_PLV
    dependency = create_card_type_property(:Dependency)
    iteration_type = setup_card_type(@project, :Iteration)
    iteration_1 = create_card!(:name => "Iteration 1", :card_type => 'Iteration')
    create_card_plv(@project, "current iteration", iteration_type, iteration_1, [dependency])
    create_card!(:name => "First Card", :Dependency => iteration_1.id)

    navigate_to_grid_view_for(@project)
    set_mql_filter_for("dependency = (current iteration)")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card(:Dependency => '(not set)')

    set_properties_on_quick_add_card(:Dependency => '(current iteration)')
    submit_card_name_and_type('Second Card')

    assert_cards_present_in_grid_view(@project.cards.find_by_name('Second Card'))
  end

  def test_using_FROM_TREE
    setup_tree_and_card_properties
    navigate_to_grid_view_for(@project)
    group_columns_by('Type')
    set_mql_filter_for("FROM TREE three_level_tree")

    drag_and_drop_quick_add_card_to('', 'iteration')
    assert_card_type_set_on_quick_add_card('iteration')
    assert_properties_not_present_on_quick_add_card('Story Status')
    assert_properties_set_on_quick_add_card('Planning release' => '(not set)')
    cancel_quick_add_card_creation

    set_mql_filter_for("FROM TREE three_level_tree WHERE Type IS Story")
    iteration1 = @project.cards.find_by_name('iteration1')
    release1   = @project.cards.find_by_name('release1')
    set_card_default(:Story, 'Planning iteration' => iteration1.number_and_name)

    drag_and_drop_quick_add_card_to('', 'story')
    assert_card_type_set_on_quick_add_card('story')
    assert_properties_set_on_quick_add_card('Planning release' => '(not set)', 'Planning iteration' => '(not set)')
    cancel_quick_add_card_creation

    iteration_type = @project.card_types.find_by_name('iteration')
    planning_iteration = @project.all_property_definitions.find_by_name('Planning iteration')
    create_card_plv(@project, "current iteration", iteration_type, iteration1, [planning_iteration])
    set_mql_filter_for("FROM TREE three_level_tree WHERE Type IS Story AND 'Planning iteration' = (current iteration)")
    drag_and_drop_quick_add_card_to('', 'story')
    assert_properties_set_on_quick_add_card('Planning release' => '(not set)', 'Planning iteration' => '(not set)')
  end

  def test_tree_relationship_props
    setup_tree_and_card_properties
    navigate_to_grid_view_for(@project)
    set_mql_filter_for("Type is story and 'planning release' = 'release1' ")
    group_columns_by(:Status)
    add_lanes(@project, 'Status', ['New','Open','(not set)'])

    drag_and_drop_quick_add_card_to('', 'Open')
    assert_properties_set_on_quick_add_card('Planning release' => '(not set)')
    assert_properties_not_present_on_quick_add_card('Planning iteration')
    submit_card_name_and_type('Testing Card')

    # bug #12903 - no JS error when change lanes after quick add card
    group_columns_by('Planning release')
    group_rows_by('Planning iteration')
    add_lanes(@project, 'Planning release', ['(not set)'])

    release1   = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')

    drag_and_drop_quick_add_card_to(iteration1.number, '')
    assert_properties_set_on_quick_add_card('Planning release' => release1.number_and_name, 'Planning iteration' => iteration1.number_and_name)
  end

  def test_predefined_or_aggregated_or_formula_or_hidden_properties_should_be_excluded
    setup_tree_and_card_properties
    release_type = @project.card_types.find_by_name('release')
    setup_aggregate_property_definition('count for release', AggregateType::COUNT, nil, @project.tree_configuration_ids.first, release_type.id, AggregateScope::ALL_DESCENDANTS)
    setup_formula_property_definition('final estimate', "2 * 2")
    @project.find_property_definition('Status').update_attribute :hidden, true

    navigate_to_grid_view_for(@project)
    set_mql_filter_for("Type != Story AND 'final estimate' = 4 OR Number > 0 OR 'Created By' != CURRENT USER")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Card') # Not Story...
    assert_properties_not_present_on_quick_add_card('Number', 'count for release', 'final estimate', 'Status', 'Created By')
  end

  def test_user_property
    create_team_property('owner')
    create_card!(:name => 'Testing Card', :owner => @mingle_admin.id)

    navigate_to_grid_view_for(@project)
    set_mql_filter_for("owner is #{@mingle_admin.login}")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card('owner' => '(not set)')
  end
end
