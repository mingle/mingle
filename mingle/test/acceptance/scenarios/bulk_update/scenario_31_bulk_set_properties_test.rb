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

# Tags: scenario, bug, properties, bulk
class Scenario31BulkSetPropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  TAG = 'foo'
  BULK_SET_PANEL_ID = 'bulk-set-properties-panel'

  MIXED_VALUE = '(mixed value)'
  NOT_SET = '(not set)'
  CURRENT_USER = '(current user)'

  STATUS = 'status'
  NEW = 'new'
  STATUS_NEW = {STATUS => NEW}
  STATUS_IN_PROGRESS = {STATUS => 'in progress'}
  STATUS_NOT_SET = {STATUS => '(not set)'}
  STATUS_MIXED_VALUE = {STATUS => '(mixed value)'}
  PRIORITY = 'priority'
  HIGH = 'HIGH'
  PRIORITY_HIGH = {PRIORITY => HIGH}
  PRIORITY_MED_TO_HIGH = {PRIORITY => 'med to high'}
  PRIORITY_NOT_SET = {PRIORITY => '(not set)'}
  PRIORITY_MIXED_VALUE = {PRIORITY => MIXED_VALUE}

  STORY = 'story'
  CARD = 'Card'
  CARD_NAME = 'card_name'
  OPEN = 'open'
  IN_PROGRESS = 'in progress'
  MED_TO_HIGH = 'med to high'
  OWNER = 'owner'
  SIZE = 'size'

  FORMULA_TYPE= 'formula'
  DATE_TYPE= 'date'

  ITERATION = 'iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_team_member = users(:admin)
    @project = create_project(:prefix => 'scenario_31', :users => [@project_team_member])
    setup_property_definitions(STATUS => [NEW, OPEN, IN_PROGRESS], PRIORITY => [HIGH, MED_TO_HIGH])
    login_as_admin_user
  end

  def test_edit_properties_link_disabled_when_bulk_update_limit_is_exceeded
    2.times { |i| create_card!(:name => "new card #{i + 1}", :card_type => CARD) }
    with_bulk_update_limit_of(1) do
      navigate_to_card_list_for(@project)
      select_all
      assert_equal "tab-disabled", @browser.get_attribute("id=#{ListViewPageId::BULK_SET_PROPERTIES_BUTTON}@class")
    end
  end

  def test_tooltip_for_property_on_bulk_edit_panel
    create_property_definition_for(@project, SIZE, :type => 'number list', :description => "This property indicates size of every card.")
    card = create_card!(:name => "morning sf")

    navigate_to_card_list_for(@project)
    select_all
    open_bulk_edit_properties
    assert_property_tooltip_on_bulk_edit_panel(SIZE)
  end

  def test_search_value_for_managed_text_managed_number_and_user_type_property_when_bulk_edit_cards
    @card = create_card!(:name => 'new card', :card_type => CARD)
    create_property_definition_for(@project, OWNER, :type => 'user')
    project_team_member_name = @project_team_member.name
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])

    navigate_to_card_list_for(@project)
    select_all
    open_bulk_edit_properties

    # search value for managed text property
    click_property_on_bulk_edit_panel(PRIORITY)
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(PRIORITY,'HELLO')
    assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(PRIORITY, [NOT_SET,HIGH,MED_TO_HIGH])
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(PRIORITY,'I')
    assert_value_present_in_property_drop_down_on_bulk_edit_panel(PRIORITY,[HIGH,MED_TO_HIGH])
    assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(PRIORITY,[NOT_SET])
    select_value_in_drop_down_for_property_on_bulk_edit_panel(PRIORITY, HIGH)
    assert_property_set_in_bulk_edit_panel(@project,PRIORITY,HIGH) # Need to decide whether to refactor this method or not

    # search value for user type property
    click_property_on_bulk_edit_panel(OWNER)
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(OWNER, "HELLO")
    assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(OWNER, [NOT_SET,CURRENT_USER,project_team_member_name])
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(OWNER, "")
    assert_value_present_in_property_drop_down_on_bulk_edit_panel(OWNER, [NOT_SET])
    select_value_in_drop_down_for_property_on_bulk_edit_panel(OWNER, NOT_SET)
    assert_property_set_in_bulk_edit_panel(@project, OWNER, NOT_SET)

    # search value for managed number property
    click_property_on_bulk_edit_panel(SIZE)
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(SIZE,'HELLO')
    assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(SIZE, [NOT_SET,1,2,3,4])
    type_keyword_to_search_value_for_property_on_bulk_edit_panel(SIZE,'1')
    assert_value_present_in_property_drop_down_on_bulk_edit_panel(SIZE,[1])
    assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(SIZE,[NOT_SET,2,3,4])
    select_value_in_drop_down_for_property_on_bulk_edit_panel(SIZE, 1)
    assert_property_set_in_bulk_edit_panel(@project,SIZE,'1')
  end

  #bug 5257
  def test_cards_gone_when_they_do_not_match_current_filter_but_should_not_left_bulk_edit_widget_behind
    type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, STATUS])
    create_cards(@project, 10, :card_type => type_story)
    new_card = create_card!(:name => 'new card', :card_type => STORY, :PRIORITY => HIGH, :STATUS => NEW)
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => NEW)
    assert_card_present_in_list(new_card)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => OPEN)
    assert_no_cards_matching_filter
    assert_bulk_set_properties_panel_not_present
  end

  def test_can_set_user_properties_using_bulk_edit
    user_property_name = "Tester's"
    card = create_card!(:name => 'bug one')
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, user_property_name => @project_team_member.name)
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {user_property_name => @project_team_member.name})
    assert_history_for(:card, card.number).version(3).not_present
  end

  def test_can_set_free_text_properties_using_bulk_edit
    free_text_property_name = 'resolution'
    value_for_free_text_property = 'fast and furious fix'
    card = create_card!(:name => 'testing free text')
    create_property_definition_for(@project, free_text_property_name, :type => 'any text')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button

    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(free_text_property_name, value_for_free_text_property)
    assert_property_set_in_bulk_edit_panel(@project, free_text_property_name, value_for_free_text_property)
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {free_text_property_name => value_for_free_text_property})
    assert_history_for(:card, card.number).version(3).not_present
  end

  def test_escape_html_in_error_message_when_using_bulk_to_create_property_value_that_looks_like_plv
    fake_now(1982, 03, 04)
    freetext_property = setup_allow_any_text_property_definition('<h1>freetext</h1>')
    managed_property = setup_managed_text_definition('<h1>managed</h1>', ['one', 'two'])

    card = create_card!(:name => 'testing free text')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(freetext_property, '(looks_like_plv)')
    assert_error_message(/&lt;h1&gt;freetext&lt;\/h1&gt;: <(b|B)>\(looks_like_plv\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_new_value_to_property_on_bulk_edit(@project, managed_property, '(also_looks_like_plv)')
    assert_error_message(/&lt;h1&gt;managed&lt;\/h1&gt;: <(b|B)>\(also_looks_like_plv\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
    ensure
      @browser.reset_fake
  end
  def test_can_set_date_properties_using_bulk_edit
    date_property_name = 'Fixed on'
    valid_date_value = '10 Apr 1976'
    card = create_card!(:name => 'testing set date property in bulk edit')
    create_property_definition_for(@project, date_property_name, :type => 'date')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_value_to_date_property_using_inline_editor_on_bulk_edit(date_property_name, valid_date_value)
    assert_property_set_in_bulk_edit_panel(@project, date_property_name, valid_date_value)
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {date_property_name => valid_date_value})
    assert_history_for(:card, card.number).version(3).not_present
  end

  def test_only_global_properties_appear_in_bulk_panel_when_filter_is_type_is_any
    story = 'story'
    bug = 'bug'
    setup_card_type(@project, story, :properties => [STATUS, PRIORITY])
    setup_card_type(@project, bug, :properties => [PRIORITY])
    story_card = create_card!(:name => 'story one', :card_type => story)
    bug_card = create_card!(:name => 'bug one', :card_type => bug, PRIORITY => HIGH)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => '(any)')
    select_all
    click_edit_properties_button
    assert_type_in_bulk_panel_set_to(MIXED_VALUE)
    assert_property_not_present_in_bulk_edit_panel(STATUS)
    assert_property_present_in_bulk_edit_panel(PRIORITY)
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY => MIXED_VALUE)
  end

  def test_hidden_properties_do_not_appear_in_bulk_edit_panel
    hidden_property = 'hidden One'
    enum_value_for_hidden = %w(foobar)
    setup_property_definitions(hidden_property => enum_value_for_hidden)
    card_with_hidden_property = create_card!(:name => 'for testing', hidden_property => enum_value_for_hidden)
    hide_property(@project, hidden_property)
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_property_not_present_in_bulk_edit_panel(hidden_property)
  end

  def test_changing_types_in_bulk_edit_properties_changes_which_properties_are_available_for_bulk_edit
    story = 'story'
    bug = 'bug'
    setup_card_type(@project, story, :properties => [STATUS, PRIORITY])
    setup_card_type(@project, bug, :properties => [PRIORITY])
    originally_story_card = create_card!(:name => 'card one', :card_type => story)
    originally_bug_card = create_card!(:name => 'card two', :card_type => bug, PRIORITY => HIGH)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => '(any)')
    select_all
    click_edit_properties_button
    set_card_type_on_bulk_edit(story)
    assert_property_present_in_bulk_edit_panel(STATUS)
    assert_property_present_in_bulk_edit_panel(PRIORITY)
    set_card_type_on_bulk_edit(bug)
    assert_property_not_present_in_bulk_edit_panel(STATUS)
    assert_property_present_in_bulk_edit_panel(PRIORITY)

    # bug 2303
    open_card(@project, originally_bug_card.number)
    assert_history_for(:card, originally_bug_card.number).version(2).shows(:changed => 'Type', :from => bug, :to => story)
    assert_history_for(:card, originally_bug_card.number).version(3).shows(:changed => 'Type', :from => story, :to => bug)
    open_card(@project, originally_story_card.number)
    assert_history_for(:card, originally_story_card.number).version(2).shows(:changed => 'Type', :from => story, :to => bug)
    assert_history_for(:card, originally_story_card.number).version(3).not_present
  end

  # bug 2144
  def test_setting_properties_where_other_properties_are_mixed_value_does_not_set_value_as_mixed_value
    task = 'task'
    user_property_name = 'Opened on'
    date_property_name = 'Owned by'
    free_text_property_name = 'Resolution'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    create_property_definition_for(@project, date_property_name, :type => 'date')
    create_property_definition_for(@project, free_text_property_name, :type => 'any text')
    setup_card_type(@project, task, :properties => [PRIORITY, STATUS, user_property_name, date_property_name, free_text_property_name])
    @project.reload.activate

    card_with_no_properties = create_card!(:name => 'starts with no properties', :card_type => task)
    card_with_properties = create_card!(:name => 'has properties set', STATUS => NEW, user_property_name => @project_team_member.id,
      free_text_property_name => 'testing', date_property_name => '05 Aug 1942', :card_type => 'Card')

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, PRIORITY => HIGH)
    assert_type_in_bulk_panel_set_to(MIXED_VALUE)
    assert_properties_set_in_bulk_edit_panel(@project, STATUS => MIXED_VALUE, user_property_name => MIXED_VALUE, PRIORITY => HIGH)
    assert_property_set_in_bulk_edit_panel(@project, date_property_name, MIXED_VALUE)
    assert_property_set_in_bulk_edit_panel(@project, free_text_property_name, MIXED_VALUE)
    open_card(@project, card_with_no_properties.number)
    assert_card_type_set_on_card_show(task)
    assert_properties_not_set_on_card_show(STATUS, user_property_name)
    assert_properties_not_set_on_card_show(date_property_name, free_text_property_name)
  end

  def test_no_tags_appear_in_bulk_property_editor
    cards = create_cards(@project, 3, :tag => TAG)
    navigate_to_card_list_for(@project)
    select_all
    cards.each{|card| assert_card_checked(card)}
    click_edit_properties_button
    @browser.assert_element_does_not_match(BULK_SET_PANEL_ID, /#{TAG}/)
    select_none
    cards.each{|card| assert_card_not_checked(card)}
  end

  def test_deleted_properties_do_not_appear_in_bulk_property_editor
    create_cards(@project, 5)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, 'status')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    @browser.assert_element_does_not_match('bulk-set-properties-panel', /status/)
  end

  def test_enabling_and_disabling_bulk_set_properties_button_and_displaying_hiding_bulk_set_properties_panel
    cards = create_cards(@project, 3)
    navigate_to_card_list_for(@project)
    select_all
    assert_bulk_set_properties_button_enabled
    click_edit_properties_button
    assert_bulk_set_properties_panel_visible
    select_none
    assert_bulk_set_properties_button_disabled
    assert_bulk_set_properties_panel_not_visible
    check_cards_in_list_view(cards[1])
    assert_bulk_set_properties_button_enabled
    uncheck_cards_in_list_view(cards[1])
    assert_bulk_set_properties_button_disabled
  end

  def test_bulk_set_properties_applies_properties_to_all_selected
    properties = STATUS_IN_PROGRESS.merge(PRIORITY_HIGH)
    cards = create_cards(@project, 2)
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_properties_set_in_bulk_edit_panel(@project, STATUS_NOT_SET.merge(PRIORITY_NOT_SET))
    set_bulk_properties(@project, PRIORITY_HIGH)
    set_bulk_properties(@project, STATUS_IN_PROGRESS)
    assert_properties_set_in_bulk_edit_panel(@project, properties)
    cards.each do |card|
      open_card(@project, card.number)
      assert_history_for(:card, card.number).version(2).shows(:set_properties => PRIORITY_HIGH)
      assert_history_for(:card, card.number).version(3).shows(:set_properties => STATUS_IN_PROGRESS)
    end
  end

  def test_bulk_set_properties_removes_selected_properties_from_all_selected_cards
    properties = STATUS_NEW
    cards = create_cards(@project, 2)
    cards.each {|card| card.update_attributes(to_attrs(properties))}
    navigate_to_card_list_for(@project)
    @browser.click "checkbox_1" # card_number_1
    click_edit_properties_button
    assert_properties_set_in_bulk_edit_panel(@project, properties)
    set_bulk_properties(@project, STATUS => nil)
    assert_properties_not_in_set_properties_panel(properties)
    @browser.with_ajax_wait do
      select_all
    end
    assert_properties_set_in_bulk_edit_panel(@project, STATUS_MIXED_VALUE)
    card_number_1 = cards[0]
    open_card(@project, card_number_1.number)
    assert_history_for(:card, card_number_1.number).version(3).shows(:unset_properties => STATUS_NEW)
  end

  def test_can_bulk_set_properties_immediately_after_bulk_tag
    properties = STATUS_IN_PROGRESS.merge(PRIORITY_MED_TO_HIGH)
    create_cards(@project, 3)
    navigate_to_card_list_for(@project)
    select_all
    bulk_tag(TAG)
    assert_value_present_in_tagging_panel("All tagged:.*#{TAG}")
    click_edit_properties_button
    @browser.assert_element_present(BULK_SET_PANEL_ID)
    set_bulk_properties(@project, properties)
    assert_properties_set_in_bulk_edit_panel(@project,  properties)
  end

  # bug 1159, 1163
  def test_bulk_set_properties_maintains_page_and_does_not_break_pagination
    cards = create_cards(@project, 52)
    cards.each {|card| card.update_attributes(to_attrs(STATUS_NEW))}
    navigate_to_card_list_for(@project)
    click_page_link(3)
    assert_on_page(@project, '3')
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => nil)
    assert_properties_not_in_set_properties_panel(STATUS_NEW)
    assert_on_page(@project, '3')
    @browser.click_and_wait('link=Previous')
    assert_not_on_page('3')
    @browser.click("checkbox_0")
    click_edit_properties_button
    assert_properties_set_in_bulk_edit_panel(@project, STATUS_NEW)
    @browser.click_and_wait('link=Next')
    assert_not_on_page('2')
    assert_not_on_page('1')
    # bug 1159
    click_page_link(1)
    assert_on_page(@project, '1', 'All', '')
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, PRIORITY_HIGH)
    @browser.click_and_wait('link=Next')
    assert_not_on_page('1')
  end

  # bug 1164
  def test_properties_with_apostrophes_do_not_break_bulk_edit_properties
    @project.activate
    setup_property_definitions(:"'wow'" => ['really'])
    create_cards(@project, 3)
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_bulk_set_properties_panel_visible
    set_bulk_properties(@project, :"'wow'" => 'really')
    assert_properties_set_in_bulk_edit_panel(@project, :"'wow'" => 'really')
  end

  def test_other_ajax_operations_on_card_list_do_not_break_bulk_edit_properties
    cards = create_cards(@project, 3)
    cards.each {|card| card.update_attributes(to_attrs(PRIORITY_MED_TO_HIGH))}
    navigate_to_card_list_for(@project)

    assert_filtering_card_list_does_not_break_bulk_edit_properties # bug1229
    assert_resetting_filters_does_not_break_bulk_edit_properties #bug1229
    assert_creating_saved_view_does_not_break_bulk_edit_properties
    assert_quick_adding_card_does_not_break_bulk_edit_properties
    assert_switching_between_list_and_grid_views_does_not_break_bulk_edit_properties
  end

  #7254
  def test_set_date_propety_value_to_today_on_bulk_edit_cause_mingle_throw_500
    fake_now(1982, 03, 04)
    setup_date_property_definitions('start on', 'end on')
    setup_formula_property_definition('formula1', "'end on' - 'start on'")
    card = create_card!(:name => 'I am card')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button

    set_bulk_properties(@project, :"start on" => '(today)')
    assert_properties_set_in_bulk_edit_panel(@project, :"start on" => '04 Mar 1982')
  ensure
    @browser.reset_fake
  end

  # bug 7938
  def test_can_bulk_update_numeric_property_to_a_plv_if_property_is_used_in_a_formula
    pd_numnum = setup_allow_any_number_property_definition('numnum')
    setup_formula_property_definition('formula', "numnum * 3")
    create_number_plv(@project, 'num_plv', '3', [pd_numnum])

    card = create_card!(:name => 'I am card')
    navigate_to_card_list_for(@project)
    select_all

    click_edit_properties_button
    set_bulk_properties(@project, :numnum => "(num_plv)")
    assert_properties_set_in_bulk_edit_panel(@project, :numnum => '3', :formula => '9')
  end

  # bug 8261
  def test_should_update_card_property_value_via_bulk_edit_when_selected_cards_have_mixed_values
    type_story = setup_card_type(@project, STORY)
    type_iteration = setup_card_type(@project, 'iteration')
    type_release = setup_card_type(@project, 'release')

    tree_one = create_and_configure_new_card_tree(@project, :name => "planning_1", :types => ['release', "iteration", STORY], :relationship_names => ["iteration", "release"])
    quick_add_cards_on_tree(@project, tree_one, :root, :card_names => ['r1'], :card_type => type_release, :reset_filter => 'no')
    r1 = @project.cards.find_by_name('r1')
    quick_add_cards_on_tree(@project, tree_one, r1, :card_names => ['i1'], :card_type => type_iteration, :reset_filter => 'no')
    i1 = @project.cards.find_by_name('i1')
    quick_add_cards_on_tree(@project, tree_one, i1, :card_names => ['s1'], :card_type => type_story, :reset_filter => 'no')

    quick_add_cards_on_tree(@project, tree_one, :root, :card_names => ['r2'], :card_type => type_release, :reset_filter => 'no')
    r2 = @project.cards.find_by_name('r2')
    quick_add_cards_on_tree(@project, tree_one, r2, :card_names => ['i2'], :card_type => type_iteration, :reset_filter => 'no')
    i2 = @project.cards.find_by_name('i2')
    quick_add_cards_on_tree(@project, tree_one, i2, :card_names => ['s2'], :card_type => type_story, :reset_filter => 'no')

    navigate_to_card_list_for(@project)

    filter_card_list_by(@project, :type => 'story')
    select_all
    click_edit_properties_button

    set_bulk_properties(@project, "release" => i2)
    assert_notice_message('2 cards updated.')
  end

  def test_cancel_bulk_change_card_type
    iteration_type = setup_card_type(@project, ITERATION)
    card_1 = create_card!(:name => CARD_NAME, :card_type => CARD)
    card_2 = create_card!(:name => CARD_NAME, :card_type => CARD)
    iteration_1 = create_card!(:name => CARD_NAME, :card_type => ITERATION)

    navigate_to_card_list_for(@project)
    select_cards([card_1,card_2])
    click_edit_properties_button
    select_card_type_on_bulk_edit(ITERATION)
    click_cancle_bulk_edit_card_type
    assert_type_in_bulk_panel_set_to(CARD)

    select_cards([iteration_1])
    select_card_type_on_bulk_edit(ITERATION)
    click_cancle_bulk_edit_card_type
    assert_type_in_bulk_panel_set_to("(mixed value)")
  end

  def test_bulk_change_card_type_on_card_list_view_should_get_warning_message
    iteration_type = setup_card_type(@project, ITERATION)
    card_1 = create_card!(:name => CARD_NAME, :card_type => CARD)
    card_2 = create_card!(:name => CARD_NAME, :card_type => CARD)

    navigate_to_card_list_for(@project)
    select_cards([card_1])
    click_edit_properties_button
    select_card_type_on_bulk_edit(ITERATION)
    assert_change_type_confirmation_for_single_card_present
    click_cancle_bulk_edit_card_type

    select_cards([card_2])
    select_card_type_on_bulk_edit(ITERATION)
    assert_change_type_confirmation_for_multiple_cards_present
  end

  # bug 1229
  def assert_filtering_card_list_does_not_break_bulk_edit_properties
    open_card(@project, 2)
    navigate_to_card_list_for(@project)
    @browser.click("checkbox_1") # card number 2
    click_edit_properties_button
    set_bulk_properties(@project, STATUS_IN_PROGRESS)
    @browser.with_ajax_wait do
      select_all
    end
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_MIXED_VALUE))
    filter_card_list_by_property(@project, 'status', IN_PROGRESS, 1)
    select_all
    click_edit_properties_button
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_IN_PROGRESS))
    set_bulk_properties(@project, STATUS => nil)
    reset_view
    select_all
    click_edit_properties_button
    assert_properties_not_in_set_properties_panel(STATUS_IN_PROGRESS)
  end

  # bug 1229
  def assert_resetting_filters_does_not_break_bulk_edit_properties
    reset_view_if_needed
    select_all
    # open_bulk_edit_properties
    click_edit_properties_button
    set_bulk_properties(@project, STATUS_IN_PROGRESS)
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_IN_PROGRESS))
    filter_card_list_by_property(@project, 'priority', MED_TO_HIGH, 1)

    reset_view
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => nil)
    assert_properties_not_in_set_properties_panel(STATUS_IN_PROGRESS)

    filter_card_list_by_property(@project, 'priority', MED_TO_HIGH, 1)
    reset_view
    @browser.click "checkbox_1"
    click_edit_properties_button
    set_bulk_properties(@project, STATUS_NEW)
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_NEW))

    reset_all_filters_return_to_all_tab
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => nil)
    assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_NOT_SET))
   end

   def assert_creating_saved_view_does_not_break_bulk_edit_properties
     create_card_list_view_for(@project, "testing view")
     reset_view_if_needed
     select_all
     click_edit_properties_button
     set_bulk_properties(@project, STATUS_IN_PROGRESS)
     assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_IN_PROGRESS))
     set_bulk_properties(@project, STATUS => nil)
     assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_NOT_SET))
   end

   def assert_quick_adding_card_does_not_break_bulk_edit_properties
     add_new_card("newest story")
     @browser.click "checkbox_1"
     click_edit_properties_button
     assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_NOT_SET))
     set_bulk_properties(@project, STATUS_IN_PROGRESS)
     assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MED_TO_HIGH.merge(STATUS_IN_PROGRESS))
   end

   def assert_switching_between_list_and_grid_views_does_not_break_bulk_edit_properties
     switch_to_grid_view
     switch_to_list_view
     select_all
     click_edit_properties_button
     set_bulk_properties(@project, STATUS => nil)
     assert_properties_set_in_bulk_edit_panel(@project, PRIORITY_MIXED_VALUE.merge(STATUS_NOT_SET))
   end

   def to_attrs(properties)
    attrs = {}
    properties.each do |key, value|
      attrs["cp_#{key}"] = value
    end
    attrs
   end

  def with_bulk_update_limit_of(number, &block)
    @browser.open("/_class_method_call?class=ConstantResetter&method=set_constant&name=CardViewLimits::MAX_CARDS_TO_BULK_UPDATE&value=#{number}")
    sleep 10
    block.call
  ensure
    @browser.open("/_class_method_call?class=ConstantResetter&method=reset_constant&name=CardViewLimits::MAX_CARDS_TO_BULK_UPDATE")
  end

end
