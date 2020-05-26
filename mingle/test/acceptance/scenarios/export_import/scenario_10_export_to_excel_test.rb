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

# Tags: excel_export
class Scenario10ExportToExcelTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  ITERATION = 'Iteration'
  MODIFIED_ON = 'Modified on (2.3.1)'
  ADDRESS = 'Address'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_10', :users => [users(:project_member)], :admins => [users(:proj_admin)])
    login_as_project_member
  end

  def setup_property_definitions_and_create_cards
    setup_property_definitions ITERATION => [1], :Priority => [], :Role => [], :Status => [], :TType => []
    setup_date_property_definition(MODIFIED_ON)
    setup_text_property_definition(ADDRESS)

    card_1 = create_card!(:number => 1, :name => 'first card', :description => 'this is the first card', :address => '20 abc st, st state 20000')
    card_1.tag_with('another_tag, first_tag')
    card_1.save!
    card_4 = create_card!(:number => 4, :name => 'another card', :description => 'another card is good', ITERATION => 1, MODIFIED_ON => '22 Apr 1976')
  end

  def test_export_with_description_works_with_interactive_filted_in_list_and_grid_view
    expectations={}
    expectations[:expected_without_description] = %{Number,Name,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
4,another card,Card,,1,22 Apr 1976,,,,,member,member,"","",""
1,first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""}

    expectations[:expected_with_description] = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"",""}

    expectations[:expected_with_description_and_tags] = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,this is the first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"","",""}

    expectations[:expected_without_description_different_sorting] = %{Number,Name,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""
4,another card,Card,,1,22 Apr 1976,,,,,member,member,"","",""}

    expectations = expectations.with_indifferent_access

    expected_with_description, expected_without_description, expected_with_description_and_tags, expected_without_description_different_sorting =
        %w(expected_with_description expected_without_description expected_with_description_and_tags expected_without_description_different_sorting).collect do |expectation_key|
          expectations[expectation_key]
        end

    setup_property_definitions_and_create_cards
    navigate_to_card_list_for @project
    add_new_filter
    set_the_filter_property_and_value(1, :property => ITERATION, :value => 1)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description, @browser.get_body_text)

    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description, @browser.get_body_text)

    click_back_link
    switch_to_grid_view
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description_and_tags, @browser.get_body_text)

    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description_different_sorting, @browser.get_body_text)
  end

  def test_export_with_description_works_with_mql_filted_in_list_and_grid_view
    expectations = {}
    expectations[:expected_without_description] = %{Number,Name,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
4,another card,Card,,1,22 Apr 1976,,,,,member,member,"","",""
1,first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""}

    expectations[:expected_without_description_different_sort] = %{Number,Name,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""
4,another card,Card,,1,22 Apr 1976,,,,,member,member,"","",""}

    expectations[:expected_with_description] = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"",""}

    expectations = expectations.with_indifferent_access

    expected_with_description, expected_without_description, expected_without_description_different_sort =
        %w(expected_with_description expected_without_description expected_without_description_different_sort).collect do |expectation_key|
          expectations[expectation_key]
        end

    setup_property_definitions_and_create_cards
    navigate_to_card_list_for @project
    set_mql_filter_for("Iteration = 1")
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description, @browser.get_body_text)
    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description, @browser.get_body_text)

    navigate_to_grid_view_for @project
    set_mql_filter_for("Iteration = 1")
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description, @browser.get_body_text)
    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description_different_sort, @browser.get_body_text)
  end

  def test_can_emit_cards_as_tab_delimited_text
    setup_property_definitions_and_create_cards
    navigate_to_card_list_for @project
    add_column_for(@project, ['modified on (2.3.1)'])
    export_all_columns_to_excel_with_description
    expected = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"","",""
1,first card,this is the first card,Card,\"20 abc st, st state 20000\",,,,,,,member,member,\"another_tag,first_tag\","",""}
    assert_equal_ignore_cr(expected, @browser.get_body_text)
  end

