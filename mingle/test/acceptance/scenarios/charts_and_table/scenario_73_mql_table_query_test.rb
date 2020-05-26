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

# Tags: mql, macro, table_query 
class Scenario73MqlTableQueryTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  CARD = 'Card'
  
  TABLE_QUERY = 'table-query'
  INSERT_TABLE_QUERY = 'Insert Table Query'
    
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_73', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', 'low'], STATUS => ['new',  'closed', 'open'])
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    
    login_as_admin_user
    navigate_to_project_overview_page(@project)
  end
  
  def test_pivot_table_with_is_current_user_parse_correctly_for_current_user
   user_property = setup_user_definition('user')
   card1 = create_card!(:name => 'card for nonadmin user', :user => @non_admin_user.id, SIZE => 1)
   card2 = create_card!(:name => 'card for admin user', :user => @project_admin_user.id, SIZE => 2)
   edit_overview_page
   table1 = add_pivot_table_query_and_save_for(user_property.name, user_property.name, :conditions => "#{user_property.name} IS CURRENT USER")
   @browser.wait_for_element_present "//*[@id='page-content']/table"
   assert_table_row_headers_and_order(table1, 'admin@email.com (admin)', 'longbob@email.com (longbob)', 'proj_admin@email.com (proj_admin)', '(not set)')
 end
 
  
  def test_should_be_able_to_use_AS_OF_in_table_query
    type_story = setup_card_type(@project, 'Story', :properties => [PRIORITY, SIZE])
    Clock.now_is("2009-05-14") do
      @story_1 = create_card!(:name => 'story_1', 'Type' => 'Story', SIZE => '1')
      @story_2 = create_card!(:name => 'story_2', 'Type' => 'Story', SIZE => '2')
    end

    Clock.now_is("2009-08-16") do
      @story_1.update_attribute(:cp_size, 2)
      @story_2.update_attribute(:cp_size, 3)
    end

    Clock.now_is("2009-10-18") do
      @story_1.update_attribute(:cp_size, 0)
      @story_2.update_attribute(:cp_size, 1)
    end
    
    edit_overview_page
    table_one = add_table_query_and_save_on(["#{SIZE} AS OF '2009, May, 30'"], ["Type=Story"])
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => [1])
    assert_table_row_data_for(table_one, :row_number => 2, :cell_values => [2])
    
    edit_overview_page
    table_one = add_table_query_and_save_on(["#{SIZE} AS OF '2009, Aug, 30'"], ["Type=Story"])
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => [2])
    assert_table_row_data_for(table_one, :row_number => 2, :cell_values => [3])
    
    edit_overview_page
    table_one = add_table_query_and_save_on(["#{SIZE} AS OF '2009, Oct, 30'"], ["Type=Story"])
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => [0])
    assert_table_row_data_for(table_one, :row_number => 2, :cell_values => [1])
  end
  
  # bug 6964, 6581
  def test_should_give_nice_error_message_when_grouping_by_a_not_selected_property
    edit_overview_page
    table = add_table_query_and_save_on(["COUNT(*)"], ["Type = 'Defect'"], :group_by => ['STATUS'])
    assert_mql_error_messages("Error in table macro: Use of GROUP BY is invalid. To GROUP BY a property you must also include this property in the SELECT statement.")
  end
  
  # bug 2965
  def test_project_with_4_underscores_does_not_break_table_query
    project_with_4_underscores_in_identifier = create_project(:prefix => 'project with 4 underscores in identifier', :identifier => 'testing____2_0')
    setup_property_definitions(STATUS => ['new',  'closed', 'open'])
    create_card!(:name => 'card one', STATUS => 'new')
    create_card!(:name => 'card two', STATUS => 'new')
    create_card!(:name => 'card three', STATUS => 'closed')

    navigate_to_project_overview_page(project_with_4_underscores_in_identifier)
    edit_overview_page
    table_one = add_table_query_and_save_on(['Name', 'Number', STATUS], ["Type = CARD", "#{STATUS} = 'new'"])
    assert_table_column_headers_and_order(table_one, 'Name', 'Number', STATUS)
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => ['card two', '2', 'new'])
    assert_table_row_data_for(table_one, :row_number => 2, :cell_values => ['card one', '1', 'new'])
  end
  
  # bug 
  def test_not_set_shown_as_not_set_in_table_query
    create_card!(:name => 'card one', STATUS => 'new', SIZE => 1)
    create_card!(:name => 'card two', STATUS => 'open', SIZE => 2)
    create_card!(:name => 'card three', SIZE => 4)
    create_card!(:name => 'card four', SIZE => 1)

    edit_overview_page
    table = add_table_query_and_save_on([STATUS, "SUM(#{SIZE})"])
    
    assert_table_column_headers_and_order(table, STATUS, "Sum #{SIZE}")
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['new', '1'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['open', '2'])
    assert_table_row_data_for(table, :row_number => 3, :cell_values => ['(not set)', '5'])
  end
  
  def test_PROPERTY_keyword_for_properties_in_table_query    
    estimate = setup_numeric_property_definition('estimate', [1, 2])
    pre_estimate = setup_numeric_property_definition('pre estimate', [1, 2])  
    
    create_card!(:name => 'card one', STATUS => 'new', 'estimate' => 1, 'pre estimate' => 1)
    create_card!(:name => 'card two', STATUS => 'open', 'estimate' => 1, 'pre estimate' => 2)
    create_card!(:name => 'card three', STATUS => 'new', 'estimate' => 2, 'pre estimate' => 1)

    edit_overview_page
    table = add_table_query_and_save_on(["PROPERTY #{STATUS}", "SUM(PROPERTY estimate)"], ["Type=Card", "PROPERTY #{STATUS} = new"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['new', 3])
  end
  
  def test_error_condition_while_property_does_not_exisits_while_use_of_PROPERTY_keyword
    edit_overview_page
    table = add_table_query_and_save_on(["PROPERTY #{STATUS}", "SUM(PROPERTY #{SIZE})"], ["Type=Card", "PROPERTY #{SIZE} = PROPERTY 'story status'"])
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property 'story status' does not exist!")
  end

  def test_card_type_named_PROPERTY_wont_get_messed_with_keyword_PROPERTY
    setup_allow_any_number_property_definition(ITERATION)
    type_property_name = 'PROPERTY'
    type_property = setup_card_type(@project, type_property_name, :properties => [PRIORITY, SIZE, STATUS, ITERATION])

    create_card!(:name => 'card one', :card_type => 'PROPERTY', STATUS => 'open', SIZE => 1, ITERATION => 1)
    create_card!(:name => 'card one', :card_type => 'PROPERTY', STATUS => 'open', SIZE => 2, ITERATION => 2)
    create_card!(:name => 'card one', :card_type => 'PROPERTY', STATUS => 'closed', SIZE => 4, ITERATION => 2)
    create_card!(:name => 'card one', :card_type => 'PROPERTY', STATUS => 'closed', SIZE => 4, ITERATION => 3)
    create_card!(:name => 'card one', :card_type => 'PROPERTY', SIZE => 4, ITERATION => 3)
    
    edit_overview_page
    table = add_table_query_and_save_on(["PROPERTY #{STATUS}", "SUM(PROPERTY #{SIZE})"], ["Type='#{type_property_name}'", "PROPERTY #{STATUS} IS NOT NULL",  "PROPERTY Iteration > 1"])

    assert_table_column_headers_and_order(table, STATUS, "Sum #{SIZE}")
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['closed', 8])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['open', 2])    
  end
  
  def test_numeric_properties_with_keyword_PROPERTY_and_order_by_PROJECT_CARD_RANK
    estimate = setup_numeric_property_definition('estimate', [1, 2, 4])
    pre_estimate = setup_numeric_property_definition('pre estimate', [1, 2, 4])  

    create_card!(:name => 'card one', 'estimate' => 1, 'pre estimate' => 1)
    create_card!(:name => 'card two', 'estimate' => 1, 'pre estimate' => 2)
    create_card!(:name => 'card three', 'estimate' => 2, 'pre estimate' => 1)
    create_card!(:name => 'card four', 'estimate' => 4, 'pre estimate' => 2)

    edit_overview_page
    table = add_table_query_and_save_on(["Number", "Estimate", "'Pre Estimate'"], ["Type=Card", "estimate > PROPERTY 'pre estimate'"], :order_by => ['PROJECT_CARD_RANK'])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['3', '2', '1'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['4', '4', '2'])
    
  end

  def test_date_properties_can_be_equated_with_keyword_PROPERTY
    completed_date = setup_date_property_definition('completed date')
    due_date = setup_date_property_definition('due date')
    
    create_card!(:name => 'card one', 'completed date' => 'Aug 01 2010', 'due date' => 'Aug 01 2010' )
    create_card!(:name => 'card two', 'completed date' => 'Sep 1 2010', 'due date' => 'Oct 01 2010' )
    create_card!(:name => 'card three', 'completed date' => 'Nov 01 2010', 'due date' => 'May 01 2010' )
    
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "'completed date'", "'due date'"], ["Type=Card", "'completed date' > PROPERTY 'due date'"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['3', '01 Nov 2010', '01 May 2010'])
  end

  def test_date_properties_can_be_used_in_part_of_IN_clause
    completed_date_property = setup_date_property_definition('completed date')

    create_card!(:name => 'card one', 'completed date' => '22 Jan 2005')
    create_card!(:name => 'card two', 'completed date' => 'Sep 1 2007')
    create_card!(:name => 'card three', 'completed date' => '29 Feb 2008')
    
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "'completed date'"], ["Type=Card", "'completed date' IN ('22 Jan 2005', '29 Feb 2008')"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['3', '29 Feb 2008'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['1', '22 Jan 2005'])
  end
  
  def test_text_properties_can_be_equated_with_keyword_PROPERTY
    release_property = setup_allow_any_text_property_definition('release')
    planned_release_property = setup_allow_any_text_property_definition('planned release')

    create_card!(:name => 'card one', 'release' => '3.3', 'planned release' => '4.0')
    create_card!(:name => 'card two', 'release' => '3.3', 'planned release' => '3.3')
    create_card!(:name => 'card three', 'release' => '4.0', 'planned release' => '4.0')
    
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "Name"], ["Type=Card", "release = PROPERTY 'planned release'"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['3', 'card three'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['2', 'card two'])
  end
  
  def test_card_not_returned_if_property_value_is_not_set_when_compare_two_properties
    release_property = setup_allow_any_text_property_definition('release')
    planned_release_property = setup_allow_any_text_property_definition('planned release')

    create_card!(:name => 'card one')
    create_card!(:name => 'card two', 'planned release' => '3.3')
    create_card!(:name => 'card three', 'release' => '4.0')
    create_card!(:name => 'card four', 'release' => '4.0', 'planned release' => '4.0')
    
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "Name"], ["Type=Card", "release = PROPERTY 'planned release'"])
    
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['4', 'card four'])   
    @browser.assert_text_not_present_in('content', 'card three')
    @browser.assert_text_not_present_in('content', 'card two')
    @browser.assert_text_not_present_in('content', 'card one')
  end
    
  # bug 3005
  def test_group_by_and_in_clauses_can_work_together
    size_property = setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    double_size_property = setup_formula_property_definition('double size', "#{SIZE} * 2")
    create_card!(:name => 'sample card 1', SIZE => '2')
    create_card!(:name => 'sample card 2', SIZE => '1')
    
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "Name", "'#{double_size_property.name}'"], ["'#{double_size_property.name}' IN (4.000, 2.00)"], :group_by => ["Number", "Name", "'#{double_size_property.name}'"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['2', 'sample card 2', '2'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['1', 'sample card 1', '4'])
  end
  
  # bug 2983
  def test_can_use_property_names_beginning_with_word_select_in_table_query
    selecthhh = setup_numeric_property_definition('selecthhh', [1, 2, 3])
    hello_card = create_card!(:name => 'hello', :selecthhh => '1')
    world_card = create_card!(:name => 'world', :selecthhh => '2')

    edit_overview_page
    table = add_table_query_and_save_on(["Number", "Name", "#{selecthhh.name}"], ["#{selecthhh.name} < 1.5"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ["#{hello_card.number}", "#{hello_card.name}", '1'])
  end
  
  # Bug 2757.
  def test_can_use_order_by_asc
    hello_card = create_card!(:name => 'hello')
    world_card = create_card!(:name => 'world')

    edit_overview_page
    table_name = add_table_query_and_save_on(['Number', 'Name'], ['type = card'], :order_by => ['Name aSc'])

    assert_table_row_data_for(table_name, :row_number => 1, :cell_values => ["#{hello_card.number}", "#{hello_card.name}"])
    assert_table_row_data_for(table_name, :row_number => 2, :cell_values => ["#{world_card.number}", "#{world_card.name}"])
  end
  
  # Bug 2757.
  def test_can_use_order_by_desc
    hello_card = create_card!(:name => 'hello')
    world_card = create_card!(:name => 'world')

    edit_overview_page
    table_name = add_table_query_and_save_on(['Number', 'Name'], ['type = card'], :order_by => ['Name dEsC'])
    assert_table_row_data_for(table_name, :row_number => 1, :cell_values => ["#{world_card.number}", "#{world_card.name}"])
    assert_table_row_data_for(table_name, :row_number => 2, :cell_values => ["#{hello_card.number}", "#{hello_card.name}"])
  end

  # Bug 3804.
  def test_relationship_properties_should_include_hash
    type_story = setup_card_type(@project, 'Story', :properties => [PRIORITY, SIZE])
    type_defect = setup_card_type(@project, 'Defect', :properties => [PRIORITY, STATUS])
    
    the_story = create_card!(:name => 'winnie the pooh', :card_type => 'Story')
    the_defect = create_card!(:name => "'the animals talk'", :card_type => 'Defect')
    tree = setup_tree(@project, 'story defects', :types => [type_story, type_defect],
      :relationship_names => ['story defects - story'])
    add_card_to_tree(tree, the_story)
    add_card_to_tree(tree, the_defect, the_story)

    edit_overview_page
    table_name = add_table_query_and_save_on(['Name', "'story defects - story'"], ["number = #{the_defect.number}"], :order_by => ['Name dEsC'])
    assert_table_row_data_for(table_name, :row_number => 1, :cell_values => [the_defect.name, the_story.number_and_name])
  end
  
  # bug 3966
  def test_table_query_does_not_require_grouping_by_number_unless_number_is_a_selected_column
    card_1 = create_card!(:name => 'hiya', :card_type => CARD)
    card_2 = create_card!(:name => 'byea', :card_type => CARD)
    
    edit_overview_page
    the_table = add_table_query_and_save_on(['Name'], ["Type = 'Card'"], :group_by => ['Name'])
    assert_table_row_data_for(the_table, :row_number => 1, :cell_values => [card_2.name])
    assert_table_row_data_for(the_table, :row_number => 2, :cell_values => [card_1.name])
  end
  
  # bug 4128
  def test_error_message_for_equating_two_property_in_conditions
    estimate = setup_numeric_property_definition('estimate', [1, 2, 3, 4])
    pre_release_estimate = setup_numeric_property_definition('pre release estimate', [1, 2, 3, 4])  

    edit_overview_page
    pivot_table = add_pivot_table_query_and_save_for('name', 'number', :conditions => "#{estimate.name} = '#{pre_release_estimate.name}'")
    assert_mql_error_messages("Property #{estimate.name} is numeric, and value #{pre_release_estimate.name} is not numeric. Only numeric values can be compared with #{estimate.name}. Value #{pre_release_estimate.name} is a property, please use PROPERTY #{pre_release_estimate.name}.")
    
    edit_overview_page
    table = add_table_query_and_save_on(['Name', 'number'], ["#{estimate.name} = '#{pre_release_estimate.name}'"])
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Property #{estimate.name} is numeric, and value #{pre_release_estimate.name} is not numeric. Only numeric values can be compared with #{estimate.name}. Value #{pre_release_estimate.name} is a property, please use PROPERTY #{pre_release_estimate.name}.")
  end
  
  def test_error_message_for_text_property_while_equating_other_than_equal_or_not_equal_operator
    edit_overview_page
    table = add_table_query_and_save_on(["Number", "'#{STATUS}'"], ["Type=Card", "#{STATUS} > PROPERTY '#{STATUS}'"])
    assert_mql_error_messages("Error in table macro using #{@project.identifier} project: Property #{STATUS} and #{STATUS} only can be compared by '=' and '!='. They cannot work with operator '>'")
  end

  def test_macro_editor_for_table_query_macro_on_wiki_edit
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_TABLE_QUERY)
    assert_should_see_macro_editor_lightbox
    assert_macro_parameters_field_exist(TABLE_QUERY, ['query','project'])
    assert_text_present('Example: SELECT number, name WHERE condition1 AND condition2')   
  end

  def test_macro_editor_preview_for_table_query_macro_on_card_edit
    type_story = setup_card_type(@project, 'Story', :properties => [PRIORITY, SIZE])

    create_card!(:name => 'sample card 1', :card_type => 'Story', PRIORITY => 'high', SIZE => '2')
    create_card!(:name => 'sample card 2', :card_type => 'Story', PRIORITY => 'high', SIZE => '1')
    
    open_macro_editor_without_param_input(INSERT_TABLE_QUERY)
    type_macro_parameters(TABLE_QUERY, :query => "")
    preview_macro
    preview_content_should_include("Error in table macro: Need to specify query or view")
    
    type_macro_parameters(TABLE_QUERY, :query => "select #{SIZE} where")
    preview_macro
    error_message_of_wrong_syntax = "Error in table macro: parse error on value false ($end). You may have a project variable, property, or tag with a name shared by a MQL keyword. If this is the case, you will need to surround the variable, property, or tags with quotes."
    assert_mql_error_messages(error_message_of_wrong_syntax)
    
    type_macro_parameters(TABLE_QUERY, :query => "select #{SIZE} where Type = Story")
    preview_macro
    preview_content_should_include(SIZE, "1", "2")
  end
  
  #Bug 7674
  def test_property_name_that_contains_a_question_mark_should_not_break_the_table_query
    property_name_with_question_mark = 'who am i ?'
    managed_text_property = create_managed_text_list_property(property_name_with_question_mark,  ['Monkey', 'Banana'])    
    type_story = setup_card_type(@project, 'Story', :properties => [PRIORITY, SIZE, managed_text_property])
    
    simple_card_1 = create_card!(:name => 'simple card 1', :card_type => 'Story', PRIORITY => 'high', SIZE => '2', property_name_with_question_mark => "Monkey")
    simple_card_2 = create_card!(:name => 'simple card 2', :card_type => 'Story', PRIORITY => 'low', SIZE => '1')
    
    open_macro_editor_without_param_input(INSERT_TABLE_QUERY)
    type_macro_parameters(TABLE_QUERY, :query => "select #{SIZE}, #{PRIORITY}, '#{property_name_with_question_mark}' where type = story")
    preview_macro

    preview_content_should_include(SIZE, "2", "1")
    preview_content_should_include(PRIORITY, "high", "low")
    preview_content_should_include(property_name_with_question_mark, "Monkey", "")
  end
  
  # Bug 7687
  def test_when_two_properties_have_a_very_long_name_and_only_differ_in_the_last_char_mql_returns_only_one_property_results
    long_property_name_one = 'did you check for related pending tests?'
    long_property_name_two = 'did you check for related pending tests!'
    
    setup_property_definitions(long_property_name_one => ['a'], long_property_name_two => ['b'])
    create_card!(:number => 7687, :name => 'long properties', long_property_name_one => 'a', long_property_name_two => 'b')
    open_macro_editor_without_param_input(INSERT_TABLE_QUERY)
    type_macro_parameters(TABLE_QUERY, :query => "select number, '#{long_property_name_one}', '#{long_property_name_two}' where number=7687")
    preview_macro
    preview_content_should_include '7687', 'a', 'b'
  end

  def test_table_macro_should_show_and_sort_display_name_and_login_name 
    logins_and_display_names = [
      {:login => 'a_admin', :name => "admin"},
      {:login => 'b_admin', :name => "admin"},
      {:login => 'cap',     :name => "B admin"},
      {:login => 'uncap',   :name =>  "b admin"},
      {:login => 'c_admin', :name => "c admin"}
    ]
    
    users_used_in_table_query = create_new_users(logins_and_display_names)        
    property_used_in_table_query = setup_user_definition('Owner').update_attributes(:card_types => [@project.card_types.find_by_name("Card")])
    users_used_in_table_query.each do |user|
      @project.add_member(user)
      card_used_in_table_query = create_card!(:name => 'cookie', :card_type => 'Card', 'Owner' =>  user.id) 
    end
    card = create_card!(:name => 'new card')
    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save("table query: select Owner where type = Card order by Owner")
    users_used_in_table_query.each_with_index do |user, index|
      assert_table_row_data_for('macro_preview', :row_number => index+1, :cell_values => [user.name_and_login])     
    end  
    
    destroy_users_by_logins(users_used_in_table_query.collect(&:login))  
  end

  def test_can_use_nested_in_clause_for_card_type_property
    create_card_type_property("release")
    setup_card_type(@project, 'Story', :properties => [SIZE, 'release'])
    setup_card_type(@project, 'Release', :properties => [PRIORITY])
    
    release_1 = create_card!(:name => 'release_1', :card_type => "Release", PRIORITY => 'high')
    release_2 = create_card!(:name => 'release_2', :card_type => "Release", PRIORITY => 'low')
    release_3 = create_card!(:name => 'release_3', :card_type => "Release", PRIORITY => 'low')
    
    story_1 = create_card!(:name => 'story_1', :card_type => 'Story', SIZE => 2, "release" => release_1.id)
    story_2 = create_card!(:name => 'story_2', :card_type => 'Story', SIZE => 4, "release" => release_2.id)
    story_3 = create_card!(:name => 'story_3', :card_type => 'Story', SIZE => 1, "release" => release_3.id)
    
    open_card_for_edit(@project, release_1)
    table = add_table_query_and_save_on(['Number', 'Name', SIZE], ["type is Story and release IN (SELECT NUMBER WHERE Type = Release and #{PRIORITY}='low')"])

    assert_table_row_data_for(table, :row_number => 1, :cell_values => [6, 'story_3', 1])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => [5, 'story_2', 4])
  end

  def test_can_use_nested_in_clause_for_relationship_property
    ##################################################################################################
    #                                 ---------------Planning tree-----------------
    #                                |                    |                         |
    #                    ----- release1----       ----- release2----      -----release3-----
    #                            |                       |                        |
    #                         story1                story2                   story3
    # ################################################################################################

    type_story = setup_card_type(@project, 'Story', :properties => [SIZE])
    type_release = setup_card_type(@project, "Release", :properties => [PRIORITY])    
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [type_release, type_story], :relationship_names => ['release'])
    
    release_1 = create_card!(:name => 'release_1', :card_type => 'Release', PRIORITY => 'high')
    release_2 = create_card!(:name => 'release_2', :card_type => 'Release', PRIORITY => 'low')
    release_3 = create_card!(:name => 'release_3', :card_type => 'Release', PRIORITY => 'low')
        
    story_1 = create_card!(:name => 'story_1', :card_type => 'Story', SIZE => 2)
    story_2 = create_card!(:name => 'story_2', :card_type => 'Story', SIZE => 4)
    story_3 = create_card!(:name => 'story_3', :card_type => 'Story', SIZE => 1)
    
    add_card_to_tree(planning_tree, [release_1, release_2, release_3])
    add_card_to_tree(planning_tree, story_1, release_1)
    add_card_to_tree(planning_tree, story_2, release_2)
    add_card_to_tree(planning_tree, story_3, release_3)
   
    edit_overview_page
    table = add_table_query_and_save_on(['Number', 'Name', SIZE], ["type is Story and release IN (SELECT Name WHERE Type is Release and #{PRIORITY}='low')"])

    assert_table_row_data_for(table, :row_number => 1, :cell_values => [6, 'story_3', 1])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => [5, 'story_2', 4])
  end
  
  def test_use_card_type_property_in_the_nested_in_clause
    setup_date_property_definition('completed date')
    create_card_type_property("release")
    setup_card_type(@project, 'Story', :properties => ['completed date', 'release', PRIORITY, SIZE])
    setup_card_type(@project, 'Release')
    
    release_1 = create_card!(:name => 'release_1', :card_type => 'Release')
    release_2 = create_card!(:name => 'release_2', :card_type => 'Release')
    
    story_1 = create_card!(:name => 'story_1', :card_type => 'Story', 'completed date' => '18 Oct 2006', "release" => release_1.id)
    story_2 = create_card!(:name => 'story_2', :card_type => 'Story', 'completed date' => '29 Oct 2007', "release" => release_1.id)
    story_3 = create_card!(:name => 'story_3', :card_type => 'Story', 'completed date' => '17 Oct 2008',"release" => release_2.id)
    
    open_card_for_edit(@project, release_1)
    table = add_table_query_and_save_on(['Number', 'Name', "'completed date'"], ["type is Story and release IN (SELECT release WHERE type is Story and 'completed date' > '18 Oct 2006')"])

    assert_mql_error_messages('Error in table macro: Nested MQL statments can only SELECT name or number properties.')
  end
  
  def test_can_not_select_more_than_one_property_in_nested_in_clause    
    create_card_type_property('release')
    setup_card_type(@project, 'Story', :properties => [PRIORITY, 'release'])
        
    edit_overview_page
    select_macro_editor(INSERT_TABLE_QUERY)
    type_macro_parameters(TABLE_QUERY, :query => "SELECT #{PRIORITY}, Name WHERE 'release' IN (SELECT NUMBER, Name WHERE #{PRIORITY}='low')")    
    submit_macro_editor
    assert_mql_error_messages('Error in table macro: Nested MQL statments can only SELECT one property.')
  end

  def test_only_support_select_name_number_relationship_properties_in_nested_in_clause
    create_card_type_property('release')
    setup_card_type(@project, 'Story', :properties => [PRIORITY, SIZE, 'release'])
    setup_card_type(@project, 'Release')
    
    story = create_card!(:name => 'story', :card_type => 'Story')
    open_card_for_edit(@project, story)
    add_table_query_and_save_on(['Number', 'Name'], ["type is Story and release IN (SELECT Type WHERE type = Release and #{PRIORITY} = low)"])
    
    assert_mql_error_messages('Error in table macro: Nested MQL statments can only SELECT name or number properties.')    
  end
  
  def test_can_not_use_group_by_in_nested_in_caluse    
    create_card_type_property('release')
    create_card_type_property('planned release')
    setup_card_type(@project, 'Story', :properties => [PRIORITY, 'release', 'planned release'])
    setup_card_type(@project, 'Release')

    release_card = create_card!(:name => 'Release 1', :card_type => 'Release')    
    story_card = create_card!(:name => 'Story 1', :card_type => 'Story', PRIORITY => 'low', 'release' => release_card.id, 'planned release' => release_card.id)
    open_card_for_edit(@project, story_card)
    add_table_query_and_save_on(['Number', 'Name'], ["type is Story and release IN (SELECT 'planned release' WHERE #{PRIORITY}=low group by 'planned release')"])

    assert_mql_error_messages('Error in table macro: GROUP BY is not allowed in a nested IN clause.')        
  end
  
  def test_can_not_use_order_by_in_nested_in_clauses
    setup_card_type(@project, 'Release')
    create_card_type_property('release')
    setup_card_type(@project, 'Story', :properties => ['release'])

    release_card = create_card!(:name => 'Release 1', :card_type => 'Release')
    create_card!(:name => 'Story 1', :card_type => 'Story', 'release' => release_card.id)

    edit_overview_page
    add_table_query_and_save_on(['Number', 'Name'], ["type is Story and release IN (SELECT NUMBER order by type)"])    

    assert_mql_error_messages('Error in table macro: ORDER BY is not allowed in a nested IN clause.')
  end
  
  def test_can_not_use_as_of_in_nested_in_clause
    setup_card_type(@project, 'Release')
    create_card_type_property('release')
    setup_card_type(@project, 'Story', :properties => ['release'])
    
    release_card = create_card!(:name => 'Release 1', :card_type => 'Release')
    create_card!(:name => 'Story 1', :card_type => 'Story', 'release' => release_card.id)

    edit_overview_page
    add_table_query_and_save_on(['Number', 'Name'], ["type is Story and release IN (SELECT NUMBER as of 'Aug 15 2010')"])    

    assert_mql_error_messages('Error in table macro: AS OF is not allowed in a nested IN clause.')    
  end
end
