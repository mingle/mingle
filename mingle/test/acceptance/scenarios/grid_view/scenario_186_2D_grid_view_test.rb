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

# Tags: gridview
class Scenario1862DGridViewTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  RELEASE = "Release"
  SPRINT = "Sprint"
  STORY = "Story"
  TASK = "Task"
  DEFECT = "Defect"

  #Task properties:
  TASK_STATUS = "Task Status"
  OWNER = "Owner"
  DEPEND_ON = "Depend on"
  DATE_TASK_COMPLETED = "Date Task Completed"
  HOURS_REMAINING = "Hours Remaining"
  SHARED_PROPERTY = "Shared Property"

  #Card names
  RELEASE_1 = "release_1"
  SPRINT_1 = "Sprint_1"
  SPRINT_2 = "Sprint_2"
  STORY_1 = "Story_1"
  STORY_2 = "Story_2"
  TASK_1 = "Task_1"
  TASK_2 = "Task_2"
  TASK_3 = "Task_3"

  RELEASE_2 = "release_2"
  SPRINT_3 = "Sprint_3"
  SPRINT_4 = "Sprint_4"
  STORY_3 = "Story_3"
  STORY_4 = "Story_4"
  TASK_4 = "Task_4"
  TASK_5 = "Task_5"
  TASK_6 = "Task_6"

  #PROPERTY VALUES
  NEW = "New"
  IN_PROGRESS = "In progress"
  DONE = "Done"
  NOTSET = "(not set)"

  MINGLE="Mingle"
  GO="Go"
  TWIST="Twist"

  #Default properties
  TYPE = "Type"

  #Others
  USER_INPUT_OPTIONAL = '(user input - optional)'
  USER_INPUT_REQUIRED = '(user input - required)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @team_member = users(:project_member)
    @another_team_member = users(:bob)
    @read_only_user = users(:read_only_user)
    @project = create_project(:prefix => 'scenario_186', :users => [@team_member, @another_team_member], :admins => [@project_admin_user], :read_only_users => [@read_only_user])
    login_as_proj_admin_user
  end

  def test_card_should_be_present_in_the_right_cell
    setup_card_types_and_properties_and_trees
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    add_new_filter
    set_the_filter_property_option(1, SPRINT)
    add_new_filter
    set_the_filter_property_and_value(2, :property => TASK_STATUS, :operator => 'is less than', :value => DONE)
    group_columns_by(TASK_STATUS)
    #use relationship property as row property
    group_rows_by(STORY)
    change_lane_heading('Sum', HOURS_REMAINING)
    assert_card_in_lane_and_row(@task_2, NEW, @story_1.id)
    assert_card_in_lane_and_row(@task_3, IN_PROGRESS, @story_2.id)
    assert_grid_rows_ordered(@story_1.name, @story_2.name)
    assert_group_row_number(1)                      #story 10646 - aggregates on rows
    assert_group_row_number(1, :lane_number => 1)
  end

  def test_select_type_as_row_property
    setup_card_types_and_properties_and_trees
    navigate_to_grid_view_for(@project)
    group_columns_by(SHARED_PROPERTY)
    group_rows_by(TYPE)
    #use Type as row property
    assert_card_in_lane_and_row(@release_1, MINGLE, RELEASE)
    assert_card_in_lane_and_row(@sprint_1, MINGLE, SPRINT)
    assert_card_in_lane_and_row(@story_1, GO, STORY)
    assert_card_in_lane_and_row(@story_2, GO, STORY)
    assert_card_in_lane_and_row(@task_1, TWIST, TASK)
    assert_card_in_lane_and_row(@task_2, TWIST, TASK)
    assert_card_in_lane_and_row(@task_3, TWIST, TASK)
    assert_grid_rows_ordered(RELEASE, SPRINT,STORY, TASK)
  end

  def test_quick_added_card_should_go_to_correct_cell
    setup_property_definitions(TASK_STATUS => ['New','In progress','Done'])
    create_managed_number_list_property(HOURS_REMAINING, ['0', '0.5', '1', '2', '3','4','5','6','7','8'])
    setup_card_type(@project, TASK, :properties => [TASK_STATUS, HOURS_REMAINING])
    @task_1 = create_card!(:name => TASK_1, :card_type => TASK, TASK_STATUS => DONE)
    @task_2 = create_card!(:name => TASK_2, :card_type => TASK, TASK_STATUS => NEW, HOURS_REMAINING => "5")
    @task_3 = create_card!(:name => TASK_3, :card_type => TASK, TASK_STATUS => IN_PROGRESS, HOURS_REMAINING => "8")

    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_columns_by(TASK_STATUS)
    group_rows_by(HOURS_REMAINING)
    assert_group_row_number(1, :lane=>[HOURS_REMAINING, :not_set]) #story 10646 - aggregates on rows
    assert_group_row_number(1, :lane=>[HOURS_REMAINING, 5])
    assert_group_row_number(1, :lane=>[HOURS_REMAINING, 8])


    add_card_via_quick_add("the first test", :type => TASK)

    new_card = @project.reload.cards.find_by_name("the first test")
    assert_card_in_lane_and_row(new_card, '', '')
    favorite = create_card_list_view_for(@project, 'save the 2d grid view')
    reset_all_filters_return_to_all_tab
    open_saved_view('save the 2d grid view')
    assert_card_in_lane_and_row(new_card, '', '')
    assert_card_in_lane_and_row(@task_2, NEW, '5')
    assert_card_in_lane_and_row(@task_3, IN_PROGRESS, '8')
    assert_card_in_lane_and_row(@task_1, DONE, '' )
    assert_grid_rows_ordered(NOTSET, '5', '8')

    assert_group_row_number(2, :lane=>[HOURS_REMAINING, :not_set]) #story 10646 - aggregates on rows
    assert_group_row_number(1, :lane=>[HOURS_REMAINING, 5])
    assert_group_row_number(1, :lane=>[HOURS_REMAINING, 8])

  end

  def test_permission_for_2d_view
    setup_card_types_and_properties_and_trees
    register_license_that_allows_anonymous_users
    login_as_proj_admin_user
    open_project_admin_for(@project)
    enable_project_anonymous_accessible_on_project_admin_page
    logout
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_columns_by(SHARED_PROPERTY)
    #use mananged text property as row property
    group_rows_by(TASK_STATUS)
    assert_card_in_lane_and_row(@task_2, TWIST, NEW)
    assert_card_in_lane_and_row(@task_3, TWIST, IN_PROGRESS)
    assert_card_in_lane_and_row(@task_1, TWIST, DONE)
    assert_grid_rows_ordered(NEW, IN_PROGRESS, DONE)

    login_as_read_only_user
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    #use user property as row property
    group_columns_by(TASK_STATUS)
    group_rows_by(OWNER)
    assert_card_in_lane_and_row(@task_3, IN_PROGRESS, @team_member.id)
    assert_card_in_lane_and_row(@task_2, NEW, @project_admin_user.id)
    assert_card_in_lane_and_row(@task_1, DONE, @another_team_member.id)
    assert_grid_rows_ordered(@another_team_member.name, @team_member.name, @project_admin_user.name)
  end

  def test_executing_transition_should_take_card_to_the_right_cell
    setup_card_types_and_properties_and_trees
    create_transtions
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    #use user property as row property
    group_columns_by(TASK_STATUS)
    group_rows_by(OWNER)
    assert_card_in_lane_and_row(@task_3, IN_PROGRESS, @team_member.id)
    assert_card_in_lane_and_row(@task_2, NEW, @project_admin_user.id)
    assert_card_in_lane_and_row(@task_1, DONE, @another_team_member.id)
    click_on_transition_for_card_in_grid_view(@task_2, @task_transition)
    assert_card_in_lane_and_row(@task_2, DONE, @team_member.id)
  end

  def test_drag_and_drop_cards_cross_columns_on_2d_grid_view_with_a_transtion_that_will_change_row_and_column_properties_at_same_time
    setup_card_types_and_properties_and_trees
    @project.find_property_definition(TASK_STATUS).update_attribute(:transition_only, true)
    transition_1 = create_transition_for(@project, 'task transition',:type => TASK, :set_properties => {TASK_STATUS => DONE, OWNER  => @team_member.name})
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_columns_by(TASK_STATUS)
    group_rows_by(OWNER)
    assert_card_in_lane_and_row(@task_3, IN_PROGRESS, @team_member.id)
    assert_card_in_lane_and_row(@task_2, NEW, @project_admin_user.id)
    assert_card_in_lane_and_row(@task_1, DONE, @another_team_member.id)
    sleep 1
    drag_and_drop_card_to_cell(@task_2, DONE, @project_admin_user.id)
    @browser.assert_text_present("#{transition_1.name} successfully applied to card ##{@task_2.number}")
    #the card should be in another row because the transtion also changed the row property
    assert_card_in_lane_and_row(@task_2, DONE, @team_member.id)
    open_card(@project, @task_2)
    assert_property_set_on_card_show(TASK_STATUS, DONE)
    assert_property_set_on_card_show(OWNER, "member@ema...")
  end


  # TODO: maybe move this to controller test
  def test_user_permission_for_executing_a_transition_on_2d_grid_view
    setup_properties
    setup_card_types
    setup_cards
    @project.find_property_definition(TASK_STATUS).update_attribute(:transition_only, true)
    ba_group = create_a_group_for_project(@project, 'BA')
    qa_group = create_a_group_for_project(@project, 'QA')
    dev_group = create_a_group_for_project(@project, 'DEV')
    add_user_to_group(@project, [@project_admin_user], [qa_group])
    add_user_to_group(@project, [@team_member], [ba_group])
    transition_for_QAs = create_transition_for(@project, 'transition for BAs', :type => TASK, :set_properties => {TASK_STATUS => DONE}, :for_groups => [ba_group])
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_columns_by(TASK_STATUS)
    group_rows_by(SHARED_PROPERTY)
    assert_card_in_lane_and_row(@task_2, NEW, TWIST)
    drag_and_drop_card_to_cell(@task_2, DONE, TWIST)
    @browser.assert_text_present("Sorry, you cannot drag this card to lane #{DONE}. Please ensure there is a transition to allow this action and this card satisfies the requirements.")
  end

  def test_do_not_allow_user_to_select_same_property_as_rows_and_columns
    setup_properties
    setup_card_types
    setup_cards
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_rows_by(TASK_STATUS)
    assert_properties_not_present_on_group_columns_by_drop_down_list(TASK_STATUS)
    group_columns_by(SHARED_PROPERTY)
    assert_properties_not_present_on_group_rows_by_drop_down_list(SHARED_PROPERTY)
    ungroup_by_row_in_grid_view
    assert_properties_not_present_on_group_rows_by_drop_down_list(SHARED_PROPERTY)
    assert_properties_present_on_group_columns_by_drop_down_list(TASK_STATUS)
    ungroup_by_columns_in_grid_view
    assert_properties_present_on_group_columns_by_drop_down_list(TASK_STATUS, SHARED_PROPERTY)
    assert_properties_present_on_group_rows_by_drop_down_list(TASK_STATUS, SHARED_PROPERTY)
  end

  # [mingle1/#12886]
  # TODO: make it clear that when the last card disappears, the row aggregate shows the correct count
  def test_moving_all_cards_out_of_the_available_lanes_does_not_show_up_stale_data
    setup_properties
    setup_card_types
    setup_cards
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_rows_by(SHARED_PROPERTY)
    group_columns_by(TASK_STATUS)
    add_new_filter
    set_the_filter_property_and_value(1, :property => TASK_STATUS, :value => IN_PROGRESS)
    add_lanes(@project, TASK_STATUS, ['New','In progress','Done'])
    drag_and_drop_card_to_cell(@task_3, DONE, TWIST)
    assert_info_message("card ##{@task_3.number} property was updated, but is not shown because it does not match the current filter.", :escape => true)
    assert_group_row_number(0, :lane => [SHARED_PROPERTY, TWIST])
  end

  def test_add_row_and_hide_row
    setup_properties
    setup_card_types
    create_card!(:name => 'first card', :card_type => TASK, TASK_STATUS => IN_PROGRESS)

    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_rows_by(TASK_STATUS)

    add_rows([DONE])
    @browser.scroll_to_top
    create_new_row("To Do")

    assert_group_row_number(1, :lane=>[TASK_STATUS, IN_PROGRESS])
    assert_group_row_number(0, :lane=>[TASK_STATUS, DONE])
    assert_group_row_number(0, :lane=>[TASK_STATUS, "To Do"])

    create_card_list_view_for(@project, "board")
    open_saved_view("board")

    assert_group_row_number(1, :lane=>[TASK_STATUS, IN_PROGRESS])
    assert_group_row_number(0, :lane=>[TASK_STATUS, DONE])
    assert_group_row_number(0, :lane=>[TASK_STATUS, "To Do"])

    hide_grid_dimension(DONE, "row")
    assert_row_not_present(DONE)

    update_favorites_for(1)
    open_saved_view("board")
    assert_row_not_present(DONE)
  end

  # [mingle1/#12477]
  def test_can_rank_cards_in_the_same_row_when_row_property_is_transition_only
    setup_properties
    setup_card_types
    status = @project.find_property_definition(TASK_STATUS)
    status.update_attribute(:transition_only, true)
    transtion_for_setup_task_status_to_done = create_transition_for(@project, 'task transition',:type => TASK, :set_properties => {TASK_STATUS => DONE})

    create_card!(:name => 'task one', :card_type => TASK)
    create_card!(:name => 'task two', :card_type => TASK, TASK_STATUS => IN_PROGRESS)
    card_3 = create_card!(:name => 'task three', :card_type => TASK, TASK_STATUS => NEW)
    card_4 = create_card!(:name => 'task four', :card_type => TASK, TASK_STATUS => NEW)
    card_5 = create_card!(:name => 'task five', :card_type => TASK, TASK_STATUS => DONE)

    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_rows_by(TASK_STATUS)

    drag_and_drop_card_to(card_3, card_4)
    assert_ordered('card_4','card_3')
  end

  # TODO: move to controller [mingle1/#12509]
  def test_user_properties_row_headers_should_be_ordered_by_display_name
    setup_properties
    setup_card_types
    create_card!(:name => 'story one', :card_type => TASK, OWNER => @team_member.id)
    create_card!(:name => 'story one', :card_type => TASK, OWNER => @another_team_member.id)
    create_card!(:name => 'story one', :card_type => TASK)

    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_rows_by(OWNER)
    assert_grid_rows_ordered(NOTSET, @another_team_member.name, @team_member.name)
  end

  # [mingle1/#12554]
  def test_drag_and_drop_card_across_columns_when_group_columns_by_relationship_property_and_rows_by_other_properties
    setup_card_types_and_properties_and_trees
    release_2 = create_card!(:name => RELEASE_2, :card_type => RELEASE, SHARED_PROPERTY => MINGLE)
    sprint_3 = create_card!(:name => SPRINT_3, :card_type => SPRINT, SHARED_PROPERTY => MINGLE)
    story_3 = create_card!(:name => STORY_3, :card_type => STORY, SHARED_PROPERTY => GO)
    story_4 = create_card!(:name => STORY_4, :card_type => STORY, SHARED_PROPERTY => GO)
    task_4 = create_card!(:name => TASK_4, :card_type => TASK, TASK_STATUS => DONE, OWNER => @another_team_member.id, DATE_TASK_COMPLETED => "Aug 15, 2011", SHARED_PROPERTY => TWIST)
    task_5 = create_card!(:name => TASK_5, :card_type => TASK, TASK_STATUS => NEW, OWNER => @project_admin_user.id, DEPEND_ON => @task_1, HOURS_REMAINING => "5", SHARED_PROPERTY => TWIST)
    task_6 = create_card!(:name => TASK_6, :card_type => TASK, TASK_STATUS => IN_PROGRESS, OWNER => @team_member.id, DEPEND_ON => @task_1, HOURS_REMAINING => "8", SHARED_PROPERTY => TWIST)

    add_card_to_tree(@schedule_tree, release_2)
    add_card_to_tree(@schedule_tree, sprint_3, release_2)
    add_card_to_tree(@schedule_tree, story_3, sprint_3)
    add_card_to_tree(@schedule_tree, story_4, sprint_3)
    add_card_to_tree(@schedule_tree, task_4, story_3)
    add_card_to_tree(@schedule_tree, task_5, story_4)

    navigate_to_grid_view_for(@project)
    select_is_not(0)
    set_the_filter_value_option(0, RELEASE)
    select_tree(@schedule_tree.name)
    click_exclude_card_type_checkbox(RELEASE)
    group_columns_by(RELEASE)
    group_rows_by(TYPE)

    assert_card_in_lane_and_row(sprint_3, release_2.id, SPRINT)
    assert_card_in_lane_and_row(story_3, release_2.id, STORY)
    assert_card_in_lane_and_row(story_4, release_2.id, STORY)
    assert_card_in_lane_and_row(task_4, release_2.id, TASK)
    assert_card_in_lane_and_row(task_5, release_2.id, TASK)

    assert_group_row_number(2, :lane=> [TYPE,SPRINT])
    assert_group_row_number(4, :lane=> [TYPE,STORY])
    assert_group_row_number(5, :lane=> [TYPE,TASK])
    assert_group_lane_number(6)
    assert_group_lane_number(5, :lane_index  => 1)

    drag_and_drop_card_to_cell(sprint_3, @release_1.id, SPRINT)
    assert_card_in_lane_and_row(sprint_3, @release_1.id, SPRINT)
    assert_card_in_lane_and_row(story_3, @release_1.id, STORY)
    assert_card_in_lane_and_row(story_4, @release_1.id, STORY)
    assert_card_in_lane_and_row(task_4, @release_1.id, TASK)
    assert_card_in_lane_and_row(task_5, @release_1.id, TASK)
    assert_group_lane_number(11)
  end