# bug 2506
  def test_form_tags_dont_break_the_excel_export
    setup_property_definitions_and_create_cards
    navigate_to_card_list_for(@project)
    create_card!(:number => 7, :name => "bad card", :description => '<form action="form_action.asp" method=" get"> KFJGHKLSDHGHDSJHG </form>')
    expected = %{<head></head><body>Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
7,bad card,\"<form action=\"\" form_action.asp\"\"=\"\" method=\"\" get\"\"=\"\"> KFJGHKLSDHGHDSJHG </form>\",Card,,,,,,,,member,member,"","",""
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"","",""
1,first card,this is the first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""\n</body>}
    navigate_to_card_list_for(@project)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected, @browser.get_html_source)
  end

  def test_deleted_properties_do_not_appear_in_export
    setup_property_definitions_and_create_cards
    login_as_proj_admin_user
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, ITERATION)
    delete_property_for(@project, ADDRESS)
    delete_property_for(@project, MODIFIED_ON)
    navigate_to_card_list_for @project
    export_all_columns_to_excel_without_description
    assert_no_match(/#{ITERATION}/, @browser.get_body_text)
    assert_no_match(/#{MODIFIED_ON}/, @browser.get_body_text)
    assert_no_match(/#{ADDRESS}/, @browser.get_body_text)
  end

# bug 3480
  def test_angled_brackets_in_card_descriptions_do_not_break_export
    expected = %{Number,Name,Description,Type,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n7,card 7,Something <25K,Card,member,member,\"\",\"\"\n6,card 6,any description,Card,member,member,\"\",\"\"\n5,card 5,Something 25k>,Card,member,member,\"\",\"\"}

    create_card!(:number => 5, :name => "card 5", :description => "Something 25k>")
    create_card!(:number => 6, :name => "card 6", :description => "any description")
    create_card!(:number => 7, :name => "card 7", :description => "Something <25K")

    navigate_to_card_list_for(@project)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected, @browser.get_body_text)
  end

#bug 4788, 5087
  def test_the_state_of_include_description_checkbox_should_be_remembered_in_session_and_be_true
    expectations = {}
    expectations[:expected_without_description] = %{Number,Name,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,Card,,1,22 Apr 1976,,,,,member,member,"",""}

    expectations[:expected_with_description] = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"",""}

    expectations[:expected_with_description_and_extra_rows] = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"","",""
1,first card,this is the first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""}

    expectations = expectations.with_indifferent_access
    expected_with_description, expected_without_description, expected_with_description_and_extra_rows =
        %w(expected_with_description expected_without_description expected_with_description_and_extra_rows).collect do |expectation_key|
          expectations[expectation_key]
        end

    setup_property_definitions_and_create_cards
    navigate_to_card_list_for @project
    add_new_filter
    set_the_filter_property_and_value(1, :property => ITERATION, :value => 1)
    export_all_columns_to_excel_with_description

    navigate_to_card_list_for @project
    add_new_filter
    set_the_filter_property_and_value(1, :property => ITERATION, :value => 1)
    switch_to_grid_view
    assert_include_description_selected
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description, @browser.get_body_text)
    click_back_link
    assert_include_description_selected
    export_all_columns_to_excel_without_description

    navigate_to_card_list_for @project
    add_new_filter
    set_the_filter_property_and_value(1, :property => ITERATION, :value => 1)

    assert_include_description_is_not_selected
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description, @browser.get_body_text)
    click_back_link
    assert_include_description_is_not_selected

    export_all_columns_to_excel_with_description
    click_back_link
    assert_include_description_selected
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description_and_extra_rows, @browser.get_body_text)
  end

  def test_default_export_options_is_only_including_visible_properties_and_dont_include_card_description
    setup_property_definitions_and_create_cards
    navigate_to_card_list_for(@project)
    assert_include_description_is_not_selected
    assert_include_only_visible_columns_selected
  end

  def test_user_can_export_visible_columns_on_list_view
    expected_list_view = %{Number,Name,Address
4,another card,
1,first card,"20 abc st, st state 20000"}
    setup_property_definitions_and_create_cards
    navigate_to_card_list_for(@project)
    add_column_for(@project, ['Address'])
    export_to_excel(:with_description => false, :visible_columns_only => true)
    assert_equal_ignore_cr(expected_list_view, @browser.get_body_text)
  end

  def test_user_can_export_visible_columns_on_hierarchy_view
    expected_hierarchy_view = %{Number,Name,Description
1,release,this is release card
3,story,
2,iteration,}
    type_release = setup_card_type(@project, 'release')
    type_iteration = setup_card_type(@project, 'iteration')
    type_story = setup_card_type(@project, 'story')
    release = create_card!(:name => 'release', :description => 'this is release card', :card_type => 'release')
    iteration = create_card!(:name => 'iteration', :card_type => 'iteration')
    story = create_card!(:name => 'story', :card_type => 'story')
    local_tree = setup_tree(@project, 'local tree', :types => [type_release, type_iteration, type_story], :relationship_names => ['tree release', 'tree iteration'])
    add_cards_to_tree(local_tree, release, iteration, story)
    navigate_to_hierarchy_view_for(@project, local_tree)
    export_to_excel(:with_description => true, :visible_columns_only => true)
    assert_equal_ignore_cr(expected_hierarchy_view, @browser.get_body_text)
  end

  def test_user_can_export_with_descriptions_on_grid_view
    expected_grid_view = %{Number,Name,Description,Type,Address,Iteration,Modified on (2.3.1),Priority,Role,Status,TType,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,this is the first card,Card,"20 abc st, st state 20000",,,,,,,member,member,"another_tag,first_tag","",""
4,another card,another card is good,Card,,1,22 Apr 1976,,,,,member,member,"","",""}
    setup_property_definitions_and_create_cards
    navigate_to_grid_view_for(@project)
    export_to_excel(:with_description => true)
    assert_equal_ignore_cr(expected_grid_view, @browser.get_body_text)
  end

  def test_user_can_export_without_descriptions_on_tree_view
    expected_tree_view = %{Number,Name,Type,local tree,tree release,tree iteration,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1,release,release,yes,,,member,member,"",""
2,iteration,iteration,yes,#1 release,,member,member,"",""
3,story,story,yes,#1 release,,member,member,"",""}
    type_release = setup_card_type(@project, 'release')
    type_iteration = setup_card_type(@project, 'iteration')
    type_story = setup_card_type(@project, 'story')
    release = create_card!(:name => 'release', :description => 'this is release card', :card_type => 'release')
    iteration = create_card!(:name => 'iteration', :card_type => 'iteration')
    story = create_card!(:name => 'story', :card_type => 'story')
    local_tree = setup_tree(@project, 'local tree', :types => [type_release, type_iteration, type_story], :relationship_names => ['tree release', 'tree iteration'])
    add_cards_to_tree(local_tree, release, iteration, story)
    navigate_to_tree_view_for(@project, local_tree.name)
    export_to_excel(:with_description => false)
    assert_equal_ignore_cr(expected_tree_view, @browser.get_body_text)
  end

  def test_user_can_export_filtered_cards_in_hierarchy_view
    expected_filtered_hierarchy = %{Number,Name,Description
1,release,this is release card
2,iteration 1,
4,story 1,}
    type_release = setup_card_type(@project, 'release')
    type_iteration = setup_card_type(@project, 'iteration')
    type_story = setup_card_type(@project, 'story')
    release = create_card!(:name => 'release', :description => 'this is release card', :card_type => 'release')
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => 'iteration')
    iteration_2 = create_card!(:name => 'iteration 2', :card_type => 'iteration')
    story_1 = create_card!(:name => 'story 1', :card_type => 'story')
    story_2 = create_card!(:name => 'story 2', :card_type => 'story')
    local_tree = setup_tree(@project, 'local tree', :types => [type_release, type_iteration, type_story], :relationship_names => ['tree release', 'tree iteration'])

    add_card_to_tree(local_tree, release)
    add_card_to_tree(local_tree, [iteration_1, iteration_2], release)
    add_card_to_tree(local_tree, story_1, iteration_1)
    add_card_to_tree(local_tree, story_2, iteration_2)
    navigate_to_hierarchy_view_for(@project, local_tree)
    set_tree_filter_for(type_iteration, 0, :property => 'tree iteration', :value => iteration_1.number)
    export_to_excel(:visible_columns_only => true, :with_description => true)
    assert_equal_ignore_cr(expected_filtered_hierarchy, @browser.get_body_text)
  end

