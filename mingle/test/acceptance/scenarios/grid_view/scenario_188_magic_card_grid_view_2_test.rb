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

# Tags: scenario, gridview
class Scenario188MagicCardGridView2Test < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  fixtures :users

  STATUS = "Status"
  NEW = "New"
  OPEN = "Open"
  CLOSED = "Closed"
  SIZE = "Size"
  CARD = "Card"
  STORY = "Story"
  TYPE = "Type"
  RELEASE = "Release"
  ITERATION = "Iteration"
  NOTSET = '(not set)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_188', :users => [users(:project_member)], :admins => [users(:admin), users(:project_member)])
    login_as_project_member
  end

  #12581
  def test_quick_add_card_when_card_default_is_set
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], SIZE => [1, 2, 4])
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    set_card_default(CARD, {STATUS => NEW, SIZE => 1})
    set_card_default(STORY, {STATUS => OPEN, SIZE => 2})

    first_card = create_card!(:name => "Super Beavor Card!")
    navigate_to_grid_view_for(@project)

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card("Card")
    assert_properties_set_on_quick_add_card(STATUS => NEW, SIZE => 1)
    type_card_name("Another Card")
    submit_quick_add_card

    assert_cards_present_in_grid_view(@project.cards.find_by_name("Another Card"))
  end

  def test_quick_add_card_when_filters_are_set
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], SIZE => [1, 2, 4])
    create_card!(:name => "first Card", :card_type => CARD, STATUS => NEW)

    navigate_to_grid_view_for(@project)
    set_the_filter_property_and_value(0, :property => "Type", :value => CARD)
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => NEW)

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card(CARD)
    assert_properties_set_on_quick_add_card(STATUS => NEW)
  end

  def test_quick_add_card_when_filters_and_card_default_are_set
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], SIZE => [1, 2, 4])
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    set_card_default(CARD, {STATUS => NEW})
    set_card_default(STORY, {STATUS => OPEN})

    create_card!(:name => "Card 1", STATUS => NEW, SIZE => 1, :card_type => CARD)
    create_card!(:name => "Card 2", STATUS => OPEN, SIZE => 2, :card_type => CARD)

    create_card!(:name => "Story 1", STATUS => NEW, SIZE => 1, :card_type => STORY)
    create_card!(:name => "Story 2", STATUS => OPEN, SIZE => 2, :card_type => STORY)

    navigate_to_grid_view_for(@project)
    set_the_filter_property_and_value(0, :property => "Type", :value => STORY)

    group_rows_by(TYPE)
    group_columns_by(SIZE)

    drag_and_drop_quick_add_card_to(STORY, 1)
    assert_properties_set_on_quick_add_card(STATUS => OPEN)

    cancel_quick_add_card_creation
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => NEW)

    drag_and_drop_quick_add_card_to(STORY, 1)
    assert_properties_set_on_quick_add_card(STATUS => NEW)
  end

  def test_quick_add_card_inherits_row_and_column_settings_on_grid_view
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], SIZE => [1, 2, 4])
    create_card!(:name => "testing card 1", STATUS => NEW, SIZE => 1)
    create_card!(:name => "testing card 1", STATUS => OPEN, SIZE => 2)

    navigate_to_grid_view_for(@project)
    group_rows_by(STATUS)
    group_columns_by(SIZE)
    add_lanes(@project, SIZE, [1, 2, 4, '(not set)'])

    drag_and_drop_quick_add_card_to(NEW, 1)
    assert_properties_set_on_quick_add_card(STATUS => NEW, SIZE => 1)
    cancel_quick_add_card_creation

    drag_and_drop_quick_add_card_to(NEW, '')
    assert_properties_set_on_quick_add_card(STATUS => NEW)
    assert_properties_not_present_on_quick_add_card(SIZE)
  end

  def test_quick_add_card_by_drag_and_drop_quick_add_card_to_specify_cell
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], SIZE => [1, 2, 4])
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    set_card_default(CARD, {STATUS => NEW, SIZE => 1})
    set_card_default(STORY, {STATUS => OPEN, SIZE => 2})

    create_card!(:name => "testing card 1", STATUS => NEW, SIZE => 1)
    create_card!(:name => "testing card 2", STATUS => OPEN, SIZE => 2)

    navigate_to_grid_view_for(@project)
    group_rows_by(STATUS)
    group_columns_by(SIZE)

    drag_and_drop_quick_add_card_to(NEW, 1)
    type_card_name("testing card 3")
    submit_quick_add_card

    assert_card_in_lane_and_row(@project.cards.find_by_name("testing card 3"), 1, NEW)

    drag_and_drop_quick_add_card_to(NEW, 2)
    type_card_name("testing card 4")
    submit_quick_add_card

    assert_card_in_lane_and_row(@project.cards.find_by_name("testing card 4"), 2, NEW)
  end

  def test_quick_add_card_when_group_cards_by_tree_props
    @project.with_active_project do |project|
      create_two_release_planning_tree
    end

    navigate_to_grid_view_for(@project)

    set_the_filter_property_and_value(0, :property => "Type", :value => 'story')
    group_columns_by('Planning iteration')
    group_rows_by('Planning release')
    release1 = @project.cards.find_by_name('release1');
    iteration1 = @project.cards.find_by_name('iteration1');
    drag_and_drop_quick_add_card_to(release1.number, iteration1.number)
    assert_properties_set_on_quick_add_card('Planning release' => release1.number_and_name, 'Planning iteration' => iteration1.number_and_name)
  end

  def test_quick_add_card_when_filter_and_group_by_tree_props
    @project.with_active_project do |project|
      create_planning_tree_with_duplicate_iteration_names
      @release1 = project.cards.find_by_name('release1')
      @release2 = project.cards.find_by_name('release2')
      @rel1_it1 = project.cards.find_by_name_and_cp_planning_release_card_id('iteration1', @release1.id)
      @rel2_it1 = project.cards.find_by_name_and_cp_planning_release_card_id('iteration1', @release2.id)
    end

    navigate_to_grid_view_for(@project)
    set_the_filter_property_and_value(0, :property => "Type", :value => 'story')

    add_new_filter
    set_the_filter_property_option(1, 'Planning iteration')
    set_the_filter_value_using_select_lightbox(1, @rel1_it1)

    group_columns_by('Planning iteration')
    group_rows_by('Planning release')

    add_lanes(@project, 'Planning iteration', ["#{@release2.name} > #{@rel2_it1.name}"])
    drag_and_drop_quick_add_card_to(@release1.number, @rel2_it1.number)
    type_card_name("Testing Card")
    assert_properties_set_on_quick_add_card("Planning release" => @release2.number_and_name, "Planning iteration" => @rel2_it1.number_and_name)
    submit_quick_add_card

    assert_card_created_with_message_not_match_filter
    open_card_via_card_link_in_message
    assert_properties_set_on_card_show("Planning release" => @release2, "Planning iteration" => @rel2_it1)
  end

  ##################################################################################################
  #                                 ---------------Planning tree-----------------
  #                                |                                            |
  #                    ----- release1----                                -----release2-----
  #                   |                 |                               |                 |
  #              iteration1      iteration2                       iteration3          iteration4
  #                  |                                                 |
  #           ---story1----                                         story2
  #          |           |
  #       task1   -----task2----
  #              |             |
  #          minutia1       minutia2
  #
  ##################################################################################################
  def test_drag_drop_quick_add_card_to_a_cell_that_should_overwrite_tree_props_setup_in_card_defaults_and_filters
    @project.with_active_project do |project|
      create_five_level_tree
      task_type = project.card_types.find_by_name('task')
      story2 = project.cards.find_by_name('story2')
      set_card_default('task', {'Planning story' => story2.id})

      @release1 = project.cards.find_by_name('release1')
      @iteration1 = project.cards.find_by_name('iteration1')
      @iteration2 = project.cards.find_by_name('iteration2')
    end

    navigate_to_grid_view_for(@project)
    set_the_filter_property_and_value(0, :property => "Type", :value => 'task')

    add_new_filter
    set_the_filter_property_option(1, 'Planning iteration')
    set_the_filter_value_using_select_lightbox(1, @iteration1)

    group_columns_by('Planning iteration')
    group_rows_by('Planning release')

    add_lanes(@project, 'Planning iteration', ["#{@release1.name} > #{@iteration2.name}"])
    drag_and_drop_quick_add_card_to(@release1.number, @iteration2.number)
    type_card_name("Testing Card")
    assert_properties_set_on_quick_add_card("Planning release" => @release1.number_and_name, "Planning iteration" => @iteration2.number_and_name)
    assert_properties_not_present_on_quick_add_card("Planning story")
    submit_quick_add_card

    assert_card_created_with_message_not_match_filter
    open_card_via_card_link_in_message
    assert_properties_set_on_card_show("Planning release" => @release1, "Planning iteration" => @iteration2)
    assert_properties_not_set_on_card_show('Planning story')
  end

  def test_change_card_type_after_drag_drop_quick_add_card
    @project.with_active_project do |project|
      create_five_level_tree
      status = setup_managed_text_definition(STATUS, [NEW, OPEN, CLOSED])
      status.card_types = project.card_types
      status.save!
      project.reload

      set_card_default('story', STATUS => OPEN)
      set_card_default('iteration', STATUS => CLOSED)
      set_card_default('release', STATUS => NEW)
      @release1 = @project.cards.find_by_name('release1');
      @iteration1 = @project.cards.find_by_name('iteration1');
    end

    navigate_to_grid_view_for(@project)

    set_the_filter_property_and_value(0, :property => "Type", :value => 'story')
    add_new_filter
    set_the_filter_property_and_value(1, :property => "Type", :value => 'task')

    group_columns_by('Planning iteration')
    group_rows_by('Planning release')

    drag_and_drop_quick_add_card_to(@release1.number, @iteration1.number)

    assert_card_type_set_on_quick_add_card('story')
    assert_properties_set_on_quick_add_card(STATUS => OPEN)
    set_quick_add_card_type_to('iteration')
    assert_properties_set_on_quick_add_card("Planning release" => @release1.number_and_name, STATUS => CLOSED)
    assert_properties_not_present_on_quick_add_card('Planning iteration')

    set_quick_add_card_type_to('story')
    assert_properties_set_on_quick_add_card("Planning release" => @release1.number_and_name, "Planning iteration" => @iteration1.number_and_name, STATUS => OPEN)

    set_quick_add_card_type_to('release')
    assert_properties_set_on_quick_add_card(STATUS => NEW)
    assert_properties_not_present_on_quick_add_card('Planning release', 'Planning iteration')
    type_card_name('test card')
    submit_quick_add_card
    assert_card_created_with_message_not_match_filter
    open_card_via_card_link_in_message
    assert_properties_set_on_card_show("Type" => 'release')
  end

  def test_quick_add_card_when_tree_props_used_in_filters_and_set_in_card_defaults
    create_a_ris_tree
    add_cards_to_tree(@planning_tree, @release_1, @iteration_1)
    add_cards_to_tree(@planning_tree, @release_2, @iteration_2)

    set_card_default("Story", {:iteration => @iteration_1.id})
    card_so_grid_shown = create_card!(:name => "Beavor!", :card_type => STORY)
    add_cards_to_tree(@planning_tree, @iteration_1, card_so_grid_shown)

    navigate_to_grid_view_for(@project)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[release][is][#{@release_1.number}]", "grid")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card(:release => @release_1.number_and_name)
    submit_card_name_and_type("Newly Created Card")

    newly_created_card = @project.cards.find_by_name("Newly Created Card")
    assert_cards_present_in_grid_view(newly_created_card)

    another_card_so_grid_shown = create_card!(:name => "Beavor!", :card_type => STORY)
    add_cards_to_tree(@planning_tree, @iteration_2, another_card_so_grid_shown)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[release][is][#{@release_2.number}]", "grid")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card(:release => @release_2.number_and_name)

    submit_card_name_and_type("Another Card")

    another_card = @project.cards.find_by_name("Another Card")
    assert_cards_present_in_grid_view(another_card)
  end

  def test_quick_add_card_when_tree_props_used_in_filters
    create_a_ris_tree
    add_cards_to_tree(@planning_tree, :root, @iteration_1)
    add_cards_to_tree(@planning_tree, @iteration_1, @story_1)

    create_card!(:name => "Testing Story", :card_type => STORY, 'iteration' => @iteration1)
    navigate_to_grid_view_for(@project)

    set_the_filter_property_and_value(0, :property => "Type", :value => STORY)
    add_new_filter
    set_the_filter_using_tree_prop(1, "iteration", @iteration_1)
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card(:iteration => @iteration_1.number_and_name)
    cancel_quick_add_card_creation

    add_cards_to_tree(@planning_tree, @release_1, @iteration_1)
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card(:iteration => @iteration_1.number_and_name, :release => @release_1.number_and_name)

    type_card_name("Newly Created Card")
    submit_quick_add_card
    newly_created_card = @project.cards.find_by_name("Newly Created Card")
    assert_cards_present_in_grid_view(newly_created_card)
  end

  def test_quick_add_card_when_filter_by_date_property
    date = create_date_property("start_on")
    create_card!(:name => 'Card 1', "start_on" => "(today)")

    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => "start_on", :value => "(today)")

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    new_card_number = submit_card_name_and_type("New Card")
    new_card = @project.cards.find_by_number(new_card_number)

    assert_cards_present_in_grid_view(new_card)
  end

  def test_quick_add_card_when_filter_by_user_property
    create_team_property("owner")
    proj_member = users(:project_member)
    proj_member.update_attributes(:name => "member")
    proj_member.reload

    create_card!(:name => 'Card 1', "owner" => proj_member.id)

    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => "owner", :value => proj_member.name)

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card("owner" => proj_member.name)
  end

  def test_quick_add_card_when_filter_by_card_type_property
    create_card_type_property("depend_on")
    card_1 = create_card!(:name => 'Card 1')
    card_2 = create_card!(:name => 'Card 2',  "depend_on" => card_1.id)

    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_option(1, "depend_on")
    set_the_filter_value_using_select_lightbox(1, card_1)

    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card("depend_on" => card_1.number_and_name)
  end

  def test_quick_add_card_when_use_plv_in_filters_and_filters_changes_should_be_reflected
    create_managed_text_list_property("status", [NEW, OPEN, CLOSED])
    plv = create_project_variable(@project, :name => "turkey plv", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'turkey', :properties => ["status"])
    create_card!(:name => "Turkey Card!", "status" => "#{plv.value}")
    create_card!(:name => "Beavor!", "status" => NEW)

    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => "status", :value => "(#{plv.name})")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card("status" => "#{plv.value}")

    cancel_quick_add_card_creation
    set_the_filter_property_and_value(1, :property => "status", :value => NEW)
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_properties_set_on_quick_add_card("status" => NEW)
  end

  # bug 12829
  def test_grid_view_with_tree_should_not_show_property_in_common_with_types_unless_filtered_for
    create_a_ris_tree
    add_cards_to_tree(@planning_tree, :root, @release_1)
    add_cards_to_tree(@planning_tree, :root, @release_2)
    add_cards_to_tree(@planning_tree, @release_1, @iteration_1, @iteration_2)
    add_cards_to_tree(@planning_tree, @iteration_1, @story_1, @story_2)

    navigate_to_grid_view_for(@project, :tree_name  => @planning_tree.name)

    group_columns_by(TYPE)
    click_exclude_card_type_checkbox(@release_type)
    set_tree_filter_for(@iteration_type, 0, :property => "iteration", :value => @iteration_1.number)
    set_tree_filter_for(@iteration_type, 1, :property => @universal_property.name, :value => NOTSET)
    drag_and_drop_quick_add_card_to("",STORY)
    assert_properties_not_present_on_quick_add_card(@universal_property.name)
  end

  # bug 12918
  def test_card_type_defaults_to_available_valid_type_from_basic_filter
    setup_property_definitions(:'Bug Status' => ['Bug New'], :'Story Status' => ['Story New'])
    story_type = setup_card_type(@project, :Story, :properties => ['Story Status'])
    set_card_default(:Story, :'Story Status' => 'Story New')
    bug_type   = setup_card_type(@project, :Bug, :properties => ['Bug Status'])

    create_card!(:name => "First Card")
    navigate_to_grid_view_for(@project)
    set_filter_by_url(@project, "filters[]=[Type][is][Bug]&filters[]=[type][is][Story]", "grid")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Bug')

    set_quick_add_card_type_to('Story')
    submit_card_name_and_type("New Story Card")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Story')

    set_quick_add_card_type_to('Card')
    submit_card_name_and_type("card card")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card('Bug')
  end

    # bug 12911 - defautled any text/number property are not displayed on quick add when use mql filters
  def test_any_text_number_properties
    setup_text_property_definition('release tag')
    setup_numeric_text_property_definition('revision reported')
    set_card_default(CARD, 'revision reported' => 1, 'release tag' => 'in current release')

    navigate_to_grid_view_for(@project)
    set_mql_filter_for('Type = Card')
    open_add_card_via_quick_add
    assert_umnanaged_properties_set_on_quick_add_card('revision reported' => '1', 'release tag' => 'in current release')
    set_unmanaged_propertes_on_quick_add_card(@project, 'revision reported' => 2)
    submit_card_name_and_type("Testing")

    open_card_via_card_link_in_message
    assert_properties_set_on_card_show('revision reported' => '2', 'release tag' => 'in current release')
  end

  # bug 12911 - missing validation for property values on quick add lightbox
  def test_validation_of_property_values
    setup_date_property_definition('start on')
    setup_numeric_property_definition('estimate', [1, 2, 4, 8])
    setup_numeric_text_property_definition('revision reported')
    set_card_default(CARD, {'start on' => 'today', 'estimate' => 1, 'revision reported' => 1})
    create_card!(:name => 'First Card')

    navigate_to_grid_view_for(@project)
    open_add_card_via_quick_add

    set_unmanaged_propertes_on_quick_add_card(@project, 'revision reported' => 'invalid value for revision reported', 'start on' => 'invalid value for start on', 'estimate' => 'invalid value for estimate')
    type_card_name("Testing")
    submit_quick_add_card
    assert_text_present('invalid value for revision reported is an invalid numeric value')
    assert_text_present('invalid value for estimate is an invalid numeric value')
    assert_text_present("invalid value for start on is an invalid date")

    cancel_quick_add_card_creation
    navigate_to_grid_view_for(@project)
    set_mql_filter_for('Type = Card')
    drag_and_drop_quick_add_card_to_ungrouped_grid_view

    set_unmanaged_propertes_on_quick_add_card(@project, 'revision reported' => 'invalid value for revision reported', 'start on' => 'invalid value for start on', 'estimate' => 'invalid value for estimate')
    type_card_name("Testing")
    submit_quick_add_card
    assert_text_present('invalid value for revision reported is an invalid numeric value')
    assert_text_present('invalid value for estimate is an invalid numeric value')
    assert_text_present("invalid value for start on is an invalid date")
  end


  private

  def set_the_filter_using_tree_prop(filter_number, prop_name, prop_value)
    set_the_filter_property_option(filter_number, prop_name)
    set_the_filter_value_using_select_lightbox(filter_number, prop_value)
  end

  def create_a_ris_tree
    @universal_property = create_managed_text_list_property('universal',[NEW,OPEN])
    @release_type = setup_card_type(@project, RELEASE, :properties => [ @universal_property.name])
    @iteration_type = setup_card_type(@project, ITERATION, :properties => [@universal_property.name])
    @story_type = setup_card_type(@project, STORY, :properties => [@universal_property.name])
    @planning_tree = setup_tree(@project, "Planning Tree", :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["release", "iteration"])

    @release_1 = create_card!(:name => "Release 1", :card_type => RELEASE)
    @release_2 = create_card!(:name => "Release 2", :card_type => RELEASE)

    @iteration_1 = create_card!(:name => "Iteration 1", :card_type => ITERATION)
    @iteration_2 = create_card!(:name => "Iteration 2", :card_type => ITERATION)

    @story_1 = create_card!(:name => "Story 1", :card_type => STORY)
    @story_2 = create_card!(:name => "Story 2", :card_type => STORY)
  end

  def assert_card_created_with_message_not_match_filter
    assert_notice_message("was successfully created, but is not shown because it does not match the current filter.")
  end

  def assert_on_grid_view
    @browser.assert_text_present_in("class=selected_view", "Grid")
  end

  def assert_properties_settings_are_inherited(property_values)
    property_values.each do |prop_name, prop_value|
      if prop_name == "Type"
        assert_card_type_set_on_card_edit(prop_value)
      else
        assert_property_set_on_card_edit(prop_name, prop_value)
      end
    end
  end

  private
  def setup_filters(target_prop_name, operator, compare_to_value)
      prop_type = compare_to_value.class.name
      if prop_type == "Card"
          value = compare_to_value.number
      elsif prop_type == "User"
          value = compare_to_value.login
      else
          value = compare_to_value
      end

      set_filter_by_url(@project, "filters[]=[#{target_prop_name}][#{operator}][#{value}]", "grid")
  end
end
