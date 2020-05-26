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

# Tags: mql, macro, value_query
class Scenario92MqlValueQueryTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  CARD = 'Card'
  STATUS = 'status'
  SIZE = 'size'
  SIZE_TIMES_TWO = 'size_times_two'
  DUE_DATE = 'due_date'
  VALUE = 'value'
  TEXT ='http://localhost:3000/projects/testing/cards/grid?color_by=Type&filters%5B%5D=%5BType%5D%5Bis%5D%5BStory%5D&filters%5B%5D=%5BIteration%5D%5Bis%5D%5B%28Current+Iteration%29%5D&group_by%5Blane%5D=Status&lanes=New%2CIn+Dev%2CTesting%2CDone&tab=Card+Wall'
  OPEN = 'open'
  CLOSED = 'closed'
  TWO = '2'
  RELEASE = 'release'
  THIS_CARD = "THIS CARD"
  TYPE = "type"
  INSERT_VALUE = 'Insert Value'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_92', :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(STATUS => [CLOSED, OPEN])
    @size = setup_numeric_property_definition(SIZE, [1, TWO, 3, 4])
    @due_date_property = setup_date_property_definition(DUE_DATE)
    setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    login_as_proj_admin_user
  end

  def test_should_be_able_to_use_AS_OF_in_value_query
    Clock.now_is("2009-05-14") do
      @card_1 = create_card!(:name => 'card_1', SIZE => '1')
    end

    Clock.now_is("2009-08-16") do
      @card_1.update_attribute(:cp_size, 2)
    end

    Clock.now_is("2009-10-18") do
      @card_1.update_attribute(:cp_size, 3)
    end

    open_overview_page_for_edit(@project)
    enter_text_in_editor('\\n\\n')
    create_free_hand_macro(generate_value_query("#{SIZE} AS OF '2009, May, 30'", "#{TYPE}=#{CARD}"))
    with_ajax_wait { click_save_link }
    assert_contents_on_page("1")
    edit_overview_page
    enter_text_in_editor('\\n\\n')

    create_free_hand_macro(generate_value_query("#{SIZE} AS OF '2009, Aug, 30'", "#{TYPE}=#{CARD}"))
    with_ajax_wait { click_save_link }
    assert_contents_on_page("2")
    edit_overview_page
    enter_text_in_editor('\\n\\n')

    create_free_hand_macro(generate_value_query("#{SIZE} AS OF '2009, Oct, 30'", "#{TYPE}=#{CARD}"))
    with_ajax_wait { click_save_link }
    assert_contents_on_page("3")
  end

  # 4254
  def test_error_message_when_use_this_card_in_macro_on_wiki_page
    create_card_type_property(RELEASE)
    error_message_of_using_this_card_on_wiki_page = "Error in value macro: #{THIS_CARD} is not a supported macro for page."
    error_message_of_using_this_card_value_on_wiki_page = "Error in value macro: #{THIS_CARD}.#{RELEASE} is not a supported macro for page."

    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_VALUE)
    type_macro_parameters(VALUE, :query => "select number where #{RELEASE} = #{THIS_CARD}")
    preview_macro
    assert_mql_error_messages(error_message_of_using_this_card_on_wiki_page)

    type_macro_parameters(VALUE, :query => "select number where #{RELEASE} = #{THIS_CARD}.#{RELEASE}")
    preview_macro
    assert_mql_error_messages(error_message_of_using_this_card_value_on_wiki_page)
  end

  # Bug 7794, Story 4254
  def test_warning_message_when_use_this_card_in_macro_on_card_default_edit_page
    create_card_type_property(RELEASE)
    warning_message_of_using_this_card_on_card_default = "Macros using #{THIS_CARD} will be rendered when card is created using this card default."
    warning_message_of_using_this_card_value_on_card_default = "Macros using #{THIS_CARD}.#{RELEASE} will be rendered when card is created using this card default."

    open_edit_defaults_page_for(@project, CARD)
    select_macro_editor(INSERT_VALUE)
    type_macro_parameters(VALUE, :query => "select number where #{RELEASE} = #{THIS_CARD}")
    preview_macro
    preview_content_should_include(warning_message_of_using_this_card_on_card_default)

    type_macro_parameters(VALUE, :query => "select number where #{RELEASE} = #{THIS_CARD}.#{RELEASE}")
    preview_macro
    preview_content_should_include(warning_message_of_using_this_card_value_on_card_default)
  end

  # Bug 7132
  def test_error_message_when_give_non_existing_project_identifier
    non_existing_project = "non_existing_project"
    card1 = create_card!(:name => 'smart cookie', STATUS => OPEN, SIZE => TWO)

    error_message_of_non_existing_project = "Error in value macro: There is no project with identifier #{non_existing_project}."
    open_macro_editor_without_param_input(INSERT_VALUE)
    add_macro_parameters_for(VALUE, ['project'])
    type_macro_parameters(VALUE, :query => "select number where #{STATUS} = #{OPEN}")
    type_macro_parameters(VALUE, :project => "#{non_existing_project}")
    preview_macro
    assert_mql_error_messages(error_message_of_non_existing_project)
  end


  # Bug 3835
  def test_value_query_should_show_values_of_non_numeric_properties
    card = create_card!(:number => 85, :name => name = 'ocho cinco', STATUS => status = OPEN, SIZE => size = TWO, DUE_DATE => due_date = 'Apr 18, 2008')
    name_value_query = generate_value_query('name', card_condition = "number=#{card.number}")
    status_value_query = generate_value_query(STATUS, card_condition)
    size_value_query = generate_value_query(SIZE, card_condition)
    size_times_two_value_query = generate_value_query(SIZE_TIMES_TWO, card_condition)
    due_date_value_query = generate_value_query(DUE_DATE, card_condition)
    open_overview_page_for_edit(@project)
    create_free_hand_macro(%{#{name_value_query} \n\n})
    create_free_hand_macro(%{#{status_value_query} \n\n})
    create_free_hand_macro(%{#{size_value_query} \n\n})
    create_free_hand_macro(%{#{size_times_two_value_query} \n\n})
    create_free_hand_macro(%{#{due_date_value_query} \n\n})
    sleep 5
    click_save_link
    assert_contents_on_page("#{name}", "#{status}", "#{size}", "4", "18 Apr 2008")
  end

  # Bug 3440.
  def test_should_display_count_as_whole_number
    card = create_card!(:number => 85, :name => name = 'ocho cinco')
    card = create_card!(:number => 86, :name => name = 'ocho seis')
    open_overview_page_for_edit(@project)
    create_free_hand_macro(generate_value_query_without_condition('Count(*)'))
    click_save_link
    assert_contents_on_page("2")
  end

  def test_macro_editor_for_value_macro_on_wiki_edit
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_VALUE)
    assert_should_see_macro_editor_lightbox
    assert_macro_parameters_field_exist(VALUE, ['query', 'project'])
    assert_text_present('Example: SELECT property_or_aggregate WHERE condition1 AND condition2')
  end


  def test_should_see_macro_content_after_save_value_macro
    value_paras = {:query => 'value query', :project => 'project'}
    card1 = create_card!(:name => 'smart cookie', STATUS => OPEN, SIZE => TWO)

    error_message_of_empty_input = "Error in value macro: Parameter query is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
    open_macro_editor_without_param_input(INSERT_VALUE)
    type_macro_parameters(VALUE, :query => "")
    preview_macro
    assert_mql_error_messages(error_message_of_empty_input)

    error_message_of_wrong_syntax = "Error in value macro: parse error on value false ($end). You may have a project variable, property, or tag with a name shared by a MQL keyword. If this is the case, you will need to surround the variable, property, or tags with quotes."
    type_macro_parameters(VALUE, :query => "select number where")
    preview_macro
    assert_mql_error_messages(error_message_of_wrong_syntax)

    type_macro_parameters(VALUE, :query => "select number where #{STATUS} = #{OPEN}")
    preview_macro
    preview_content_should_include("1")
  end

  def test_using_project_parameter_in_value_query
    card1 = create_card!(:name => 'smart cookie', STATUS => OPEN, SIZE => TWO)
    open_macro_editor_without_param_input(INSERT_VALUE)
    add_macro_parameters_for(VALUE, ['project'])
    type_macro_parameters(VALUE, :query => "select number where #{RELEASE} = #{THIS_CARD}")
    type_macro_parameters(VALUE, :project => "123")
    preview_macro
    assert_mql_error_messages("Error in value macro: There is no project with identifier 123.")
  end

  # 9368
  def test_should_be_able_to_compare_number_with_a_THIS_CARD_releationship_property_in_mql_where_clause
    create_card_type_property("depend_on")
    @release = create_card!(:name => 'Release_1')
    @bug_1 = create_card!(:name => 'bug1')
    @bug_1.update_attribute(:cp_depend_on, @release)
    open_card_for_edit(@project, @bug_1)
    select_macro_editor(INSERT_VALUE)
    type_macro_parameters(VALUE, :query => "SELECT name WHERE number = THIS CARD.'depend_on'")
    preview_macro
    preview_content_should_include("Release_1")
  end

  # 14570
  def test_rendered_macro_result_should_not_be_editable_content
    open_overview_page_for_edit(@project)
    create_free_hand_macro(generate_value_query_without_condition('Count(*)'))
    assert_equal 'false', @browser.get_element_attribute('css=span.macro', 'contentEditable')
  end
end

