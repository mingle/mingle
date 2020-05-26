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

class CardPropertyDefinitionTest < ActiveSupport::TestCase
  
  def setup
    login_as_member
    @project = card_prop_def_test_project
    @project.activate
    login_as_member
    @story_type = @project.find_card_type('story')    
    @iteration_type = @project.find_card_type('iteration')
    @iteration_propdef = @project.find_property_definition('iteration')
  end
    
  def test_after_creating_card_property_card_should_have_correct_db_column
    assert_equal('cp_iteration_card_id', @iteration_propdef.column_name)
    assert_card_has_column 'cp_iteration_card_id'
  end
  
  def test_can_get_card_reference_from_card_property
    story = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    iteration = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    assert_nil story.cp_iteration
    story.cp_iteration = iteration
    story.save!
    story.reload
    assert_equal iteration, story.cp_iteration
  end
  
  def test_should_not_be_able_to_assign_card_with_type_that_is_not_allowed
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    story2 = @project.cards.create!(:name => 'story2', :card_type => @story_type)
    story1.cp_iteration = story2
    @iteration_propdef.validate_card(story1)
    assert !story1.valid?
  end
  
  def test_should_not_be_able_to_assign_card_to_itself
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    iteration1.cp_iteration = iteration1
    @iteration_propdef.validate_card(iteration1)
    assert !iteration1.valid?
  end
  
  def test_should_raise_error_if_value_card_can_not_be_find
    card = @project.cards.new(:name => 'card1', :cp_iteration_card_id => 'invalid card id', 
      :project => @project, :card_type => @story_type)
    assert_raise(PropertyDefinition::InvalidValueException) do
      @iteration_propdef.validate_card(card)
    end
  end
  
  def test_value_for_card_should_return_card
    story = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    story.cp_iteration = iteration1
    assert_equal iteration1,  @iteration_propdef.value(story)
    property_value = story.property_value(@iteration_propdef)
    assert_equal iteration1.id.to_s, property_value.db_identifier
  end

  def test_should_not_support_inline_creating
    assert !@iteration_propdef.support_inline_creating?
  end

  def test_should_be_able_to_update_card_with_new_value
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    @iteration_propdef.update_card(story1, iteration1.id)
    story1.save!
    @iteration_propdef.update_card(story1, iteration2.id)
    story1.save!
    assert_equal iteration2, story1.cp_iteration
  end
  
  def test_values_should_return_all_the_cards_with_valid_card_type
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    assert @iteration_propdef.values.include?(iteration1)
    assert !@iteration_propdef.values.include?(story1)
  end
   
  def test_should_be_able_to_tell_whether_a_value_is_assigned_to_card
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    assert !@iteration_propdef.property_value_from_db(iteration1.id).assigned_to?(story1)
    assert @iteration_propdef.property_value_from_db(nil).assigned_to?(story1)
    story1.cp_iteration = iteration1
    assert @iteration_propdef.property_value_from_db(iteration1.id).assigned_to?(story1)
  end
  
  def test_should_be_able_to_unassign_a_card_property_value
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1)
    @iteration_propdef.update_card(story1, nil)
    story1.save!
    assert_nil story1.reload.cp_iteration
  end
  
  
  def test_inital_value_for_card_selections
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1)
    card_selection = CardSelection.new(@project.reload, [story1])
    assert_equal ["##{iteration1.number} iteration1", iteration1.id.to_s], card_selection.value_for(@iteration_propdef)
    assert_equal iteration1.id.to_s, card_selection.value_identifier_for(@iteration_propdef)
  end
  
  def test_bulk_edit_card_property_definition
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    story2 = @project.cards.create!(:name => 'story2', :card_type => @story_type)
    story3 = @project.cards.create!(:name => 'story3', :card_type => @story_type)
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    card_selection = CardSelection.new(@project.reload, [story1, story2])    
    card_selection.update_properties('iteration' => iteration1.id.to_s)
    assert card_selection.errors.empty?
    assert_equal iteration1, story1.reload.cp_iteration
    assert_equal iteration1, story2.reload.cp_iteration
    assert_not_equal iteration1, story3.reload.cp_iteration
  end

  def test_columns_for_card_list_view_should_include_card_property_defintions
    assert @project.property_definitions_for_columns.include?(@iteration_propdef)
    view = CardListView.find_or_construct(@project.reload, {:columns => 'iteration'})
    assert_equal [@iteration_propdef], view.column_property_definitions
  end
  
  def test_group_lanes_works_with_card_property_definition
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
    iteration3 = @project.cards.create!(:name => 'iteration3', :card_type => @iteration_type)
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1)
    story2 = @project.cards.create!(:name => 'story2', :card_type => @story_type, :cp_iteration => iteration2)
    story3 = @project.cards.create!(:name => 'story3', :card_type => @story_type)
  
    view = OpenStruct.new(:project => @project, :cards => [], :to_params => {})
    view.cards = [story1, story2, story3]
    group_lanes = CardView::GroupLanes.new(view, {:group_by => 'iteration', :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},#{iteration1.number},#{iteration2.number}"})
    assert_equal [story3], group_lanes.not_set_lane.cards
    assert_equal [story1], group_lanes.lane(iteration1.number).cards
    assert_equal [story2], group_lanes.lane(iteration2.number).cards
  end
  
  
  def test_should_work_with_transitions
    iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
    iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
    story1 = @project.cards.create!(:name => 'story1', :card_type => @story_type)
    transition = create_transition(@project, 'move to iteration 2', :required_properties => {:iteration => iteration1.id.to_s}, :set_properties => {:iteration => iteration2.id.to_s})
    assert !transition.available_to?(story1)
    story1.update_attributes(:cp_iteration => iteration1)
    assert transition.available_to?(story1)
    transition.execute(story1)
    assert_equal(iteration2.name, story1.cp_iteration.name)
  end
  
  # def test_filter_card_list_by_card_property
  #   iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
  #   iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
  #   @project.reload
  #   card1 = @project.cards.create!(:name => 'first card', :cp_iteration => iteration1, :card_type => @story_type)
  #   card2 = @project.cards.create!(:name => 'second card', :cp_iteration => iteration1, :card_type => @story_type)
  #   card3 = @project.cards.create!(:name => 'third card', :cp_iteration => nil, :card_type => @story_type)
  # 
  #   assert_filterout [card1, card2], "[iteration][is][#{iteration1.number}]"
  #   assert_filterout [card3], "[iteration][is][]"
  #   assert_filterout [card3], "[iteration][is not][#{iteration1.number}]"
  # end
  # 
  # def test_mql_average_query_works_with_card_property_definition
  #   iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
  #   iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
  #   @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1, :cp_size => '2')
  #   card2 = @project.cards.create!(:name => 'story2', :card_type => @story_type, :cp_iteration => iteration2, :cp_size => '4')
  #   assert_equal [iteration1.number_and_name, iteration2.number_and_name], CardQuery.parse("SELECT Iteration WHERE name in (story1, story2) order by iteration").single_values
  #   assert_equal 'story1', CardQuery.parse("SELECT name WHERE Iteration = 'iteration1'").single_value
  #   assert_equal_ignoring_spaces '<p>3</p>', 
  #     render("{{ average query: SELECT SUM(Size) WHERE Iteration IN ('iteration1', 'iteration2') GROUP BY Iteration }}", @project)
  # end
  # 
  # def test_mql_sub_query
  #   assert_equal_ignoring_spaces '<p>no values found</p>', 
  #     render("{{ average query: SELECT SUM(Size) WHERE Iteration IN (Select Iteration) GROUP BY Iteration }}", @project)
  #     
  #   iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
  #   @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1, :cp_size => '2')
  # 
  #   assert_equal_ignoring_spaces '<p>2</p>', 
  #     render("{{ average query: SELECT SUM(Size) WHERE Iteration IN (Select Iteration) GROUP BY Iteration }}", @project)
  # end
  # 
  # def test_mql_pie_chart_works_with_card_property_definition
  #   iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
  #   iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
  #   @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1, :cp_size => '2')
  #   @project.cards.create!(:name => 'story2', :card_type => @story_type, :cp_iteration => iteration2, :cp_size => '4')    
  #   @project.cards.create!(:name => 'story3', :card_type => @story_type, :cp_iteration => iteration2, :cp_size => '1')
  # 
  #   chart = Chart.extract(%{ 
  #     {{
  #       pie-chart
  #         data: SELECT Iteration, SUM(Size) WHERE Type = Story
  #     }} 
  #   }, 'pie', 1)
  #   assert_equal [[iteration1.number_and_name, 2], [iteration2.number_and_name, 5]], chart.data
  # end
  # 
  # def test_can_render_render_stack_bar_with_card_property_definition
  #   iteration1 = @project.cards.create!(:name => 'iteration1', :card_type => @iteration_type)
  #   iteration2 = @project.cards.create!(:name => 'iteration2', :card_type => @iteration_type)
  #   @project.cards.create!(:name => 'story1', :card_type => @story_type, :cp_iteration => iteration1, :cp_size => '2')
  #   @project.cards.create!(:name => 'story2', :card_type => @story_type, :cp_iteration => iteration2, :cp_size => '4')    
  #   @project.cards.create!(:name => 'story3', :card_type => @story_type, :cp_iteration => iteration2, :cp_size => '1')
  # 
  #   chart = Chart.extract(%{ {{
  #     stack-bar-chart
  #       cumulative  : true
  #       conditions  : type = Story
  #       series:
  #         - label       : Original
  #           color       : yellow
  #           combine     : total
  #           data        : >
  #             SELECT Iteration, SUM(Size) ORDER BY Iteration
  #   }} }, 'stack-bar', 1)
  #   
  #   assert_equal [iteration1.number_and_name, iteration2.number_and_name], chart.labels
  # end
  
  private
  def filtered_events(filters={})
    sql = HistoryFilters.new(@project, filters).to_sql
    ActiveRecord::Base.connection.select_all(sql)
  end
  
  def assert_filterout(expected_cards, filter)
    view = CardListView.find_or_construct(@project.reload, {:filters => ["[type][is][#{@story_type.name}]", filter]})
    assert_equal expected_cards.collect(&:name).sort, view.cards.collect(&:name).sort
  end
end
