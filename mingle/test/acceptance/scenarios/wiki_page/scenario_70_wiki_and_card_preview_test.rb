#encoding:utf-8

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

#Tags: preview, wiki, page, card

class Scenario70WikiAndCardPreviewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  
  LOW = 'low'
  HIGH = 'high'
  PLANNING = 'Planning'
  NONE = 'None'
  
  START_DATE = 'start_date'
  END_DATE = 'end_date'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_70', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => [HIGH, LOW], SIZE => [1, 2, 4], STATUS => [NEW, OPEN], ITERATION => [1,2,3,4])
    setup_date_property_definition(START_DATE)
    setup_date_property_definition(END_DATE)
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, ITERATION])
    login_as_proj_admin_user
    @story1 = create_card!(:name => 'story', :description => "h3. Acceptance criteria", :card_type => STORY, SIZE  => '2')
    @story2 = create_card!(:name => 'story2', :description => "cc", :card_type => STORY, SIZE  => '4')
    @defect1 = create_card!(:name => 'Bug', :card_type => DEFECT, PRIORITY => HIGH)
    @story3 = create_card!(:name => 'story3', :card_type => STORY, PRIORITY => HIGH, SIZE => 4)
    
    navigate_to_card_list_for(@project)
  end


  def test_should_give_correct_value_for_stack_bar_chart
    add_stack_bar_chart_and_save_on_overview_page(:property  => 'size',:aggregate  => "count(*)", :conditions  => 'priority is high', :render_as_text => true)
    assert_chart('x_labels','1,2,4')
    assert_chart('data_for_Series 1','0,0,1')
  end

  def test_should_give_correct_value_for_data_series_chart
    add_data_series_chart_and_save_on_overview_page(:property  => "size", :aggregate  => "count(*)", :render_as_text => true, :conditions  => 'priority is null')
    assert_chart('x_labels','1,2,4')
    assert_chart('data_for_Series 1','0,1,2')
  end

  # bug 8135
  def test_should_not_render_series_data_labels_if_not_specified_when_type_is_area
    add_data_series_chart_and_save_on_overview_page(:property  => "size", :aggregate  => "count(*)", :render_as_text => true, :conditions  => 'priority is null', :series_type => "area")
    assert_value_not_set('data_labels_enabled_for_Series 1')
  end
  
  def test_should_render_series_data_labels_if_specified
    add_data_series_chart_and_save_on_overview_page(:property  => "size", :aggregate  => "count(*)", :render_as_text => true, :conditions  => 'priority is null', :series_type => "area", :data_labels => 'true')
    assert_chart('data_labels_enabled_for_Series 1', 'true') 
  end


  def test_should_give_correct_value_for_ratio_bar_chart
    add_ratio_bar_chart_and_save_on_overview_page("size", "count(*)", :render_as_text => true, :restrict_conditions  => 'priority is high')
    assert_chart("x_labels", "2,4")
    assert_chart('data','0,50')
  end
  
  #bug 6199
  def test_user_should_get_incorrect_synax_error_but_not_other_unclear_errors
    edit_overview_page 
    query = generate_a_incorrect_data_series_chart_query(:conditions => 'type = Story', :aggregate => 'count(*)', :property => 'size')
    create_free_hand_macro(query)
    assert_mql_syntax_error_message_present    
  end
    
  #bug 5475
  def test_can_create_wiki_page_with_name_that_contains_the_period_DOT
    wiki_name_with_dot = '2.2 release'
    new_wiki = create_a_wiki_page_with_text(@project, 'new wiki', "[[#{wiki_name_with_dot}]]")
    click_link("#{wiki_name_with_dot}")
    @browser.assert_text_present("#{wiki_name_with_dot}")
  end
  
  # bug 4604
  def test_can_create_wiki_page_with_name_that_has_utf8_chars
    russian_name = 'Требования'
    new_page = create_a_wiki_page_with_text(@project, russian_name, "some nice content")
    open_wiki_page(@project, russian_name)
    assert_opened_wiki_page(russian_name)  # before the bug fix, we would end up on wiki edit page, not show page
  end
  

  #bug 3099 
  def test_should_get_a_clear_error_message_when_comparing_two_properties_in_mql
    type_new_story_type = setup_card_type(@project, 'New_Story_Type', :properties => [STATUS, PRIORITY, SIZE,START_DATE, END_DATE])
    create_card!(:name => 'my_story1', :card_type => 'New_Story_Type', START_DATE => OPEN, PRIORITY => HIGH, SIZE => 1, START_DATE => '01 Sep 2008', END_DATE => '08 Sep 2008')
    create_card!(:name => 'my_story2', :card_type => 'New_Story_Type', START_DATE => OPEN, PRIORITY => HIGH, SIZE => 2, START_DATE => '01 Sep 2008', END_DATE => '08 Sep 2008')
    create_card!(:name => 'my_story3', :card_type => 'New_Story_Type', START_DATE => OPEN, PRIORITY => HIGH, SIZE => 4, START_DATE => '01 Sep 2008', END_DATE => '08 Sep 2008')
    navigate_to_card_list_for(@project)
    add_pie_chart_and_save_on_overview_page("size", "count(*)", :conditions => "#{END_DATE} > #{START_DATE}")
    assert_mql_error_messages("Error in pie-chart macro using #{@project.name} project: Property #{END_DATE} is date, and value #{START_DATE} is not date. Only date values can be compared with #{END_DATE}. Value #{START_DATE} is a property, please use PROPERTY #{START_DATE}.")
  end
  
  def test_should_give_correct_value_for_pie_chart
    add_pie_chart_and_save_on_overview_page("size", "count(*)", :render_as_text => true)
    assert_chart("pie_width", "440")
    assert_chart("pie_height", "300")
    assert_chart('slice_labels','2, 4, (not set)')
    assert_chart('slice_sizes','1, 2, 1')
  end
  
  # bug 2936
  def test_mql_tables_or_views_does_not_fail_previewing_if_typo_error_in_property_or_type
    value_query = generate_value_query(SIZE, 'Type=storyy')
    average_query = generate_average_query("sizze", "#{TYPE}=#{STORY}")
    table_query = generate_table_query(['name', 'numbeer'], ["#{TYPE}=#{DEFECT}"])
    # on a wiki
    edit_overview_page
    create_free_hand_macro(value_query)
    assert_mql_error_messages(
    "Error in value macro using #{@project.name} project: storyy is not a valid value for Type, which is restricted to Card, Defect, and Story")
    create_free_hand_macro(average_query)
    assert_mql_error_messages("Error in average macro using #{@project.name} project: Card property 'sizze' does not exist!")
    create_free_hand_macro(table_query)
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property 'numbeer' does not exist!")

    # on a card
    open_card(@project, @defect1.number)
    click_edit_link_on_card
    create_free_hand_macro(value_query)
    assert_mql_error_messages(
    "Error in value macro using #{@project.name} project: storyy is not a valid value for Type, which is restricted to Card, Defect, and Story")
    create_free_hand_macro(average_query)
    assert_mql_error_messages("Error in average macro using #{@project.name} project: Card property 'sizze' does not exist!")
    create_free_hand_macro(table_query)
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property 'numbeer' does not exist!")
  
    # on Card Defaults...
    navigate_to_card_type_management_for(@project)
    open_edit_defaults_page_for(@project, STORY)
    create_free_hand_macro(value_query)
    assert_mql_error_messages(
    "Error in value macro using #{@project.name} project: storyy is not a valid value for Type, which is restricted to Card, Defect, and Story")
    create_free_hand_macro(average_query)
    assert_mql_error_messages("Error in average macro using #{@project.name} project: Card property 'sizze' does not exist!")
    create_free_hand_macro(table_query)
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property 'numbeer' does not exist!")
  end
  
  # bug 2982
  def test_mql_does_not_throw_error_when_no_aggregate_mensioned_in_query
    edit_overview_page
    table_one = add_pivot_table_query_and_save_for(PRIORITY, SIZE, :conditions => "Type = #{STORY}", :aggregation => "", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')
    @browser.assert_text_not_present("Could not parse query")
    assert_table_column_headers_and_order(table_one, '2', '4')
  end
    
  private
  def assert_all_mql_macro_errors_on_page
    assert_mql_error_messages(
    "Error in value macro using #{@project.name} project: storyy is not a valid value for Type, which is restricted to Card, Defect, and Story",
    "Error in average macro using #{@project.name} project: Card property 'sizze' does not exist!",
    "Error in table macro using #{@project.name} project: Card property 'numbeer' does not exist!"
    )
  end

end
