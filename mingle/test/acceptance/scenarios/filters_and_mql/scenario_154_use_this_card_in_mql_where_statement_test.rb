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

# Tags: mql, macro, this_card
class Scenario154UseThisCardInMqlWhereStatementTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  START_DATE = "start date"
  START_DATE_VALUE = "24 Dec 2009"
  CARD = "Card"
  CARD_NAME = "testing card"
  RELEASE = "release"
  
  COMMON_CARD = "comman card"
  
  
  ITERATION = "iteration"
  STORY = "story"
  BUG = "bug"
  AGGREGATE = "aggregate"
  SIZE = "size"
  OWNER = "owner"
  STATUS = "status" 
  
  DEVELOP_COMPLETE_ON = "develop complete on"
  ADDED_TO_SCOPE_ON = "added to scope on"
  
  
  CREATED_BY = "'created by'"
  MODIFIED_BY = "'Modified by'"
  CREATED_ON  = "'created on'"
  MODIFIED_ON = "'modified on'"
  BLANK = ""
  
  CHART_USE_THIS_CARD_VALUE_IN_CHART_CONDITIONS = {:render_as_text => true, :conditions => "type is #{STORY} and #{RELEASE} = this card.#{RELEASE}",:data_query_1 => "SELECT '#{DEVELOP_COMPLETE_ON}', count(*)",
  :data_query_2 => "SELECT '#{ADDED_TO_SCOPE_ON}', count(*)", :cumulative => true, :label_1 => "#{DEVELOP_COMPLETE_ON}", :label_2 => "#{ADDED_TO_SCOPE_ON}"}

  CHART_USE_THIS_CARD_VALUE_IN_SERIES_CONDITION = {:render_as_text => true, :conditions => "type is #{STORY}",:data_query_1 => "SELECT '#{DEVELOP_COMPLETE_ON}', count(*) WHERE #{RELEASE} = this card.#{RELEASE}",
  :data_query_2 => "SELECT '#{ADDED_TO_SCOPE_ON}', count(*) WHERE #{RELEASE} = this card.#{RELEASE}", :cumulative => true, :label_1 => "#{DEVELOP_COMPLETE_ON}", :label_2 => "#{ADDED_TO_SCOPE_ON}"}
  
  USE_NUMBER_AS_RELATIONSHIP_PROPERTY_CONDITION = {:render_as_text => true, :conditions => "type is #{STORY}", :data_query_1 => "SELECT 'Release', '#{DEVELOP_COMPLETE_ON}', count(*) WHERE 'Release' = this card.number",
  :cumulative => true, :label_1 => "#{DEVELOP_COMPLETE_ON}", :data_query_2 => "SELECT '#{ADDED_TO_SCOPE_ON}', count(*)", :label_2 => "#{ADDED_TO_SCOPE_ON}"}

  CHART_USE_THIS_CARD_VALUE_IN_DOWN_FROM = {:render_as_text => true, :conditions => "type is #{STORY}",:data_query_1 => "SELECT '#{DEVELOP_COMPLETE_ON}', count(*) WHERE #{RELEASE} = this card.#{RELEASE}",
  :data_query_2 => "SELECT '#{ADDED_TO_SCOPE_ON}', count(*) WHERE #{RELEASE} = this card.#{RELEASE}", :cumulative => true, :label_1 => "#{DEVELOP_COMPLETE_ON}", :label_2 => "#{ADDED_TO_SCOPE_ON}", 
  :down_from_1 => "select count(*) where  #{RELEASE} = this card.#{RELEASE}", :down_from_2 => "select count(*) where #{RELEASE} = this card.#{RELEASE}"}

  RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_CHART_CONDITIONS = {'data_for_develop complete on' => '1,1,1,1,2,2','data_for_added to scope on' => '1,1,2,2,2,2'}
  RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_SERIES_CONDITION = {'data_for_develop complete on' => '1,1,1,1,2,2','data_for_added to scope on' => '1,1,2,2,2,2'}
  RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_DOWN_FROM = {'data_for_develop complete on' => '2,1,1,1,1,0,0','data_for_added to scope on' => '2,1,1,0,0,0,0'}
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_154', :admins => [@project_admin_user])
    login_as_proj_admin_user
  end

  def test_should_be_able_to_print_any_type_property_value_of_card_in_its_description
    @release_card = create_card!(:name => COMMON_CARD)
    @owner = users(:proj_admin)
    Outline(<<-Examples, :skip_setup => true) do | property_name, property_type, property_value, formula, expected_result |
      | status        | Managed text list   | open                           |         | open                            |
      | size          | Managed number list | 1                              |         | 1                               |
      | revision      | Allow any text      | r2009_12_24                    |         | r2009_12_24                     |
      | estimate      | Allow any number    | 3.5                            |         | 3.5                             |
      | start_date    | date                | 24 Dec 2009                    |         | 24 Dec 2009                     |
      | owner         | team                | #{@owner.id}                   |         | #{@owner.name}                  |
      | release       | card                | #{@release_card.id}            |         | #{@release_card.number_and_name}|
      | formula       | formula             |                                | 1 + 1   | 2                               |
      Examples

      create_property_for_card(property_type, property_name, :formula => formula)

      #formula value is nil, so property_name => property_value would be ignored
      @card = create_card!(:name => 'testing card', property_name => property_value)
      open_card_for_edit(@project, @card.number)

      add_value_query_and_save_on(property_name,  "number = this card.number")
      assert_card_description_in_show(expected_result)
    end
  end

  def test_use_this_card_to_access_value_of_pre_defined_properties
    card = create_card!(:name => COMMON_CARD)
    {
      "type"      => CARD,
      "name"      => card.name,
      "number"    => card.number,
      CREATED_BY  => @project_admin_user.login,
      MODIFIED_BY => @project_admin_user.login,
      CREATED_ON  => utc_today_in_project_format(@project),
      MODIFIED_ON => utc_today_in_project_format(@project)
    }.each do |property_name, property_value|
      open_card_for_edit(@project, card.number)
      enter_text_in_editor('\\n\\n')
      add_value_query_and_save_on(property_name,  "number = this card.number")
      assert_card_description_in_show(property_value)
    end
  end

  def test_use_this_card_to_access_value_of_relationship_and_aggregate_properties
    iteration_type = setup_card_type(@project, ITERATION)
    story_type = setup_card_type(@project, STORY)
    bug_type = setup_card_type(@project, BUG)

    planning_tree = setup_tree(@project, 'Planning Tree', :types => [iteration_type, story_type,bug_type], 
    :relationship_names => [ITERATION, STORY])
    count_of_bugs = setup_aggregate_property_definition(AGGREGATE, AggregateType::COUNT, nil, planning_tree.id, story_type.id, bug_type)

    @iteration_card = create_card!(:name => "iteration card", :card_type => iteration_type)
    @story_card = create_card!(:name => "story card", :card_type => story_type)
    bug_card = create_card!(:name => "bug card", :card_type => bug_type)
    add_card_to_tree(planning_tree, @iteration_card)
    add_card_to_tree(planning_tree, @story_card, @iteration_card)
    add_card_to_tree(planning_tree, bug_card,@story_card)
    AggregateComputation.run_once
    sleep 1
    open_card_for_edit(@project, @story_card.number)     
    add_value_query(ITERATION,  "number IS this card.number")
    assert_card_or_page_content_in_edit("##{@iteration_card.number} #{@iteration_card.name}")

    add_value_query(AGGREGATE.inspect,  "number in (this card.number)")
    assert_card_or_page_content_in_edit("1")
  end

  def test_use_this_card_to_access_value_of_hidden_property
    setup_date_property_definition(START_DATE)
    hide_property(@project,START_DATE)
    @card = create_card!(:name => CARD_NAME, START_DATE => START_DATE_VALUE)
    open_card_for_edit(@project, @card.number)     
    add_value_query_and_save_on(START_DATE.inspect,  "number = this card.number")
    assert_card_description_in_show(START_DATE_VALUE)
  end

  def test_use_numeric_and_user_property_value_of_this_card_in_table_macro
     create_property_for_card("Managed number list", SIZE)
      create_property_for_card("team", OWNER)
      @card_1 = create_card!(:name => "this card", OWNER => @project_admin_user.id, SIZE => 2)
      @card_2 = create_card!(:name => "card should not be displayed", OWNER => @project_admin_user.id, SIZE => 3)
      @card_3 = create_card!(:name => "card should not be displayed", SIZE => 1)
      @card_4 = create_card!(:name => "card should be displayed", SIZE => 3)
    open_card_for_edit(@project, @card_1.number)    
    @table=add_table_query_and_save_on(['Number','Name'], ["#{SIZE} > THIS card.#{SIZE}", "#{OWNER} != THIS CARD.#{OWNER}"])    
    assert_table_row_data_for(@table, :row_number => 1, :cell_values => ["#{@card_4.number}","#{@card_4.name}"])
    cards_should_not_be_displayed = [@card_1,@card_2,@card_3]
    cards_should_not_be_displayed.each do |card|
      assert_card_description_in_show_does_not_match("#{card.number}\\s*#{card.name}")
   end
  end

  def test_use_managed_text_property_value_of_this_card_in_average_macro
    create_property_for_card("Managed number list", SIZE)
    create_property_for_card("Managed text list", RELEASE)
    card_1 = create_card!(:name => CARD_NAME, RELEASE => "release 1")
    @card = create_card!(:name => CARD_NAME, SIZE => 2, RELEASE => "release 1")
    card_2 = create_card!(:name => CARD_NAME, SIZE => 3, RELEASE => "release 1")
    card_3 = create_card!(:name => CARD_NAME, SIZE => 3, RELEASE => "release 2")
    open_card_for_edit(@project, @card.number)    
    add_average_query_and_save_on(SIZE, "#{RELEASE}= this card.#{RELEASE}")
    assert_card_description_in_show("2.5")    
  end

  def test_use_aggregate_and_relationship_property_value_of_this_card_in_pivot_table_macro
     iteration_type = setup_card_type(@project, ITERATION)
      release_type = setup_card_type(@project, RELEASE)
      story_type = setup_card_type(@project, STORY)    
      size = create_property_definition_for(@project, SIZE, :type => 'number list', :types => [STORY])
      planning_tree = setup_tree(@project, 'Planning Tree', :types => [release_type,iteration_type,story_type], 
      :relationship_names => [RELEASE, ITERATION])
      max_size = setup_aggregate_property_definition(AGGREGATE, AggregateType::MAX, size, planning_tree.id, iteration_type.id, story_type)
      releases = create_cards(@project,2,:card_name => RELEASE,:card_type => release_type)
      @iterations = create_cards(@project,4,:card_name => ITERATION,:card_type => iteration_type)

      story_1 = create_card!(:name => "story card 1", :card_type => story_type, SIZE => 4)
      story_2 = create_card!(:name => "story card 2", :card_type => story_type, SIZE => 1)
      story_3 = create_card!(:name => "story card 3", :card_type => story_type, SIZE => 5)
      story_4 = create_card!(:name => "story card 4", :card_type => story_type, SIZE => 1)

      add_card_to_tree(planning_tree, releases[0])
      add_card_to_tree(planning_tree, releases[1])
      add_card_to_tree(planning_tree, [@iterations[0], @iterations[3]],releases[0])
      add_card_to_tree(planning_tree, [@iterations[1], @iterations[2]],releases[1])
      add_card_to_tree(planning_tree, story_1, @iterations[0])
      add_card_to_tree(planning_tree, story_2, @iterations[1])
      add_card_to_tree(planning_tree, story_3, @iterations[2])
      add_card_to_tree(planning_tree, story_4, @iterations[3])
      AggregateComputation.run_once
      sleep 1
    open_card_for_edit(@project, @iterations[0].number)
    @pivot_table = add_pivot_table_query_and_save_for(AGGREGATE,RELEASE,:conditions => "(#{RELEASE} is not this card.#{RELEASE} or #{AGGREGATE} >= this card.#{AGGREGATE}) and type is this card.type")
    assert_table_row_data_for(@pivot_table, :row_number => 1, :cell_values => [BLANK,'1',BLANK])
    assert_table_row_data_for(@pivot_table, :row_number => 2, :cell_values => ['1',BLANK,BLANK])
    assert_table_row_data_for(@pivot_table, :row_number => 3, :cell_values => [BLANK,'1',BLANK])
    assert_table_row_data_for(@pivot_table, :row_number => 4, :cell_values => [BLANK,BLANK,BLANK])
  end

  def test_use_card_property_and_created_on_value_of_this_card_in_ratio_bar_chart
    Clock.fake_now(:year => 2012, :month => 10, :day => 30)
    create_property_for_card("Managed text list", STATUS)
    create_property_for_card("date", START_DATE)
    create_property_for_card("card", RELEASE)

    release_1 = create_card!(:name => "release 1")
    release_2 = create_card!(:name => "release 2")
    card_1 = create_card!(:name => "card 1", STATUS => "open", START_DATE => utc_today_in_project_format(@project), RELEASE => release_1.id)

    card_2 = create_card!(:name => "card 2", STATUS => "open", START_DATE => "2099-02-14", RELEASE => release_1.id)
    card_3 = create_card!(:name => "card 3", STATUS => "open", START_DATE => "1099-02-14", RELEASE => release_1.id)
    card_4 = create_card!(:name => "card 4", STATUS => "closed", START_DATE => utc_today_in_project_format(@project), RELEASE => release_1.id)
    card_5 = create_card!(:name => "card 5", STATUS => "closed", START_DATE => "1099-02-14", RELEASE => release_1.id)
    card_6 = create_card!(:name => "card 6", STATUS => "open", START_DATE => utc_today_in_project_format(@project), RELEASE => release_2.id)
    open_card_for_edit(@project, card_1.number)
    add_ratio_bar_chart_and_save_for(STATUS, "count(*)", :query_conditions  => "#{RELEASE}=this card.#{RELEASE}",:render_as_text => true, :restrict_conditions  => "'#{START_DATE}'>=this card.#{CREATED_ON}")
    assert_chart("x_labels", "open,closed")
    assert_chart('data','66,50')
  ensure
    Clock.reset_fake
  end

  def test_use_date_property_value_of_this_card_in_pie_chart
    iteration_type = setup_card_type(@project, ITERATION)
    release_type = setup_card_type(@project, RELEASE)
    story_type = setup_card_type(@project, STORY)            
    start_date = create_property_definition_for(@project, START_DATE, :type => 'date', :types => [STORY,ITERATION,RELEASE,CARD])

    iteration_card = create_card!(:name => "iteration card", :card_type => iteration_type,START_DATE => "2010-3-14")
    release_card = create_card!(:name => "release card", :card_type => release_type,START_DATE => "2010-1-14")
    @story_card = create_card!(:name => "story card", :card_type => story_type, START_DATE => "2010-2-14")
    open_card_for_edit(@project, @story_card.number)
    add_pie_chart_and_save_for("Type", "count(*)", :conditions => "'#{START_DATE}' <= THIS CARD.'#{START_DATE}'", :render_as_text => true)    
    assert_chart('slice_labels',"#{RELEASE}, #{STORY}")
    assert_chart('slice_sizes','1, 1')    
  end

  def test_use_value_of_this_card_in_chart_level_and_series_level_conditions_in_stack_bar_chart
     card_type = @project.card_types.find_by_name(CARD)
      story_type = setup_card_type(@project, STORY)            
      iteration = create_property_definition_for(@project, ITERATION, :type => "Allow any text", :types => [STORY,CARD])
      status = create_property_definition_for(@project, STATUS, :type => "Allow any text", :types => [STORY,CARD])

      card_1 = create_card!(:name => "card 1", :card_type => card_type, STATUS => "new", ITERATION => "iteration 1")
      @story_1 = create_card!(:name => "story 1", :card_type => story_type,STATUS => "new", ITERATION => "iteration 1")
      story_2 = create_card!(:name => "story 2", :card_type => story_type,STATUS => "open", ITERATION => "iteration 1")
      story_3 = create_card!(:name => "story 3", :card_type => story_type,STATUS => "open", ITERATION => "iteration 2")
    open_card_for_edit(@project, @story_1.number)
    add_stack_bar_chart_with_two_series_and_save_for(:render_as_text => true, :conditions => "type is this card.type",:data_1 => "SELECT #{ITERATION}, count(*) where #{STATUS} is this card.#{STATUS}",
    :data_2 => "SELECT #{ITERATION}, count(*)", :label_1 => "#{STATUS} is new", :label_2 => "total")
    assert_chart("data_for_total", "1,1")
    assert_chart('data_for_status is new','1,0')
  end

  def test_relationship_property_value_of_this_card_in_data_series_chart_level_conditions
    user_has_some_cards_in_RIS_planning_tree
    open_card_for_edit(@project, @iterations[0].number)
    add_data_series_chart_and_save_for(CHART_USE_THIS_CARD_VALUE_IN_CHART_CONDITIONS)
    user_should_only_see_correct_result_shown_on_data_series_chart(RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_CHART_CONDITIONS)
  end

  #bug 8339 Active record issue when using THIS CARD on data series MQL
  def test_should_draw_a_blank_chart_when_use_number_as_a_relationship_property_value
    user_has_some_cards_in_RIS_planning_tree
    open_card_for_edit(@project, @iterations[0].number)
    add_data_series_chart_and_save_for(USE_NUMBER_AS_RELATIONSHIP_PROPERTY_CONDITION)
    user_should_only_see_correct_result_shown_on_data_series_chart({'data_for_develop complete on' => '0,0','data_for_added to scope on' => '0,0'})
  end

  def test_relationship_property_value_of_this_card_in_data_series_series_level_condition
    user_has_some_cards_in_RIS_planning_tree
    open_card_for_edit(@project, @iterations[0].number)
    add_data_series_chart_and_save_for(CHART_USE_THIS_CARD_VALUE_IN_SERIES_CONDITION)
    user_should_only_see_correct_result_shown_on_data_series_chart(RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_SERIES_CONDITION)
  end

  def test_relationship_property_value_of_this_card_in_down_from_of_data_series_chart
    user_has_some_cards_in_RIS_planning_tree
    open_card_for_edit(@project, @iterations[0].number)
    add_data_series_chart_and_save_for(CHART_USE_THIS_CARD_VALUE_IN_DOWN_FROM)
    user_should_only_see_correct_result_shown_on_data_series_chart(RESULTS_OF_CHART_USE_THIS_CARD_VALUE_IN_DOWN_FROM)
  end

  def test_error_message_when_use_this_card_in_card_content_before_card_is_created
    open_card_create_page_for(@project)
    add_value_query("name",  "name = this card.name")
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, "Macros using THIS CARD.Name will be rendered when card is saved.")
  end

  def test_error_message_when_use_non_existing_property_value_of_this_card
    common_card = create_card!(:name => COMMON_CARD)
    status = create_property_definition_for(@project, STATUS, :type => "Allow any text", :types => [])
    open_card_for_edit(@project, common_card.number)
    add_value_query_and_save_on("name",  "status = this card.status")
    assert_mql_error_messages("Error in value macro: Card property 'status' is not valid for 'Card' card types.")
  end

  # bug 8091
  def test_number_comparison_in_mql_should_be_numeric_instead_of_alphabetical
    common_card = create_card!(:name => COMMON_CARD)
    create_card!(:number => 20,  :name => 'twenty')
    create_card!(:number => 100, :name => 'hundred')
    open_card_for_edit(@project, common_card.number)
    enter_text_in_editor('\\n\\n')
    add_value_query_and_save_on("name",  "number < 20")
    assert_card_description_in_show("comman card")
    open_card_for_edit(@project, common_card.number)
    add_value_query_and_save_on("name",  "number > 20")
    assert_card_description_in_show("hundred")
  end

  # bug 9075
  def test_error_message_when_create_table_mql_in_card_default_using_tree_property_not_avaliable_for_this_card
    open_edit_defaults_page_for(@project, "Card")
    release_type = setup_card_type(@project, RELEASE)
    card_type = @project.card_types.find_by_name(CARD)
    tree = setup_tree(@project, 'simple', :types => [card_type,release_type],:relationship_names => ["simple - card"])
    query = generate_table_query(['Number','Name'], ["type != THIS CARD.'simple - card'"])
    paste_query(query)
    assert_mql_error_messages("Error in table macro: Card property 'simple - card' is not valid for '#{CARD}' card types.")
  end

  # bug 9079
  def test_error_message_when_create_table_mql_in_card_default_using_non_existing_property_for_this_card
    open_edit_defaults_page_for(@project, "Card")
    query = generate_table_query(['Number','Name'], ["number > 1", "type != THIS CARD.'non_existing_property'"])
    paste_query(query)
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property 'non_existing_property' does not exist!")
  end

  # bug 8313
  def test_should_be_able_to_use_this_card_in_macro_condition_for_multiple_times_in_card_default
    open_edit_defaults_page_for(@project, "Card")
    release_type = setup_card_type(@project, RELEASE)
    card_type = @project.card_types.find_by_name(CARD)
    tree = setup_tree(@project, 'simple', :types => [release_type,card_type],:relationship_names => ["simple - release"])

    query = generate_pivot_table_query("number","name",:conditions => "type is not this card.'simple - release' or name != this card.name and number > this card.number")
    paste_query(query)
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, "Macros using THIS CARD.'simple - release' will be rendered when card is created using this card default. Macros using THIS CARD.Name will be rendered when card is created using this card default. Macros using THIS CARD.Number will be rendered when card is created using this card default.")
  end
  
  private
  def user_has_some_cards_in_RIS_planning_tree
    release_type = setup_card_type(@project, RELEASE)
    iteration_type = setup_card_type(@project, ITERATION)
    story_type = setup_card_type(@project, STORY)    
    @added_to_scope_on = create_property_definition_for(@project, ADDED_TO_SCOPE_ON, :type => 'date', :types => [STORY])
    @develop_complete_on = create_property_definition_for(@project, DEVELOP_COMPLETE_ON, :type => 'date', :types => [STORY])
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [release_type,iteration_type,story_type], 
    :relationship_names => [RELEASE, ITERATION])

    releases = create_cards(@project,2,:card_name => RELEASE,:card_type => release_type)
    @iterations = create_cards(@project,3,:card_name => ITERATION,:card_type => iteration_type)

    story_1 = create_card!(:name => "story card 1", :card_type => story_type, ADDED_TO_SCOPE_ON => "2010-01-01", DEVELOP_COMPLETE_ON => "2010-01-01")
    story_2 = create_card!(:name => "story card 2", :card_type => story_type, ADDED_TO_SCOPE_ON => "2010-01-03", DEVELOP_COMPLETE_ON => "2010-01-05")
    story_3 = create_card!(:name => "story card 3", :card_type => story_type, ADDED_TO_SCOPE_ON => "2010-01-04", DEVELOP_COMPLETE_ON => "2010-01-06")

    add_card_to_tree(planning_tree, releases[0])
    add_card_to_tree(planning_tree, releases[1])
    add_card_to_tree(planning_tree, [@iterations[0], @iterations[1]],releases[0])
    add_card_to_tree(planning_tree, [@iterations[2]],releases[1])
    add_card_to_tree(planning_tree, story_1, @iterations[0])
    add_card_to_tree(planning_tree, story_2, @iterations[1])
    add_card_to_tree(planning_tree, story_3, @iterations[2])    
  end
end
