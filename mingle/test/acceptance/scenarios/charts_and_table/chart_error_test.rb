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

#Tags: wiki_2, page, card, chart

class ChartErrorTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'owner'
  CURRENT_USER= '(current user)'

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
  CLOSED = 'closed'
  
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
    @project = create_project(:prefix => 'chart_errors', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => [HIGH, LOW], SIZE => [1, 2, 4], STATUS => [NEW, OPEN, CLOSED], ITERATION => [1,2,3,4])
    setup_date_property_definition(START_DATE)
    setup_date_property_definition(END_DATE)
    setup_user_definition(OWNER)
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, STATUS, ITERATION, START_DATE, END_DATE, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, ITERATION])
    login_as_proj_admin_user
    @story1 = create_card!(:name => 'story', :description => "h3. Acceptance criteria", :card_type => STORY, SIZE  => '2', START_DATE => '10/10/2009',  STATUS => 'closed', OWNER => CURRENT_USER)
    @story2 = create_card!(:name => 'story2', :description => "cc", :card_type => STORY, SIZE  => '4', START_DATE => '11/10/2009', STATUS => 'open', OWNER => CURRENT_USER)
    @story3 = create_card!(:name => 'story3', :description => "ss", :card_type => STORY, SIZE  => '4', STATUS => 'new', OWNER => @non_admin_user.id)
    @defect1 = create_card!(:name => 'Bug', :card_type => DEFECT, PRIORITY => HIGH)
    navigate_to_card_list_for(@project)
  end
      
 # Pie charts
 
  def test_given_property_does_not_exist_when_used_in_pie_then_give_error
    add_pie_chart_and_save_on_overview_page("siize", "count(*)", :conditions => "Type = #{STORY}", :render_as_text => false)
     assert_mql_error_messages(
    "Error in pie-chart macro using #{@project.name} project: Card property 'siize' does not exist!")
  end
  
  def test_given_no_or_wrong_aggregate_when_used_in_pie_then_give_error
    add_pie_chart_without_aggregate_and_save_for("size")
    assert_mql_error_messages(
    "Error in pie-chart macro: Must provide a property and an aggregate, e.g. SELECT status, SUM(size)")
    add_pie_chart_and_save_on_overview_page("size", "sum(*)", :conditions => "Type = #{STORY}", :render_as_text => false)
     assert_mql_error_messages(
    "Error in pie-chart macro: * can only be used with the count aggregate function.")
    add_pie_chart_and_save_on_overview_page("status", "count(size)", :conditions => "Type = #{STORY}", :render_as_text => false)
    assert_mql_error_messages(
    "Error in pie-chart macro using #{@project.name} project: Property size is not numeric, only numeric properties can be aggregated.")      
  end
  
  # Data series charts - generic errors
  
  def test_data_series_given_property_does_not_exist_when_used_in_data_series_then_give_error
    add_data_series_chart_and_save_on_overview_page(:property => "siize", :conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in data-series-chart macro using #{@project.name} project: Card property 'siize' does not exist!")
  end
  
  def test_data_series_given_plotting_against_non_relationship_property_when_x_labels_conditions_is_specified_then_give_error
    add_data_series_chart_and_save_on_overview_page(:property =>"size", :x_labels_conditions => "Type = #{STORY}", :conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in data-series-chart macro using #{@project.name} project: Parameters x-labels-conditions and x-labels-tree are only supported when x-labels are driven by a relationship property. Please remove these parameters if you are not charting against a relationship property.")
  end
  
  def test_data_series_when_no_series_specified_then_give_error
    add_data_series_chart_with_no_series_and_save_for(:conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter series is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.")
  end
  
  def test_data_series_when_only_property_or_aggregate_is_specified_in_series_data_then_give_error
    add_data_series_chart_with_wrong_data_query_and_save_for("SELECT size")
    assert_mql_error_messages(
    "Error in data-series-chart macro: An aggregate must be specified in the series data parameter: SELECT size")
    add_data_series_chart_with_wrong_data_query_and_save_for("SELECT count(*)")
    assert_mql_error_messages(
    "Error in data-series-chart macro: A property name must be specified in the series data parameter: SELECT count(*)")
  end
  
  def test_data_series_when_invailid_value_given_to_static_parameter_then_give_error
    add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter("SELECT size, count(*)", "chart-type: foo")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter chart-type must be one of: line, area, bar. The default value is line.")
    add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter("SELECT size, count(*)", "three-d: not true")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter three-d must be one of: true, false. The default value is false.")
    add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter("SELECT size, count(*)", "cumulative: not true")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter cumulative must be one of: true, false. The default value is false.")
    add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter("SELECT size, count(*)", "show-start-label: not true")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter show-start-label must be one of: true, false. The default value is false, unless one of the chart's series is a down-from series, in which case the default value is true.")
    add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter("SELECT size, count(*)", "show-start-label: not true")
  end
  
  def test_data_series_when_property_in_conditions_does_not_exist_then_give_error
    add_data_series_chart_and_save_on_overview_page(:chart_conditions => "'Feature' = 'Charting'", :property =>"size", :x_labels_conditions => "Type = #{STORY}", :conditions => "Type = #{STORY}" )
    assert_mql_error_messages(
    "Error in data-series-chart macro using #{@project.name} project: Card property 'Feature' does not exist!")
  end
  
  def test_data_series_when_type_in_conditions_does_not_exist_then_give_error
    add_data_series_chart_and_save_on_overview_page(:chart_conditions => "'Type' = 'Feature'", :property =>"size", :x_labels_conditions => "Type = #{STORY}", :conditions => "Type = #{STORY}" )
    assert_mql_error_messages(
    "Error in data-series-chart macro using #{@project.name} project: Feature is not a valid value for Type, which is restricted to Card, Defect, and Story")
  end
 
  # Data series charts - numeric properties
  
  def test_data_series_given_plotting_against_numeric_property_when_x_labels_start_value_does_not_exist_then_give_error
    add_data_series_chart_and_save_on_overview_page(:property =>"size", :x_labels_start => "1000", :conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in data-series-chart macro using #{@project.name} project: 1000 is not a valid value for the x-labels-start parameter because it does not exist for property size.")
  end
  
  def test_data_series_given_plotting_against_numeric_property_when_x_labels_end_value_does_not_exist_then_give_error
     add_data_series_chart_and_save_on_overview_page(:property =>"size", :x_labels_end => "1000", :conditions => "Type = #{STORY}")
     assert_mql_error_messages(
     "Error in data-series-chart macro using #{@project.name} project: 1000 is not a valid value for the x-labels-end parameter because it does not exist for property size.")
  end
  
  def test_data_series_given_plotting_against_numeric_property_when_x_labels_start_is_after_x_labels_end_then_give_error
     add_data_series_chart_and_save_on_overview_page(:property =>"size", :x_labels_start => "4", :x_labels_end => "1", :conditions => "Type = #{STORY}")
     assert_mql_error_messages(
     "Error in data-series-chart macro: x-labels-start must be a value less than x-labels-end.")
  end
 
   # Data series charts - text properties

    def test_data_series_given_plotting_against_text_property_when_x_labels_start_value_does_not_exist_then_give_error
      add_data_series_chart_and_save_on_overview_page(:property =>"status", :x_labels_start => "opuen", :conditions => "Type = #{STORY}")
      assert_mql_error_messages(
      "Error in data-series-chart macro using #{@project.name} project: opuen is not a valid value for the x-labels-start parameter because it does not exist for property status.")
    end

    def test_data_series_given_plotting_against_text_property_when_x_labels_end_value_does_not_exist_then_give_error
       add_data_series_chart_and_save_on_overview_page(:property =>"status", :x_labels_end => "opuen", :conditions => "Type = #{STORY}")
       assert_mql_error_messages(
       "Error in data-series-chart macro using #{@project.name} project: opuen is not a valid value for the x-labels-end parameter because it does not exist for property status.")
    end

    def test_data_series_given_plotting_against_text_property_when_x_labels_start_is_after_x_labels_end_then_give_error
       add_data_series_chart_and_save_on_overview_page(:property =>"status", :x_labels_start => "closed", :x_labels_end => "new", :conditions => "Type = #{STORY}")
       assert_mql_error_messages(
       "Error in data-series-chart macro: x-labels-start must be a value less than x-labels-end.")
    end
    
  # Data series charts - team properties

   def test_data_series_given_plotting_against_team_property_when_x_labels_start_value_does_not_exist_then_give_error
     add_data_series_chart_and_save_on_overview_page(:property =>"owner", :x_labels_start => "suzie", :conditions => "Type = #{STORY}")
     assert_mql_error_messages(
     "Error in data-series-chart macro using #{@project.name} project: suzie is not a valid value for the x-labels-start parameter because it does not exist for property owner.")
   end

   def test_data_series_given_plotting_against_team_property_when_x_labels_end_value_does_not_exist_then_give_error
      add_data_series_chart_and_save_on_overview_page(:property =>"owner", :x_labels_end => "suzie", :conditions => "Type = #{STORY}")
      assert_mql_error_messages(
      "Error in data-series-chart macro using #{@project.name} project: suzie is not a valid value for the x-labels-end parameter because it does not exist for property owner.")
   end

   def test_data_series_given_plotting_against_team_property_when_x_labels_start_is_after_x_labels_end_then_give_error
      add_data_series_chart_and_save_on_overview_page(:property =>"owner", :x_labels_start => "proj_admin", :x_labels_end => "longbob", :conditions => "Type = #{STORY}")
      assert_mql_error_messages(
      "Error in data-series-chart macro: x-labels-start must be a value less than x-labels-end.")
   end
  
  # Data series charts - date properties

  def test_data_series_given_plotting_against_date_property_when_x_labels_start_is_not_a_date_then_give_error
    add_data_series_chart_and_save_on_overview_page(:property =>"start_date", :x_labels_start => "1000", :conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in data-series-chart macro: Parameter x-labels-start must be a valid date.")
  end
  
  
  # Stack bar charts - generic errors - when I run this locally I get this message but when I run this here the message is different. I don't know why?
  
  def test_stack_when_no_series_specified_then_give_error
    add_stack_bar_chart_with_no_series_and_save_for(:conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in stack-bar-chart macro: Parameter series is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax.")
  end
  
  # Stack bar charts - numeric properties
  
  def test_stack_given_property_does_not_exist_when_used_in_stack_then_give_error
    add_stack_bar_chart_and_save_on_overview_page(:property => "siize", :conditions => "Type = #{STORY}")
    assert_mql_error_messages(
    "Error in stack-bar-chart macro using #{@project.name} project: Card property 'siize' does not exist!")
  end

  # bug 7443 ratio-bar-chart
  def test_should_give_error_message_when_wrong_card_type_used_in_cross_project
    project_2 = create_project(:prefix => 'empty project', :users => [@non_admin_user], :admins => [@project_admin_user])
    open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
         ratio-bar-chart
             totals: SELECT name, count(*)
             restrict-ratio-with: type = story
             project: #{project_2.identifier}
     })
     assert_mql_error_messages(
     "Error in ratio-bar-chart macro using #{project_2.name} project: story is not a valid value for Type, which is restricted to Card ")
  end 
  
  def test_should_give_error_when_tried_ruby_code_injection_through_mql
    open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
        project-variable
           name: !ruby/object:Time
    })
    assert_mql_error_messages("Error in project-variable macro: Embedding Ruby objects is not allowed")
  end

  def test_should_give_error_for_in_plan_clause_used_for_non_existant_plan
    open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
      table query: SELECT number, name where in plan doesnotexisit
    })
    assert_mql_error_messages "Error in table macro: Plan with name doesnotexisit does not exist or has not been associated with this project."
  end

  def test_should_give_error_for_plan_name_with_paranthesis
    open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
      table query: SELECT number, name where in plan (noPlan)
    })
    assert_mql_error_messages "Error in table macro: parse error on value \"(\" (OPEN_BRACE). You may have a project variable, property, or tag with a name shared by a MQL keyword. If this is the case, you will need to surround the variable, property, or tags with quotes."
  end

end 
