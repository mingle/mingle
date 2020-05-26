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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

PivotTable
class PivotTable
  def header_values
    header_data.collect(&:to_s)
  end
  
  def total_values
    total_data.collect(&:to_s)
  end
  
  def body_values_for(value)
    row_values(find_row_by_value(body_data, value))
  end
  
  def first_column_values
    table_data.collect(&:first).collect(&:to_s)
  end
  
  private
  
  def row_values(row)
    row.collect(&:to_s)
  end
  
  def find_row_by_value(body_data, value)
    body_data.detect { |row| row.first.value == value }
  end
end

class PivotTableTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_member
    @project = pivot_table_macro_project
    @project.activate
  end
  
  def test_should_maintain_project_precision_in_cells_when_performing_aggregation
    create_card!(:name => 'I am card 7', :size => '7.0')
    create_card!(:name => 'I am card 8', :size => '8.000', :status => 'open')
    create_card!(:name => 'I am card 1', :size => '9.1'  , :status => 'open')
    create_card!(:name => 'I am card 2', :size => '9.223', :status => 'open')
    create_card!(:name => 'I am card 3', :size => '9.223', :status => 'open')
    create_card!(:name => 'I am card 3', :size => '9.345', :status => 'open')
    
    pivot_table = PivotTable.new(@project, :aggregation => 'SUM(SIZE)', :rows => 'Status', :columns => 'Size', :empty_rows => false, :empty_columns => false)
    assert_equal(["&nbsp;", "1", "2", "3", "5" , "7.0", "8.00", "9.1", "9.22" , "9.35"], pivot_table.header_values)
    assert_equal(["Totals", "2", "4", "3", "15", "7"  , "8"   , "9.1", "18.44", "9.35"], pivot_table.total_values)
  end
  
  def test_should_pivot_on_date_properties_with_unset_values_for_columns
    create_card!(:name => 'Card #1', :date_created => '2007-01-01', :date_deleted => '2007-02-01')
    create_card!(:name => 'Card #2', :date_created => '2007-01-01', :date_deleted => '2007-02-01')
    create_card!(:name => 'Card #3',                                :date_deleted => '2007-02-01')
  end
  
  # Bug 4689.
  def test_zero_is_not_null
    with_new_project do |project|
      login_as_bob
      setup_numeric_property_definition('story_size', [0, 1, 3, 5, 7])
      setup_property_definitions :status => ['closed', 'developed', 'new', 'open']
      card_type = project.card_types.find_by_name('Card')
      
      create_card!(:name => '1', :card_type => card_type, :status => 'open', :story_size => 0)
      create_card!(:name => '2', :card_type => card_type, :status => 'open', :story_size => 0)
      create_card!(:name => '3', :card_type => card_type, :status => 'open', :story_size => 0)
      create_card!(:name => '4', :card_type => card_type, :status => 'open', :story_size => 0)
      
      pivot_table = PivotTable.new(project, :rows => 'status', :columns => 'story_size', :conditions => 'type = Card', :aggregation => 'count(*)', :empty_columns => true)
      assert_equal(["&nbsp;" , "0", "1", "3", "5", "7", "(not set)"], pivot_table.header_values)
      assert_equal(["open"   , "4", "" , "" , "" , "" , ""         ], pivot_table.body_values_for('open'))
      assert_equal(["Totals" , "4", "" , "" , "" , "" , ""         ], pivot_table.total_values)
    end
  end
  
  # Bug 4699.
  def test_should_show_totals_for_formula_columns_that_are_not_set
    create_card!(:name => 'No size')

    pivot_table = PivotTable.new(@project, :conditions => 'Status is null', :rows => 'Status', :columns => 'half')
    assert_equal(["&nbsp;"   , "2.5", "(not set)"], pivot_table.header_values)
    assert_equal(["(not set)", "2"  , "1"        ], pivot_table.body_values_for('(not set)'))
    assert_equal(["Totals"   , "2"  , "1"        ], pivot_table.total_values)
  end
  
  def test_can_get_data_for_basic_table
    pivot_table = PivotTable.new(@project, :conditions => 'old_type = story AND Iteration = 1', :rows => 'Feature', :columns => 'Status', :aggregation => 'SUM(Size)', :totals => true, :links => false)
    assert_equal(["&nbsp;", "Dashboard", "Applications", "Rate calculator", "Profile builder", "User administration", "(not set)", "Totals"], pivot_table.first_column_values)
    assert_equal(["&nbsp;"             , "New", "In Progress", "Done", "Closed", "(not set)"], pivot_table.header_values)
    assert_equal(["Dashboard"          , ""   , ""           , ""    , "1"     , ""         ], pivot_table.body_values_for('Dashboard'))
    assert_equal(["Applications"       , "1"  , "2"          , ""    , ""      , ""         ], pivot_table.body_values_for('Applications'))
    assert_equal(["Rate calculator"    , "3"  , ""           , ""    , "2"     , ""         ], pivot_table.body_values_for('Rate calculator'))
    assert_equal(["Profile builder"    , ""   , "5"          , ""    , ""      , ""         ], pivot_table.body_values_for('Profile builder'))
    assert_equal(["User administration", ""   , ""           , ""    , ""      , ""         ], pivot_table.body_values_for('User administration'))
    assert_equal(["(not set)"          , ""   , ""           , ""    , ""      , "5"        ], pivot_table.body_values_for('(not set)'))
    assert_equal(["Totals"             , "4"  , "7"          , ""    , "3"     , "5"        ], pivot_table.total_values)
  end
  
  def test_should_pivot_on_text_properties_with_unset_values
    create_card!(:name => 'Card #1', :freetext1 => 'one', :freetext2 => 'blah' )
    create_card!(:name => 'Card #2', :freetext2 => 'blah' )
    create_card!(:name => 'Card #3', :freetext1 => 'two', :freetext2 => 'nonblah' )
    
    pivot_table = PivotTable.new(@project, :conditions => 'freetext2 IN (blah)', :rows => 'freetext1', :columns => 'freetext2', :empty_columns => false)
    assert_equal(['&nbsp;'   , 'blah'], pivot_table.header_values)
    assert_equal(['one'      , '1'   ], pivot_table.body_values_for('one'))
    assert_equal(['(not set)', '1'   ], pivot_table.body_values_for('(not set)'))
  end
  
  def test_should_pivot_on_date_properties_with_unset_values
    create_card!(:name => 'Card #1', :date_created => '2007-01-01', :date_deleted => '2007-02-01')
    create_card!(:name => 'Card #2', :date_created => '2007-01-01', :date_deleted => '2007-02-01')
    create_card!(:name => 'Card #3',                                :date_deleted => '2007-02-01')
    
    pivot_table = PivotTable.new(@project, :conditions => "date_deleted IN ('2007-02-01')", :rows => 'date_created', :columns => 'date_deleted', :empty_columns => false)
    assert_equal(['&nbsp;'    , '2007-02-01'], pivot_table.header_values)
    assert_equal(['2007-01-01', '2'         ], pivot_table.body_values_for('2007-01-01'))
    assert_equal(['(not set)' , '1'         ], pivot_table.body_values_for('(not set)'))
  end
  
  def test_should_be_able_to_pivot_on_card_relationship_column
    with_new_project do |project|
      by_first_admin_within(project) do
        analysis_property = setup_card_relationship_property_definition('analysis card')
        status_property   = setup_property_definitions :status => ['new', 'open', 'closed']
        card_type      = project.card_types.find_by_name('Card')
        iteration_type = project.card_types.create!(:name => 'Iteration')
        project.reload
      
        analysis_card = create_card!(:name => 'analysis', :card_type => iteration_type, :status => 'new')
        create_card!(:name => 'no generic'   , :card_type => card_type, :status => 'new')
        create_card!(:name => 'has generic 1', :card_type => card_type, :status => 'open'  , 'analysis card' => analysis_card.id)
        create_card!(:name => 'has generic 2', :card_type => card_type, :status => 'closed', 'analysis card' => analysis_card.id)
      
        pivot_table = PivotTable.new(project, :rows => 'status', :columns => "analysis card", :conditions => 'type = Card', :aggregation => 'count(*)', :empty_columns => false)
        assert_equal(["&nbsp;", analysis_card.number_and_name, "(not set)"], pivot_table.header_values)
        assert_equal(["new"   , ""                           , "1"        ], pivot_table.body_values_for('new'))
        assert_equal(["open"  , "1"                          , ""         ], pivot_table.body_values_for('open'))
        assert_equal(["closed", "1"                          , ""         ], pivot_table.body_values_for('closed'))
        assert_equal(["Totals", "2"                          , "1"        ], pivot_table.total_values)
      end  
    end
  end
  
  def test_should_be_able_to_pivot_on_card_relationship_column_with_empty_columns
    with_new_project do |project|
      by_first_admin_within(project) do
        analysis_property = setup_card_relationship_property_definition('analysis card')
        status_property   = setup_property_definitions :status => ['new', 'open', 'closed']
        card_type      = project.card_types.find_by_name('Card')
        iteration_type = project.card_types.create!(:name => 'Iteration')
        project.reload
        
        analysis_card      = create_card!(:name => 'analysis', :card_type => iteration_type, :status => 'new')
        no_generic_card    = create_card!(:name => 'no generic'   , :card_type => card_type, :status => 'new')
        has_generic_1_card = create_card!(:name => 'has generic 1', :card_type => card_type, :status => 'open'  , 'analysis card' => analysis_card.id)
        
        pivot_table = PivotTable.new(project, :rows => 'status', :columns => 'analysis card', :conditions => 'type = Card', :aggregation => 'count(*)', :empty_columns => true)
        assert_equal(["&nbsp;", analysis_card.number_and_name, no_generic_card.number_and_name, has_generic_1_card.number_and_name, "(not set)"], pivot_table.header_values)
        assert_equal(["new"   , ""                           , ""                             , ""                                , "1"        ], pivot_table.body_values_for('new'))
        assert_equal(["open"  , "1"                          , ""                             , ""                                , ""         ], pivot_table.body_values_for('open'))
        assert_equal(["Totals", "1"                          , ""                             , ""                                , "1"        ], pivot_table.total_values)
      end
    end
  end
  
  def test_should_be_able_to_use_this_card_in_condition
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')
    
    [[1, 'new'], [1, 'open'], [2, 'new']].each do |size, status|
      card = @project.cards.create!(:name => "#{status} #{size} - with related card", :cp_size => size, :cp_status => status, :card_type_name => 'Card')
      related_card_property_definition.update_card(card, this_card)
      card.save!
      @project.cards.create!(:name => "#{status} #{size} - without related card", :cp_size => size, :cp_status => status, :card_type_name => 'Card')
    end
    
    pivot_table = PivotTable.new(@project, :rows => 'status', :columns => 'size', :conditions => "'related card' = THIS CARD", :aggregation => 'count(*)', 
                                           :empty_columns => false, :empty_rows => false, :content_provider => this_card)
    assert_equal(["&nbsp;", "1", "2"], pivot_table.header_values)
    assert_equal(["New"   , "1", "1"], pivot_table.body_values_for('New'))
    assert_equal(["open"  , "1", "" ], pivot_table.body_values_for('open'))
    assert_equal(["Totals", "2", "1"], pivot_table.total_values)
  end
  
  # Bug 4700.
  def test_enumerated_text_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'Status', :rows => 'status', :empty_columns => true)
    expected_header = ["&nbsp;"] + @project.find_property_definition('Status').allowed_values + ["(not set)"]
    assert_equal(expected_header, pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_enumerated_text_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'Status', :columns => 'status', :empty_rows => true)
    expected_header = ["&nbsp;"] + @project.find_property_definition('Status').allowed_values + ["(not set)"]
    assert_equal(expected_header, pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_free_text_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'freetext1', :rows => 'status', :empty_columns => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_free_text_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'freetext1', :columns => 'status', :empty_rows => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_numeric_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'Size', :rows => 'status', :empty_columns => true)
    expected_header = ["&nbsp;"] + @project.find_property_definition('Size').allowed_values + ["(not set)"]
    assert_equal(expected_header, pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_numeric_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'Size', :columns => 'status', :empty_rows => true)
    expected_header = ["&nbsp;"] + @project.find_property_definition('Size').allowed_values + ["(not set)"]
    assert_equal(expected_header, pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_numeric_free_text_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    @project.cards.each(&:destroy)
    pivot_table = PivotTable.new(@project, :columns => 'numeric_free_text', :rows => 'status', :empty_columns => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_numeric_free_text_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    @project.cards.each(&:destroy)
    pivot_table = PivotTable.new(@project, :rows => 'numeric_free_text', :columns => 'status', :empty_rows => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_team_member_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'owner', :rows => 'status', :empty_columns => true)
    expected_header = ["&nbsp;"] + @project.users.collect(&:name_and_login).smart_sort + ["(not set)"]
    assert_equal(expected_header, pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_team_member_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'owner', :columns => 'status', :empty_rows => true)
    expected_header = ["&nbsp;"] + @project.users.collect(&:name_and_login).smart_sort + ["(not set)"]
    assert_equal(expected_header, pivot_table.first_column_values)
  end

  # Bug 4700.
  def test_date_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'date_created', :rows => 'status', :empty_columns => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.header_values)
  end

  # Bug 4700.
  def test_date_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'date_created', :columns => 'status', :empty_rows => true)
    assert_equal(["&nbsp;", "(not set)"], pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_formula_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :columns => 'half', :rows => 'status', :empty_columns => true)
    assert_equal(["&nbsp;", "0.5", "1", "1.5", "2.5", "(not set)"], pivot_table.header_values)
  end
  
  # Bug 4700.
  def test_formula_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    pivot_table = PivotTable.new(@project, :rows => 'half', :columns => 'status', :empty_rows => true)
    assert_equal(["&nbsp;", "0.5", "1", "1.5", "2.5", "(not set)"], pivot_table.first_column_values)
  end
  
  # Bug 4700.
  def test_relationship_should_show_not_set_column_when_empty_columns_is_true_and_there_are_no_not_set_values_in_database
    create_tree_project(:init_empty_planning_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      setup_property_definitions(:status => [])
      pivot_table = PivotTable.new(project, :rows => 'Planning release', :columns => 'status', :empty_columns => true)
      assert_equal(["&nbsp;", "(not set)"], pivot_table.header_values)
    end
  end
  
  # Bug 4700.
  def test_relationship_should_show_not_set_row_when_empty_rows_is_true_and_there_are_no_not_set_values_in_database
    create_tree_project(:init_empty_planning_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      setup_property_definitions(:status => [])
      pivot_table = PivotTable.new(project, :columns => 'Planning release', :rows => 'status', :empty_rows => true)
      assert_equal(["&nbsp;", "(not set)"], pivot_table.first_column_values)
    end
  end
  
  # Bug 4828.
  def test_should_not_show_empty_columns_for_tree_relationship_properties_when_empty_columns_are_false
    with_three_level_tree_project do |project|
      iteration1, story1, story2 = ['iteration1', 'story1', 'story2'].collect { |name| project.cards.find_by_name(name) }
      [[story1, 'open'], [story2, 'closed']].each do |(card, status)|
        card.cp_status = status
        card.save!
      end
      
      pivot_table = PivotTable.new(project, :columns => 'Planning iteration', :rows => 'status', :empty_columns => false, :conditions => "Type = Story", :totals => true)
      assert_equal(["&nbsp;"   , iteration1.number_and_name], pivot_table.header_values)
      assert_equal(["open"     , "1"                       ], pivot_table.body_values_for('open'))
      assert_equal(["closed"   , "1"                       ], pivot_table.body_values_for('closed'))
      assert_equal(["(not set)", ""                        ], pivot_table.body_values_for('(not set)'))
      assert_equal(["Totals"   , "2"                       ], pivot_table.total_values)
    end
  end
  
  # Bug 4828.
  def test_should_not_show_empty_rows_for_tree_relationship_properties_when_empty_rows_are_false
    with_three_level_tree_project do |project|
      iteration1, story1, story2 = ['iteration1', 'story1', 'story2'].collect { |name| project.cards.find_by_name(name) }
      [[story1, 'open'], [story2, 'closed']].each do |(card, status)|
        card.cp_status = status
        card.save!
      end
      
      pivot_table = PivotTable.new(project, :columns => 'status', :rows => "Planning iteration", :empty_rows => false, :conditions => "Type = Story", :totals => true)
      assert_equal(["&nbsp;", iteration1.number_and_name, "Totals"], pivot_table.first_column_values)
      assert_equal(["&nbsp;"                  , "open", "closed", "(not set)"], pivot_table.header_values)
      assert_equal([iteration1.number_and_name, "1"   , "1"     , ""         ], pivot_table.body_values_for(iteration1.number_and_name))
      assert_equal(["Totals"                  , "1"   , "1"     , ""         ], pivot_table.total_values)
    end
  end
  
  # bug 6942
  def test_pivot_table_should_recognize_the_value_2_and_20
    with_new_project do |project|
      by_first_admin_within(project) do
        setup_property_definitions :status => ['new']
        setup_numeric_property_definition('size', [2,20])
        project.reload
        create_card!(:name => "I am new card", :size => 20)
        pivot_table = PivotTable.new(project, :columns => 'size', :rows => 'status')
        assert_equal ["&nbsp;", "2", "20", "(not set)"], pivot_table.header_values
        assert_equal ["(not set)", "", "1", ""], pivot_table.body_values_for('(not set)')
        assert_equal ["Totals", "", "1", ""], pivot_table.total_values
      end
    end
  end
  
  def test_pivot_table_should_display_actual_cards_when_number_property_value_is_0
    with_new_project do |project|
      by_first_admin_within(project) do
        setup_property_definitions :status => ['new']
        setup_numeric_property_definition('size', [0,5])
        project.reload
        create_card!(:name => "I am new card", :size => 5, :status => 'new')
        create_card!(:name => "I am new card", :status => 'new')
        pivot_table = PivotTable.new(project, :columns => 'size', :rows => 'status')
        assert_equal ["&nbsp;", "0", "5", "(not set)"], pivot_table.header_values
        assert_equal ["Totals", "", "1", "1"], pivot_table.total_values
      end
    end
  end
  
  # Bug 7714
  def test_should_provide_error_message_when_using_project_as_row
    assert_raise_message(RuntimeError, "Cannot use project as the #{'rows'.bold} parameter.") do
      PivotTable.new @project, :rows => 'PROject', :columns => 'status'
    end
  end
  
  # Bug 7714
  def test_should_provide_error_message_when_using_project_as_column
    assert_raise_message(RuntimeError, "Cannot use project as the #{'columns'.bold} parameter.") do
      PivotTable.new @project, :rows => 'status', :columns => 'PrOjEcT'
    end
  end
  
  # Bug 7758
  def test_should_allow_properties_with_apostrophies_in_the_name
    with_new_project do |project|
      by_first_admin_within(project) do
        pds = setup_property_definitions "ain't a movie" => %w{a b},
                                   :status => %w{open closed}
        setup_numeric_property_definition 'size', [1,2]
        create_card! :name => 'a', "ain't a movie" => 'a', :status => 'open'
        create_card! :name => 'b', "ain't a movie" => 'b', :status => 'closed'
        pivot_table = PivotTable.new(project, :rows => "ain't a movie", :columns => 'status', :empty_columns => false)
        assert_equal ['&nbsp;', 'open', 'closed'], pivot_table.header_values
        assert_equal ['a',      '1',    ''      ], pivot_table.body_values_for('a')
        assert_equal ['b',      '',     '1'     ], pivot_table.body_values_for('b')
        assert_equal ['Totals', '1',    '1'     ], pivot_table.total_values
      end
    end
  end
  
  # Bug 7758
  def test_should_allow_properties_with_quotes_in_the_name
    with_new_project do |project|
      by_first_admin_within(project) do
        pds = setup_property_definitions "'iron' mike" => %w{a b},
                                   :status => %w{open closed}
        setup_numeric_property_definition 'size', [1,2]
        create_card! :name => 'a', "'iron' mike" => 'a', :status => 'open'
        create_card! :name => 'b', "'iron' mike" => 'b', :status => 'closed'
        pivot_table = PivotTable.new(project, :rows => "'iron' mike", :columns => 'status', :empty_columns => false)
        assert_equal ['&nbsp;', 'open', 'closed'], pivot_table.header_values
        assert_equal ['a',      '1',    ''      ], pivot_table.body_values_for('a')
        assert_equal ['b',      '',     '1'     ], pivot_table.body_values_for('b')
        assert_equal ['Totals', '1',    '1'     ], pivot_table.total_values
      end
    end
  end

  private
  
  def admin
    User.find_by_name('admin')
  end
end
