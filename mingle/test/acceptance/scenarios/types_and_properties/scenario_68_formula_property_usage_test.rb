# -*- coding: utf-8 -*-

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

# Tags: scenario, properties, formula
class Scenario68FormulaPropertyUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STORY = 'Story'

  SIZE = 'Size'
  SIZE_TIMES_TWO = 'size time two'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_68', :admins => [@project_admin], :users => [@admin, @project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_numeric_property_definition(SIZE, [2, 4])
    login_as_proj_admin_user
  end

  # bug 7998
  def test_should_be_able_to_edit_a_hidden_property_used_as_component_of_formula
    type_story = setup_card_type(@project, STORY, :properties => [SIZE])
    type_card = @project.card_types.find_by_name("Card")
    edit_property_definition_for(@project,SIZE,:card_types_to_uncheck => ["Card"])
    hide_property(@project, SIZE)

    formula = create_property_definition_for(@project,"double size",:type => "formula",:formula => "#{SIZE} * 2",:types => [STORY])
    tree = setup_tree(@project, 'planning tree', :types => [type_card, type_story], :relationship_names => ["planning tree - card"])
    setup_aggregate_property_definition('sum of double size', AggregateType::SUM, formula, tree.id, type_card.id, type_story)
    edit_property_definition_for(@project,SIZE,:card_types_to_check => ["Card"])
    assert_notice_message('Property was successfully updated.')
  end

  # bug 7608
  def test_bulk_updating_date_property_when_used_as_formula_component
    date_1 = setup_date_property_definition("ended_on")
    date_2 = setup_date_property_definition("started_on")
    card = create_card!(:name => 'card for bulk editing', "ended_on" =>  "24 September 2009", "started_on" => "22 September 2009")
    formula = setup_formula_property_definition("duration", "#{SIZE} * 2")
    navigate_to_card_list_for(@project)
    select_all
    open_bulk_edit_properties
    set_bulk_properties(@project, "ended_on" => "(not set)")
    set_bulk_properties(@project, "started_on" => "(not set)")
    assert_notice_message "1 card updated."
  end

  # bug 8633
  def test_using_dates_in_formulas
    date_1 = setup_date_property_definition("ended_on")
    date_2 = setup_date_property_definition("started_on")
    card = create_card!(:name => 'card for bulk editing', "ended_on" =>  "24 September 2009", "started_on" => "22 September 2009")
    formula = setup_formula_property_definition("duration", "ended_on - (started_on - 5)")

    open_card(@project, card.number)
    set_property_value_on_card_show(@project, "started_on", "24 Sep 2009")
    set_property_value_on_card_show(@project, "ended_on", "21 Sep 2009")

    assert_properties_set_on_card_show(formula.name => "2")
  end

  def test_setting_value_of_operand_property_on_card_updates_formula_property_also
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, SIZE, 8)
    assert_properties_set_on_card_show(SIZE_TIMES_TWO => '16')
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE => '8'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE_TIMES_TWO => '16'})
  end

  def test_formula_properties_are_read_only_in_bulk_edit_panel
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_property_present_in_bulk_edit_panel(SIZE_TIMES_TWO)
    assert_property_not_editable_in_bulk_edit_properties_panel(@project, SIZE_TIMES_TWO)
  end

  def test_bulk_updating_operand_property_value_updates_formula_property_value
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, SIZE => 4)
    assert_properties_set_in_bulk_edit_panel(@project, SIZE_TIMES_TWO => '8')
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE => '4'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE_TIMES_TWO => '8'})
  end

  # bug 3057
  def test_creating_formula_property_does_not_create_empty_history_version_on_existing_card_where_operand_property_is_not_set
    card = create_card!(:name => 'for testing')
    create_property_definition_for(@project, SIZE_TIMES_TWO, :type => 'formula', :formula => 'Size * 2')
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, SIZE => 4)
    assert_properties_set_in_bulk_edit_panel(@project, SIZE_TIMES_TWO => '8')
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE => '4', SIZE_TIMES_TWO => '8'})
    assert_history_for(:card, card.number).version(3).not_present
  end

  def test_can_add_column_for_formula_property_and_create_saved_view
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing', SIZE => 1)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [SIZE_TIMES_TWO])
    formula_property_view = 'formula property view'
    create_card_list_view_for(@project, formula_property_view)
    open_favorites_for(@project, formula_property_view)
    assert_column_present_for(SIZE_TIMES_TWO)
  end

  def test_formula_properties_do_not_appear_in_history_filters
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    navigate_to_history_for(@project)
    assert_property_not_present_in_first_filter_widget(SIZE_TIMES_TWO)
    assert_property_not_present_in_second_filter_widget(SIZE_TIMES_TWO)
  end

  def test_cannot_group_by_or_color_by_on_card_grid_view
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    navigate_to_grid_view_for(@project)
    assert_property_not_present_in_group_columns_by(SIZE_TIMES_TWO)
    assert_property_not_present_in_color_by(SIZE_TIMES_TWO)
  end

  def test_cannot_set_value_for_existing_formula_property_via_excel_import
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    navigate_to_card_list_for(@project)
    header_row = ['number', "#{SIZE_TIMES_TWO}"]
    imported_card_number = 15
    attempted_formula_property_value = '279'
    card_data = [[imported_card_number, attempted_formula_property_value]]
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message_matches("Cannot set value for formula property: #{SIZE_TIMES_TWO}") #bug 2989
    assert_ignore_selected_for_property_column(SIZE_TIMES_TWO)
    assert_ignore_only_available_mapping_for_property_column(SIZE_TIMES_TWO)
    import_from_preview
    @browser.run_once_history_generation
    open_card(@project, imported_card_number)
    assert_property_not_set_on_card_show(SIZE_TIMES_TWO)
    assert_history_for(:card, imported_card_number).version(1).does_not_show(:set_properties => {SIZE_TIMES_TWO => attempted_formula_property_value})
  end

  def test_changing_formula_generates_system_comment_in_history_when_formula_property_is_set_on_card
    size_formula_property_name = 'size formula'
    size_times_two_formula = "#{SIZE} * 2"
    size_minus_two_formula = "#{SIZE} - 2"
    create_property_definition_for(@project, size_formula_property_name, :type => "formula", :formula => size_times_two_formula)
    card = create_card!(:name => 'testing history comment', SIZE => 4)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {SIZE => '4'})
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {size_formula_property_name => '8'})
    open_property_for_edit(@project, size_formula_property_name)
    type_formula(size_minus_two_formula)
    click_save_property
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:changed => size_formula_property_name, :from => '8', :to => '2')
    assert_history_for(:card, card.number).version(2).shows(:formula_changed => size_formula_property_name, :from => size_times_two_formula, :to => size_minus_two_formula)
  end

  # bug 2831
  def test_formula_properties_appear_on_edit_card_defaults_page_but_are_not_editable
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    setup_card_type(@project, STORY, :properties => [SIZE, SIZE_TIMES_TWO])
    open_edit_defaults_page_for(@project, STORY)
    assert_property_present_on_card_defaults(SIZE)
    assert_property_present_on_card_defaults(SIZE_TIMES_TWO)
    assert_property_not_editable_on_card_defaults(@project, SIZE_TIMES_TWO)
  end

  # bug 2830
  def test_formula_properties_do_not_appear_in_card_list_filters
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    card = create_card!(:name => 'for testing')
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, 'Card')
    add_new_filter
    assert_filter_property_not_present_on(1, :properties => [SIZE_TIMES_TWO])
  end

  # bug 2834
  def test_hidden_formula_properties_appear_in_history_events
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    hide_property(@project, SIZE_TIMES_TWO)
    card = create_card!(:name => 'has hidden property')
    open_card(@project, card.number)
    set_properties_on_card_show(SIZE => 4)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE => '4'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE_TIMES_TWO => '8'})
  end

  # bug 3000
  def test_formula_properties_do_not_appear_in_transition_requires_properties_or_sets_properties_during_transition_creation
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_requires_property_not_present(SIZE_TIMES_TWO)
    assert_sets_property_not_present(SIZE_TIMES_TWO)
  end

  # bug 3000
  def test_formula_properties_do_not_appear_in_transition_requires_properties_or_sets_properties_during_transition_creation
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    existing_transition = create_transition_for(@project, 'existing transition', :set_properties => {STATUS => NEW})
    open_transition_for_edit(@project, existing_transition)
    assert_requires_property_not_present(SIZE_TIMES_TWO)
    assert_sets_property_not_present(SIZE_TIMES_TWO)
  end

  # bug 2969
  def test_formula_property_value_not_updated_on_card_when_new_property_operand_is_set_to_not_set
    points = 'points'
    original_formual_using_size = "#{SIZE} * 2"
    new_formula_using_points = "#{points} * 2"
    setup_numeric_property_definition(points, [100])
    setup_formula_property_definition(SIZE_TIMES_TWO, original_formual_using_size)
    card_with_points_not_set = create_card!(:name => 'initial card', SIZE => 2)
    card_with_points_set_to_100 = create_card!(:name => 'initial card', SIZE => 2, points => 100)

    @browser.run_once_history_generation
    open_card(@project, card_with_points_not_set.number)
    assert_properties_set_on_card_show(SIZE_TIMES_TWO => '4')
    assert_history_for(:card, card_with_points_not_set.number).version(1).shows(:set_properties => {SIZE => '2'})
    assert_history_for(:card, card_with_points_not_set.number).version(1).shows(:set_properties => {SIZE_TIMES_TWO => '4'})

    edit_property_definition_for(@project, SIZE_TIMES_TWO, :new_formula => new_formula_using_points)
    @browser.run_once_history_generation

    open_card(@project, card_with_points_not_set.number)
    assert_properties_set_on_card_show(SIZE_TIMES_TWO => NOT_SET)
    assert_history_for(:card, card_with_points_not_set.number).version(1).shows(:set_properties => {SIZE => '2'})
    assert_history_for(:card, card_with_points_not_set.number).version(1).shows(:set_properties => {SIZE_TIMES_TWO => '4'})
    assert_history_for(:card, card_with_points_not_set.number).version(2).shows(:changed => SIZE_TIMES_TWO, :from => '4', :to => NOT_SET)
    assert_history_for(:card, card_with_points_not_set.number).version(2).shows(:formula_changed => SIZE_TIMES_TWO, :from => original_formual_using_size, :to => new_formula_using_points)
    open_card(@project, card_with_points_set_to_100.number)
    assert_properties_set_on_card_show(SIZE_TIMES_TWO => '200')
    assert_history_for(:card, card_with_points_set_to_100.number).version(1).shows(:set_properties => {SIZE => '2'})
    assert_history_for(:card, card_with_points_set_to_100.number).version(1).shows(:set_properties => {points => '100'})
    assert_history_for(:card, card_with_points_set_to_100.number).version(2).shows(:changed => SIZE_TIMES_TWO, :from => '4', :to => '200')
    assert_history_for(:card, card_with_points_set_to_100.number).version(2).shows(:formula_changed => SIZE_TIMES_TWO, :from => original_formual_using_size, :to => new_formula_using_points)
    assert_history_for(:card, card_with_points_not_set.number).version(3).not_present
  end

  # bug 3016
  def test_changing_formula_then_using_save_and_another_causes_empty_history_version
    formula_property_with_changing_formula = 'size stuff'
    original_formula = "#{SIZE} * 2"
    new_formula = "#{SIZE} - 2"
    setup_formula_property_definition(formula_property_with_changing_formula, original_formula)
    card = create_card!(:name => 'for testing', SIZE => 4)
    edit_property_definition_for(@project, formula_property_with_changing_formula, :new_formula => new_formula)
    @browser.run_once_history_generation
    open_card_for_edit(@project, card)
    click_save_and_add_another_link
    open_card(@project, card)
    assert_history_for(:card, card.number).version(2).shows(:changed => formula_property_with_changing_formula, :from => '8', :to => '2')
    assert_history_for(:card, card.number).version(2).shows(:formula_changed => formula_property_with_changing_formula, :from => original_formula, :to => new_formula)
    assert_history_for(:card, card.number).version(3).not_present
  end

  # bug 3058
  def test_changing_formula_property_from_date_to_number_displays_full_date_in_card_history
    date_property_name = 'end date'
    old_formula_using_date_property =  "'#{date_property_name}' + 2"
    new_formula = "#{SIZE} +2"
    formula_property_name = 'formula'
    may_sixteen = '16 May 2008'
    result_of_new_formula = 4
    create_property_definition_for(@project, date_property_name, :type => 'date')
    setup_formula_property_definition(formula_property_name, old_formula_using_date_property)
    card = create_card!(:name => 'card for testing')
    open_card(@project,card.number)
    add_new_value_to_property_on_card_show(@project, SIZE, 2)
    add_new_value_to_property_on_card_show(@project, date_property_name, '14 May 2008')
    assert_properties_set_on_card_show(formula_property_name => may_sixteen)
    open_property_for_edit(@project, formula_property_name)
    type_formula(new_formula)
    click_save_property
    @browser.run_once_history_generation
    open_card(@project,card.number)
    assert_properties_set_on_card_show(formula_property_name => '4')
    load_card_history
    assert_history_for(:card, card.number).version(4).shows(:changed => formula_property_name, :from => may_sixteen, :to => result_of_new_formula)
    assert_history_for(:card, card.number).version(4).shows(:formula_changed => formula_property_name, :from => old_formula_using_date_property, :to => new_formula)
    assert_history_for(:card, card.number).version(4).does_not_show(:changed => formula_property_name, :from => '2008', :to => result_of_new_formula)
    assert_history_for(:card, card.number).version(5).not_present
  end


  # bug #8179 #8204 #6863
  def test_bulk_editing_date_component_when_adding_substracting_decimal_to_from_a_date_explicitly_in_formula
    expectations = [
      {:formula => 'started_on + 2.1', :started_on => '24 Sep 2009', :expected_formula_value => '26 Sep 2009'},
      {:formula => 'started_on + 2.8', :started_on => '24 Sep 2009', :expected_formula_value => '27 Sep 2009'},
      {:formula => '2.1 + started_on', :started_on => '24 Sep 2009', :expected_formula_value => '26 Sep 2009'},
      {:formula => '2.8 + started_on', :started_on => '24 Sep 2009', :expected_formula_value => '27 Sep 2009'},
      {:formula => 'started_on - 2.1', :started_on => '24 Sep 2009', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'started_on - 2.8', :started_on => '24 Sep 2009', :expected_formula_value => '21 Sep 2009'}
    ]

    date = setup_date_property_definition("started_on")

    expectations.each do |expectation|
      formula = setup_formula_property_definition("formula", expectation[:formula])
      card = create_card!(:name => 'card for bulk editing', "started_on" =>  expectation[:started_on])
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => expectation[:expected_formula_value])
      navigate_to_card_list_for(@project)
      select_all
      open_bulk_edit_properties
      set_bulk_properties(@project, "started_on" => "(not set)")
      assert_notice_message "1 card updated."
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => "(not set)")
      navigate_to_property_management_page_for(@project)
      assert_property_present_on_property_management_page(formula.name)
      delete_property_for(@project, formula.name)
      delete_card(@project, card.name)
    end
  end

  def test_updating_date_component_on_card_show_when_adding_substracting_decimal_to_from_a_date_explicitly_in_formula
    expectations = [
      {:formula => 'started_on + 2.1', :started_on => '24 Sep 2009', :expected_formula_value => '26 Sep 2009'},
      {:formula => 'started_on + 2.8', :started_on => '24 Sep 2009', :expected_formula_value => '27 Sep 2009'},
      {:formula => '2.1 + started_on', :started_on => '24 Sep 2009', :expected_formula_value => '26 Sep 2009'},
      {:formula => '2.8 + started_on', :started_on => '24 Sep 2009', :expected_formula_value => '27 Sep 2009'},
      {:formula => 'started_on - 2.1', :started_on => '24 Sep 2009', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'started_on - 2.8', :started_on => '24 Sep 2009', :expected_formula_value => '21 Sep 2009'}
    ]

    date = setup_date_property_definition("started_on")

    expectations.each do |expectation|
      formula = setup_formula_property_definition("formula", expectation[:formula])
      card = create_card!(:name => 'card for bulk editing', "started_on" =>  expectation[:started_on])
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => expectation[:expected_formula_value])
      open_card(@project, card.number)
      set_properties_on_card_show("started_on" => "(not set)")
      assert_properties_set_on_card_show(formula.name => "(not set)")
      navigate_to_property_management_page_for(@project)
      assert_property_present_on_property_management_page(formula.name)
      delete_property_for(@project, formula.name)
      delete_card(@project, card.name)
    end
  end

  def test_bulk_editing_date_component_when_adding_substracting_a_numeric_property_with_a_decimal_value_to_from_a_date
    expectations = [
      {:formula => 'started_on + estimate', :started_on => '24 Sep 2009', :estimate =>  '2.1', :expected_formula_value => '26 Sep 2009'},
      {:formula => 'estimate + started_on', :started_on => '24 Sep 2009', :estimate =>  '2.1', :expected_formula_value => '26 Sep 2009'},
      {:formula => 'started_on - estimate', :started_on => '24 Sep 2009', :estimate =>  '2.1', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'started_on + estimate', :started_on => '24 Sep 2009', :estimate =>  '2.8', :expected_formula_value => '27 Sep 2009'},
      {:formula => 'estimate + started_on', :started_on => '24 Sep 2009', :estimate =>  '2.8', :expected_formula_value => '27 Sep 2009'},
      {:formula => 'started_on - estimate', :started_on => '24 Sep 2009', :estimate =>  '2.8', :expected_formula_value => '21 Sep 2009'},
      {:formula => 'started_on + estimate', :started_on => '24 Sep 2009', :estimate => '-2.1', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'estimate + started_on', :started_on => '24 Sep 2009', :estimate => '-2.1', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'started_on - estimate', :started_on => '24 Sep 2009', :estimate => '-2.1', :expected_formula_value => '26 Sep 2009'},
      {:formula => 'started_on + estimate', :started_on => '24 Sep 2009', :estimate => '-2.8', :expected_formula_value => '21 Sep 2009'},
      {:formula => 'estimate + started_on', :started_on => '24 Sep 2009', :estimate => '-2.8', :expected_formula_value => '21 Sep 2009'},
      {:formula => 'started_on - estimate', :started_on => '24 Sep 2009', :estimate => '-2.8', :expected_formula_value => '27 Sep 2009'}
    ]

    estimate = setup_numeric_property_definition('estimate', [2.1, 2.8, -2.1, -2.8])
    date = setup_date_property_definition("started_on")

    expectations.each do |expectation|
      formula = setup_formula_property_definition("formula", expectation[:formula])
      card = create_card!(:name => 'card for bulk editing', "started_on" =>  expectation[:started_on], "estimate" => expectation[:estimate])
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => expectation[:expected_formula_value])
      navigate_to_card_list_for(@project)
      select_all
      open_bulk_edit_properties
      set_bulk_properties(@project, "started_on" => "(not set)")
      assert_notice_message "1 card updated."
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => "(not set)")
      navigate_to_property_management_page_for(@project)
      assert_property_present_on_property_management_page(formula.name)
      delete_property_for(@project, formula.name)
      delete_card(@project, card.name)
    end
  end

  def test_updating_date_component_on_card_show_when_adding_substracting_a_numeric_property_with_a_decimal_value_to_from_a_date
    expectations = [
      # {:formula => 'started_on + (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate =>  '6.4', :expected_formula_value => '26 Sep 2009'},
      {:formula => '(estimate / 3.0) + started_on', :started_on => '24 Sep 2009', :estimate =>  '6.4', :expected_formula_value => '26 Sep 2009'},
      # {:formula => 'started_on - (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate =>  '6.4', :expected_formula_value => '22 Sep 2009'},
      {:formula => 'started_on + (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate =>  '8.5', :expected_formula_value => '27 Sep 2009'},
      # {:formula => '(estimate / 3.0) + started_on', :started_on => '24 Sep 2009', :estimate =>  '8.5', :expected_formula_value => '27 Sep 2009'},
      # {:formula => 'started_on - (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate =>  '8.5', :expected_formula_value => '21 Sep 2009'},
      # {:formula => 'started_on + (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate => '-6.4', :expected_formula_value => '22 Sep 2009'},
      {:formula => '(estimate / 3.0) + started_on', :started_on => '24 Sep 2009', :estimate => '-6.4', :expected_formula_value => '22 Sep 2009'},
      # {:formula => 'started_on - (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate => '-6.4', :expected_formula_value => '26 Sep 2009'},
      # {:formula => 'started_on + (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate => '-8.5', :expected_formula_value => '21 Sep 2009'},
      # {:formula => '(estimate / 3.0) + started_on', :started_on => '24 Sep 2009', :estimate => '-8.5', :expected_formula_value => '21 Sep 2009'},
      {:formula => 'started_on - (estimate / 3.0)', :started_on => '24 Sep 2009', :estimate => '-8.5', :expected_formula_value => '27 Sep 2009'}
    ]

    estimate = setup_numeric_property_definition('estimate', [2.1, 2.8, -2.1, -2.8])
    date = setup_date_property_definition("started_on")

    expectations.each do |expectation|
      formula = setup_formula_property_definition("formula", expectation[:formula])
      card = create_card!(:name => 'card for bulk editing', "started_on" =>  expectation[:started_on], "estimate" => expectation[:estimate])
      open_card(@project, card.number)
      assert_properties_set_on_card_show(formula.name => expectation[:expected_formula_value])
      open_card(@project, card.number)
      set_properties_on_card_show("started_on" => "(not set)")
      assert_properties_set_on_card_show(formula.name => "(not set)")
      navigate_to_property_management_page_for(@project)
      assert_property_present_on_property_management_page(formula.name)
      delete_property_for(@project, formula.name)
      delete_card(@project, card.name)
    end
  end

  #bug #8630 [Formula] Subtracting an expression from a numeric property can result in a 500 error
  def test_sbustraction_in_formula_should_work
    setup_numeric_property_definition('NUM', [30])
    setup_formula_property_definition('substraction', "#{SIZE} - (NUM * 10)")
    card = create_card!(:name => 'for substraction')
    open_card(@project, card.number)
    set_properties_on_card_show("#{SIZE}" => 2)
    set_properties_on_card_show("NUM" => 30)
    open_card(@project, card.number)
  end

  def test_formula_parsing_with_special_characters
    velocity = setup_numeric_property_definition('vélocité', [30])
    size = setup_numeric_property_definition('size', [15])
    formula1 = setup_formula_property_definition('formula1', "vélocité * 2")
    formula2 = setup_formula_property_definition('formula2', "size * 2")
    card = create_card!(:name => 'formula card')
    open_card(@project, card.number)
    set_properties_on_card_show('vélocité' => 30)
    assert_properties_set_on_card_show(formula1.name => "60")
    edit_property_definition_for(@project, size.name , :new_property_name => 'sizé')
    open_property_for_edit(@project, formula2.name)
    assert_formula_for_formula_property("'sizé' * 2")
  end
end