private
  def setup_properties
    @task_status = setup_property_definitions(TASK_STATUS => ['New','In progress','Done'])
    @owner = create_team_property(OWNER)
    @depend_on = 	create_card_type_property(DEPEND_ON)
    @date_task_completed = create_date_property(DATE_TASK_COMPLETED)
    @hours_remaining =  create_managed_number_list_property(HOURS_REMAINING, ['0', '0.5', '1', '2', '3','4','5','6','7','8'])
    @shared_proeprty = setup_property_definitions(SHARED_PROPERTY => ["Mingle", "Go", "Twist"])
  end

  def setup_card_types
    @type_release = setup_card_type(@project, RELEASE, :properties => [SHARED_PROPERTY])
    @type_sprint = setup_card_type(@project, SPRINT, :properties => [SHARED_PROPERTY])
    @type_story = setup_card_type(@project, STORY, :properties => [SHARED_PROPERTY])
    @type_task = setup_card_type(@project, TASK, :properties => [TASK_STATUS, OWNER, DEPEND_ON, DATE_TASK_COMPLETED, HOURS_REMAINING, SHARED_PROPERTY])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [SHARED_PROPERTY])
  end

  def setup_cards
    @release_1 = create_card!(:name => RELEASE_1, :card_type => RELEASE, SHARED_PROPERTY => MINGLE)
    @sprint_1 = create_card!(:name => SPRINT_1, :card_type => SPRINT, SHARED_PROPERTY => MINGLE)
    @story_1 = create_card!(:name => STORY_1, :card_type => STORY, SHARED_PROPERTY => GO)
    @story_2 = create_card!(:name => STORY_2, :card_type => STORY, SHARED_PROPERTY => GO)
    @task_1 = create_card!(:name => TASK_1, :card_type => TASK, TASK_STATUS => DONE, OWNER => @another_team_member.id, DATE_TASK_COMPLETED => "Aug 15, 2011", SHARED_PROPERTY => TWIST)
    @task_2 = create_card!(:name => TASK_2, :card_type => TASK, TASK_STATUS => NEW, OWNER => @project_admin_user.id, DEPEND_ON => @task_1, HOURS_REMAINING => "5", SHARED_PROPERTY => TWIST)
    @task_3 = create_card!(:name => TASK_3, :card_type => TASK, TASK_STATUS => IN_PROGRESS, OWNER => @team_member.id, DEPEND_ON => @task_1, HOURS_REMAINING => "8", SHARED_PROPERTY => TWIST)
  end

  def setup_scrum_tree
    @schedule_tree = setup_tree(@project, "schedule", :types => [@type_release, @type_sprint, @type_story, @type_task, @type_defect], :relationship_names => [RELEASE, SPRINT, STORY, TASK])
    add_card_to_tree(@schedule_tree, @release_1)
    add_card_to_tree(@schedule_tree, @sprint_1, @release_1)
    add_card_to_tree(@schedule_tree, @story_1, @sprint_1)
    add_card_to_tree(@schedule_tree, @story_2, @sprint_1)
    add_card_to_tree(@schedule_tree, @task_1, @story_1)
    add_card_to_tree(@schedule_tree, @task_2, @story_1)
    add_card_to_tree(@schedule_tree, @task_3, @story_2)
    ##################################################################################################
    #                                                Schedule tree
    #                                                    |
    #                                                Release_1
    #                                                   |
    #                                      -----------Sprint_1----
    #                                     |                      |
    #                                ---Story1---             Story2
    #                                |          |               |
    #                               Task1     Task2            Task3
    # ################################################################################################
  end

  def setup_card_types_and_properties_and_trees
    setup_properties
    setup_card_types
    setup_cards
    setup_scrum_tree
  end

  def create_transtions
    @task_transition = create_transition_for(@project, 'task transition',:type => TASK, :set_properties => {TASK_STATUS => DONE, OWNER  => @team_member.name})
  end

end