#bug 10569
  def test_should_be_able_to_do_export_in_a_favorite
    expected = %{Number,Name
1,card1}
    create_card!(:name => "card1")
    navigate_to_card_list_for @project
    create_card_list_view_for(@project, 'favorite one')
    open_saved_view("favorite one")
    export_to_excel(:visible_columns_only => true, :with_description => false)
    assert_equal_ignore_cr(expected, @browser.get_body_text)
  end

  def test_when_limit_enabled_and_filter_is_present_that_reduces_cards_below_limit_export_link_is_enabled
    with_card_export_limit_of(2) do
      create_card!(:name => "first")
      create_card!(:name => "second")
      create_card!(:name => "third")
      navigate_to_card_list_for @project
      click_twisty_for_export_import
      @browser.assert_has_classname('show_export_options_link', 'disabled')
      set_mql_filter_for("number < 3")
      @browser.assert_does_not_have_classname('show_export_options_link', 'disabled')
    end
  end

  def test_when_limit_enabled_export_link_is_disabled_when_too_many_cards_in_view
    with_card_export_limit_of(2) do
      create_card!(:name => "first")
      create_card!(:name => "second")
      create_card!(:name => "third")
      navigate_to_card_list_for @project
      click_twisty_for_export_import
      @browser.assert_has_classname('show_export_options_link', 'disabled')
    end
  end

  def test_when_limit_enabled_export_link_is_enabled_when_acceptable_number_in_view
    with_card_export_limit_of(20) do
      create_card!(:name => "first")
      create_card!(:name => "second")
      create_card!(:name => "third")
      navigate_to_card_list_for @project
      click_twisty_for_export_import
      @browser.assert_does_not_have_classname('show_export_options_link', 'disabled')
    end
  end

  private

  def with_card_export_limit_of(number, &block)
    scriptlet = "CardViewLimits::MAX_CARDS_TO_EXPORT=#{number}"
    @browser.open(%[/_eval?scriptlet=#{CGI.escape(scriptlet)}])
    yield
  end
end
