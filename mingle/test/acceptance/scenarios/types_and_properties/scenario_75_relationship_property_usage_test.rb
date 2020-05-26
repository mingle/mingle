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

# Tags: relationship-properties, tree_usage
class Scenario75RelationshipPropertyUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  SIZE2 = 'size2'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOT_SET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'

  SUM = 'Sum'
  COUNT = 'Count'
  AVERAGE = 'Average'

  PLANNING_TREE = 'planning tree'
  USER_INPUT_OPTIONAL = '(user input - optional)'

  #does_not_work_on_google_chrome

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_75', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', LOW], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @size_property = setup_numeric_property_definition(SIZE, [1, 2, 4])
    @size2_property = setup_numeric_property_definition(SIZE2, [0, 3, 5])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE2, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    navigate_to_tree_configuration_management_page_for(@project)
  end

  def test_create_tree_relationship_property_with_none_default_name_should_reflect_on_cards_edit
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}"])
    @card_story = create_card!(:name => "story 1", :card_type => @type_story)
    @card_iteration = create_card!(:name => "Iteration 1", :card_type => @type_iteration)

    open_card_for_edit(@project, @card_story)
    assert_property_set_on_card_edit("#{PLANNING_TREE} - #{RELEASE}", NOT_SET)
    assert_property_set_on_card_edit("relationship-#{ITERATION_TYPE}", NOT_SET)
    open_card_for_edit(@project, @card_iteration)
    assert_property_set_on_card_edit("#{PLANNING_TREE} - #{RELEASE}", NOT_SET)
    assert_property_not_present_on_card_edit("relationship-#{ITERATION_TYPE}")
  end

  def test_create_tree_relationship_property_with_none_default_name_should_reflect_on_cards_show
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["#{PLANNING_TREE}-#{RELEASE}", "relationship-#{ITERATION_TYPE}"])
    @card_story = create_card!(:name => "story 1", :card_type => @type_story)
    @card_iteration = create_card!(:name => "Iteration 1", :card_type => @type_iteration)

    open_card(@project, @card_story)
    assert_property_set_on_card_show("#{PLANNING_TREE}-#{RELEASE}", NOT_SET)
    assert_property_set_on_card_show("relationship-#{ITERATION_TYPE}", NOT_SET)
    open_card(@project, @card_iteration)
    assert_property_set_on_card_show("#{PLANNING_TREE}-#{RELEASE}", NOT_SET)
    assert_property_not_present_on_card_show("relationship-#{ITERATION_TYPE}")
  end

  def test_relationship_property_names_reflect_on_card_defaults
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["PLRelease", "PLIteration"])
    open_edit_defaults_page_for(@project, STORY)
    assert_property_present_on_card_defaults('PLRelease')
    assert_property_present_on_card_defaults('PLIteration')
  end

  def test_bulk_edit_holds_renamed_relationship_properties
    @card_story = create_card!(:name => "story 1", :card_type => @type_story)
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["PLRelease", "PLIteration"])
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    select_all
    click_edit_properties_button
    assert_property_present_in_bulk_edit_panel('PLRelease')
    assert_property_present_in_bulk_edit_panel('PLRelease')
  end

  def test_transitions_hold_relationship_properties_and_can_be_set
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}"])
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(STORY)
    assert_requires_property_present("#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}")
    assert_sets_property_present("#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}")

    set_card_type_on_transitions_page(ITERATION_TYPE)
    assert_requires_property_present("#{PLANNING_TREE} - #{RELEASE}")
    assert_sets_property_present("#{PLANNING_TREE} - #{RELEASE}")
    assert_requires_property_not_present("relationship-#{ITERATION_TYPE}")
    assert_sets_property_not_present("relationship-#{ITERATION_TYPE}")
  end

  def test_only_one_relationship_property_can_be_set_for_sets_per_transition
    puts "Test started"
    get_tree_built_with_aggregates_and_cards_in_it
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(STORY)
    set_required_properties(@project, :'PT iteration' => card_number_and_name(@iteration_cards[0]))
    set_sets_properties(@project, :'PT iteration' => card_number_and_name(@iteration_cards[1]))
    assert_sets_property_and_value_read_only(@project, 'PT release', "(determined by tree)")

    open_transition_create_page(@project)
    set_card_type_on_transitions_page(STORY)
    set_sets_properties(@project, :'PT release' => card_number_and_name(@release_cards[0]))
    assert_sets_property_and_value_read_only(@project, 'PT iteration', "(no change)")
  end

  def test_removing_a_node_from_configuration_deletes_the_relationship_property_from_cards
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}"])
    cp_iteration_relationship = @project.find_property_definition("relationship-#{ITERATION_TYPE}")
    @card_story = create_card!(:name => "story 1", :card_type => @type_story)

    open_card_for_edit(@project, @card_story)
    assert_property_set_on_card_edit("#{PLANNING_TREE} - #{RELEASE}", NOT_SET)
    assert_property_set_on_card_edit("relationship-#{ITERATION_TYPE}", NOT_SET)

    open_configure_a_tree_through_url(@project, tree)
    remove_card_type_node_from_tree(1)
    click_save_link
    assert_warning_messages_on_tree_node_remove(ITERATION_TYPE, "relationship-#{ITERATION_TYPE}")
    click_save_permanently_link

    open_card(@project, @card_story)
    assert_property_set_on_card_show("#{PLANNING_TREE} - #{RELEASE}", NOT_SET)
    assert_property_not_present_on_card_show(cp_iteration_relationship)

    open_card_for_edit(@project, @card_story)
    assert_property_set_on_card_edit("#{PLANNING_TREE} - #{RELEASE}", NOT_SET)
    assert_property_not_present_on_card_edit(cp_iteration_relationship)
  end

  def test_can_set_relationship_properties_using_save_and_add_another
    bug_cluster_property = 'Bug Cluster property'
    card_type_with_spaces_in_the_name = setup_card_type(@project, 'bug cluster')
    bug_cluster_tree = setup_tree(@project, 'Bug Cluster Tree', :types => [card_type_with_spaces_in_the_name, @type_defect], :relationship_names => [bug_cluster_property])
    bug_cluster_card = create_card!(:name => 'Bug Cluster A', :card_type => card_type_with_spaces_in_the_name)
    defect_card = create_card!(:name => 'defect A', :card_type => @type_defect)
    add_card_to_tree(bug_cluster_tree, bug_cluster_card)
    open_card_for_edit(@project, defect_card)
    set_relationship_properties_on_card_edit(bug_cluster_property => bug_cluster_card)
    assert_properties_set_on_card_edit(bug_cluster_property => bug_cluster_card)
    click_save_and_add_another_link
    assert_notice_message("Card ##{defect_card.number} was successfully updated.")
    type_card_name('confirming bug 3066')
    assert_properties_set_on_card_edit(bug_cluster_property => bug_cluster_card)
    save_card
    saved_and_added_another_card_number = defect_card.number + 1

    @browser.run_once_history_generation
    open_card(@project, saved_and_added_another_card_number)
    assert_history_for(:card, saved_and_added_another_card_number).version(1).shows(:set_properties => {bug_cluster_property => card_number_and_name(bug_cluster_card)})
  end

  # bug 3444
  def test_can_set_relationship_properties_on_card_when_card_type_name_has_spaces_in_it
    bug_cluster_property = 'Bug Cluster property'
    card_type_with_spaces_in_the_name = setup_card_type(@project, 'bug cluster')
    bug_cluster_tree = setup_tree(@project, 'Bug Cluster Tree', :types => [card_type_with_spaces_in_the_name, @type_defect],
      :relationship_names => [bug_cluster_property])
    bug_cluster_card = create_card!(:name => 'Bug Cluster A', :card_type => card_type_with_spaces_in_the_name)
    defect_card = create_card!(:name => 'defect A', :card_type => @type_defect)
    open_card(@project, defect_card)
    set_relationship_properties_on_card_show(bug_cluster_property => bug_cluster_card)
    @browser.run_once_history_generation
    open_card(@project, defect_card)

    assert_history_for(:card, defect_card.number).version(2).shows(:set_properties => {bug_cluster_property => card_number_and_name(bug_cluster_card)})
    assert_history_for(:card, defect_card.number).version(3).not_present
  end

  # bug 3287
  def test_values_for_relationship_properties_appear_as_card_number_and_card_name_on_card_show_and_edit
    bug_cluster_property = 'Bug Cluster property'
    bug_cluster_type = setup_card_type(@project, 'bug cluster')
    bug_cluster_tree = setup_tree(@project, 'Bug Cluster Tree', :types => [bug_cluster_type, @type_defect], :relationship_names => [bug_cluster_property])
    bug_cluster_card = create_card!(:name => 'Bug Cluster A', :card_type => bug_cluster_type)
    defect_card = create_card!(:name => 'defect A', :card_type => @type_defect)
    add_card_to_tree(bug_cluster_tree, bug_cluster_card)
    add_card_to_tree(bug_cluster_tree, defect_card, bug_cluster_card)
    open_card(@project, defect_card)
    assert_property_set_on_card_show(bug_cluster_property, card_number_and_name(bug_cluster_card))

    open_card_for_edit(@project, defect_card)
    assert_property_set_on_card_edit(bug_cluster_property, card_number_and_name(bug_cluster_card))
  end

  # bug 3419
  def test_value_for_relationship_property_escapes_html_in_history_versions_and_filter
    card_name_with_html_tags = "<b>NEW</b> card"
    same_name_without_html_tags = "NEW card"
    story_card = create_card!(:name => card_name_with_html_tags, :card_type => @type_story)
    task_card = create_card!(:name => 'task one', :card_type => @type_task)
    story_property = 'story tree property'
    story_tree = setup_tree(@project, 'Story Tree', :types => [@type_story, @type_task], :relationship_names => [story_property])
    add_card_to_tree(story_tree, story_card)
    add_card_to_tree(story_tree, task_card, story_card)
    @browser.run_once_history_generation
    open_card(@project, task_card.number)
    assert_history_for(:card, task_card.number).version(2).shows(:set_properties => {story_property => card_number_and_name(story_card)})
    assert_history_for(:card, task_card.number).version(2).does_not_show(:set_properties => {story_property => "##{story_card.number} #{same_name_without_html_tags}"})
    navigate_to_history_for(@project)
    filter_history_using_first_condition_by(@project, story_property => card_number_and_name(story_card))
    assert_properties_in_first_filter_widget(story_property => card_number_and_name(story_card))
    navigate_to_history_for(@project)
    filter_history_using_second_condition_by(@project, story_property => card_number_and_name(story_card))
    assert_properties_in_second_filter_widget(story_property => card_number_and_name(story_card))
  end

  # bug 3256 & 3401
  def test_renaming_card_that_is_set_as_value_of_relationship_property_renames_property_value_on_card
    new_name_for_story_card = 'NEW name'
    story_card = create_card!(:name => 'original name', :card_type => @type_story)
    task_card = create_card!(:name => 'task one', :card_type => @type_task)
    story_property = 'story tree property'
    story_tree = setup_tree(@project, 'Story Tree', :types => [@type_story, @type_task], :relationship_names => [story_property])
    add_card_to_tree(story_tree, story_card)
    add_card_to_tree(story_tree, task_card, story_card)
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, card_number_and_name(story_card))
    open_card(@project, story_card)
    edit_card(:name => new_name_for_story_card)
    new_display_number_and_name_for_story_card = "##{story_card.number} #{new_name_for_story_card}"
    @browser.run_once_history_generation
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, new_display_number_and_name_for_story_card)
    # the following 5 calls is an attempt to simulate refresh that was needed to reproduce the bug
    open_card(@project, task_card)
    open_card(@project, task_card)
    open_card(@project, task_card)
    open_card(@project, task_card)
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, new_display_number_and_name_for_story_card)
    assert_history_for(:card, task_card.number).version(2).shows(:set_properties => {story_property => new_display_number_and_name_for_story_card})
  end

  # bug 3254
  def test_renaming_card_that_is_in_a_tree_does_not_drop_card_from_the_tree
    new_name_for_story_card = 'NEW name'
    story_card = create_card!(:name => 'original name', :card_type => @type_story)
    task_card = create_card!(:name => 'task one', :card_type => @type_task)
    iteration_card = create_card!(:name => 'iteration one', :card_type => @type_iteration)
    iteration_property = 'story tree iteration property'
    story_property = 'story tree property'
    story_tree = setup_tree(@project, 'Story Tree', :types => [@type_iteration, @type_story, @type_task], :relationship_names => [iteration_property, story_property])
    add_card_to_tree(story_tree, iteration_card)
    add_card_to_tree(story_tree, story_card, iteration_card)
    add_card_to_tree(story_tree, task_card, story_card)
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, card_number_and_name(story_card))
    open_card(@project, story_card)
    edit_card(:name => new_name_for_story_card)
    new_display_number_and_name_for_story_card = "##{story_card.number} #{new_name_for_story_card}"
    @browser.run_once_history_generation
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, new_display_number_and_name_for_story_card)
    assert_history_for(:card, task_card.number).version(2).shows(:set_properties => {story_property => new_display_number_and_name_for_story_card})
    assert_card_in_tree(@project, story_tree, story_card)
    assert_card_in_tree(@project, story_tree, task_card)
    open_card(@project, story_card)
    assert_property_set_on_card_show(iteration_property, iteration_card)
    assert_history_for(:card, story_card.number).version(2).shows(:set_properties => {iteration_property => card_number_and_name(iteration_card)})
    assert_card_in_tree(@project, story_tree, story_card)
    assert_card_in_tree(@project, story_tree, task_card)
    assert_card_in_tree(@project, story_tree, iteration_card)
  end

  # bug 3060
  def test_can_change_type_of_card_that_is_also_value_of_relationship_property
    story_card = create_card!(:name => 'going to change type', :card_type => @type_story)
    task_card = create_card!(:name => 'task one', :card_type => @type_task)
    story_property = 'story tree property'
    story_tree = setup_tree(@project, 'Story Tree', :types => [@type_story, @type_task], :relationship_names => [story_property])
    add_card_to_tree(story_tree, story_card)
    add_card_to_tree(story_tree, task_card, story_card)
    open_card(@project, story_card)
    set_card_type_on_card_show(DEFECT)
    assert_history_for(:card, story_card.number).version(2).shows(:changed => TYPE, :from => STORY, :to => DEFECT)
    @browser.run_once_history_generation
    open_card(@project, task_card)
    assert_property_set_on_card_show(story_property, NOT_SET)
    assert_history_for(:card, task_card.number).version(3).shows(:changed => story_property, :from => card_number_and_name(story_card), :to => NOT_SET)
    assert_card_not_in_tree(@project, story_tree, story_card)
    assert_card_in_tree(@project, story_tree, task_card)
  end
  # bug 3278
  def test_value_appearing_in_relationship_property_column_on_card_list_includes_card_number
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [ITERATION_TYPE, STORY], :relationship_names => ["#{PLANNING_TREE} - #{RELEASE}", "relationship-#{ITERATION_TYPE}"])
    card_story = create_card!(:name => "Story 1", :card_type => @type_story)
    card_iteration = create_card!(:name => "Iteration 1", :card_type => @type_iteration)
    add_card_to_tree(tree, card_iteration)
    add_card_to_tree(tree, card_story, card_iteration)

    navigate_to_card_list_for(@project)
    add_column_for(@project, ['planning tree - Release'])
    assert_table_row_data_for('cards', :row_number => 3, :cell_values => ['', '1', 'Story 1', '#2 Iteration 1'])
  end

  def test_mingle_should_prefilter_relationship_for_card_selector_on_transition_popup
    get_tree_built_with_aggregates_and_cards_in_it
    new_transition = create_transition_for(@project, 'new transition',:type => TASK, :set_properties => {'PT story' => USER_INPUT_OPTIONAL})
    open_card(@project, @task_cards[0])
    click_transition_link_on_card(new_transition)

    open_card_selector_for_property_on_transition_popup('PT story')
    assert_filter_set_on_card_selector(1, 'PT release' => "##{@release_cards[0].number} #{@release_cards[0].name}")
    assert_filter_set_on_card_selector(2, 'PT iteration' => "##{@iteration_cards[1].number} #{@iteration_cards[1].name}")
  end

  def test_prefilter_card_selector_when_select_a_card_value_for_relationship_property
    get_tree_built_with_aggregates_and_cards_in_it
    open_card(@project, @task_cards[0])
    open_card_selector_for_property_on_card_show('PT story')
    @browser.wait_for_all_ajax_finished
    assert_filter_set_on_card_selector(1, 'PT release' => "##{@release_cards[0].number} #{@release_cards[0].name}")
    assert_filter_set_on_card_selector(2, 'PT iteration' => "##{@iteration_cards[1].number} #{@iteration_cards[1].name}")
  end

  def test_prefilter_card_selector_when_using_plv
    get_tree_built_with_aggregates_and_cards_in_it
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :properties => ["PT release"])
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :properties => ["PT iteration"])
    @browser.open("/projects/#{@project.identifier}/cards/new?properties[Type]=#{@type_task.name}")
    set_properties_in_card_edit('PT release' => "(current release)")
    set_properties_in_card_edit('PT iteration' => "(current iteration)")

    open_card_selector_for_property_on_card_edit('PT story')
    @browser.wait_for_all_ajax_finished
    assert_filter_set_on_card_selector(1, 'PT release' => "(current release)")
    assert_filter_set_on_card_selector(2, 'PT iteration' => "(current iteration)")
  end

  private
  def get_tree_built_with_aggregates_and_cards_in_it
    @planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story, @type_task],
      :relationship_names => ['PT release', 'PT iteration', 'PT story'])
    @sum_of_size =   aggregate_story_count_for_release = setup_aggregate_property_definition('sum of size', AggregateType::SUM, @size_property, @planning_tree.id, @type_release.id, @type_story)
    @count_of_stories = aggregate_story_count_for_release = setup_aggregate_property_definition('count of stories', AggregateType::COUNT, nil, @planning_tree.id, @type_release.id, @type_story)

    @release_cards = create_cards(@project, 2, :card_type => @type_release)
    @iteration_cards = create_cards(@project, 2, :card_type => @type_iteration)
    @story_1 = create_card!(:name => 'story 1', :card_type => @type_story, SIZE => '2')
    @story_2 = create_card!(:name => 'story 2', :card_type => @type_story, SIZE => '1')
    @story_3 = create_card!(:name => 'story 3', :card_type => @type_story, SIZE => '4')
    @story_4 = create_card!(:name => 'story 4', :card_type => @type_story, SIZE => '2')
    @story_5 = create_card!(:name => 'story 5', :card_type => @type_story, SIZE => '1')

    @task_cards = create_cards(@project, 5, :card_type => @type_task)

    add_card_to_tree(@planning_tree, @release_cards)
    add_card_to_tree(@planning_tree, @iteration_cards, @release_cards[0])
    add_card_to_tree(@planning_tree, [@story_1, @story_2, @story_3, @story_4, @story_5], @iteration_cards[0])
    add_card_to_tree(@planning_tree, @task_cards, @iteration_cards[1])
  end

end
