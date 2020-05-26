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

# Tags: scenario, gridview
class Scenario189MagicCardOnGridViewWithTreeTest < ActiveSupport::TestCase
  fixtures :users
  include TreeFixtures::PlanningTree, TreeSetup

  STATUS = "Status"
  NEW = "New"
  OPEN = "Open"
  CLOSED = "Closed"
  ESTIMATION = "Estimation"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_189', :users => [@team_member, @mingle_admin], :admins => [@project_admin_user])
    login_as_proj_admin_user
  end

  # story 12567
  def test_set_card_type_and_properties_based_on_tree_filters
    setup_tree_and_card_properties

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    click_exclude_card_type_checkbox("release", "iteration")

    set_tree_filter_for(@iteration, 0, :property => "Planning iteration", :value => iteration1.number)
    set_tree_filter_for(@story, 0, :property => STATUS, :value => NEW)
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card("story")
    assert_properties_set_on_quick_add_card("Planning iteration" => iteration1.number_and_name, STATUS => NEW)

    submit_card_name_and_type("Testing Card")
    open_card_via_card_link_in_message

    assert_properties_set_on_card_show('Type' => 'story', "Planning release" => release1, "Planning iteration" => iteration1, STATUS => NEW)
  end

  def test_group_by_settings_should_overwrite_tree_filters
    setup_tree_and_card_properties

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    click_exclude_card_type_checkbox("release", "iteration")

    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [OPEN])

    set_tree_filter_for(@iteration, 0, :property => "Planning iteration", :value => iteration1.number)
    set_tree_filter_for(@story, 0, :property => STATUS, :value => NEW)
    drag_and_drop_quick_add_card_to("", OPEN)
    assert_card_type_set_on_quick_add_card("story")
    assert_properties_set_on_quick_add_card("Planning iteration" => iteration1.number_and_name, STATUS => OPEN)

    submit_card_name_and_type("Testing Card")
    open_card_via_card_link_in_message
    assert_properties_set_on_card_show('Type' => 'story', "Planning release" => release1, "Planning iteration" => iteration1, STATUS => OPEN)
  end

  def test_tree_filters_should_overwrite_card_defaults
    setup_tree_and_card_properties

    set_card_default('iteration', STATUS => OPEN, 'Planning release' => release1.id)

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    click_exclude_card_type_checkbox("release", "story")

    set_tree_filter_for(@iteration, 0, :property => STATUS, :value => CLOSED)

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card("iteration")
    assert_properties_set_on_quick_add_card(STATUS => CLOSED, 'Planning release' => release1.number_and_name)

    submit_card_name_and_type("Testing Card")
    open_card_via_card_link_in_message
    assert_properties_set_on_card_show('Type' => 'iteration', STATUS => CLOSED, 'Planning release' => release1)
  end

  def test_change_card_type_should_apply_filters_of_that_type
    setup_tree_and_card_properties

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    click_exclude_card_type_checkbox("release")

    set_tree_filter_for(@iteration, 0, :property => STATUS, :value => CLOSED)
    set_tree_filter_for(@story, 0, :property => ESTIMATION, :value => '1')

    drag_and_drop_quick_add_card_to_ungrouped_grid_view

    assert_card_type_set_on_quick_add_card("iteration")
    assert_properties_set_on_quick_add_card(STATUS => CLOSED)

    set_quick_add_card_type_to("story")
    assert_properties_set_on_quick_add_card(ESTIMATION => 1)
    assert_properties_not_present_on_quick_add_card(STATUS)
  end

  def test_apply_ambiguous_tree_filter_of_managed_number_property
    setup_tree_and_card_properties

    navigate_to_grid_view(
      'excluded' => ['release', 'iteration'],
      'tree_name' => 'three_level_tree',
      'tf_story' => ['[Estimation][is greater than][1]']
    )

    drag_and_drop_quick_add_card_to_ungrouped_grid_view

    assert_card_type_set_on_quick_add_card("story")
    assert_properties_set_on_quick_add_card(ESTIMATION => 2)
  end

  def test_apply_ambiguous_tree_filter_of_date_property
    setup_tree_and_card_properties
    associate_property_definition_with_card_type(setup_date_property_definition('Start Date'), @story)

    story1.cp_start_date = Date.parse('Sep 01 2011')
    story1.save!

    navigate_to_grid_view(
      'excluded' => ['release', 'iteration'],
      'tree_name' => 'three_level_tree',
      'tf_story' => ['[Start Date][is less than][01 Oct 2011]', '[Start Date][is greater than][01 Jan 2011]']
    )

    group_columns_by(STATUS)
    group_rows_by(ESTIMATION)
    add_lanes(@project,STATUS, [OPEN])

    drag_and_drop_quick_add_card_to(4, OPEN)
    new_card_number = submit_card_name_and_type("Testing Card")
    assert_card_in_lane_and_row(@project.cards.find_by_number(new_card_number), OPEN, '4')
  end


  # bug 12838
  def test_can_create_card_whose_type_is_not_in_tree
    setup_tree_and_card_properties

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    group_columns_by("Type")
    add_lanes(@project, 'Type', ['Card'], :type => true)

    drag_and_drop_quick_add_card_to("", "Card")
    submit_card_name_and_type("Bucky Beavor!")

    open_card_via_card_link_in_message
    assert_properties_set_on_card_show("Type" => "Card")

    navigate_to_grid_view_for(@project, :tree_name => "three_level_tree")
    group_columns_by("Type")

    drag_and_drop_quick_add_card_to("", "iteration")
    set_quick_add_card_type_to("Card")
    submit_card_name_and_type("Bucky Beavor Junior!")

    open_card_via_card_link_in_message
    assert_properties_set_on_card_show("Type" => "Card")
  end

  private

  # filters => hash
  def navigate_to_grid_view(filters)
    set_filter_by_url(@project, filters.to_query, "grid")
  end

  def story1
    @story1 ||= @project.cards.find_by_name('story1')
  end

  def iteration1
    @iteration1 ||= @project.cards.find_by_name("iteration1")
  end

  def release1
    @release1 ||= @project.cards.find_by_name("release1")
  end

end
