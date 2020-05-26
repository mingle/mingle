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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class XAxisLabelsTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  def setup
    @project = data_series_chart_project
    @project.activate
    login_as_admin
  end

  def test_x_axis_labels_should_be_labels_for_property_defintion
    project = first_project
    project.activate
    xlables = XAxisLabels.new(project.find_property_definition('Status'))
    assert_equal ['fixed', 'new', 'open', 'closed','in progress'], xlables.labels
  end

  def test_free_numeric_x_axis_labels_should_group_non_managed_numbers_without_consideration_of_precision
    xlabels =
    FreeNumericXAxisLabels.new(@project.find_property_definition('free number'))
    assert_equal ["2.0", "3.0", "4.0", "5"], xlabels.labels
  end

  def test_should_fill_in_gaps_between_dates_when_date_property_definition
    xlabels = DateXAxisLabels.new(@project.find_property_definition('Entered Scope On'),:date_format => @project.date_format)
    expected_labels = (Date.parse('2007-11-26')..Date.parse('2007-12-20')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, xlabels.labels()
  end

  def test_should_use_labels_query_if_available_while_fetching_x_labels
    labels_query = CardQuery.parse("Select DISTINCT 'Entered Scope On' where 'Entered Scope On' <= '04 Dec 2007'").order_and_group_by_first_column_if_necessary
    xlabels = DateXAxisLabels.new(@project.find_property_definition('Entered Scope On'),:date_format => @project.date_format, labels_query: labels_query)

    expected_labels = (Date.parse('2007-11-26')..Date.parse('2007-12-04')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, xlabels.labels()
  end

  def test_card_property_definition_labels_should_be_card_number_and_name
    with_three_level_tree_project do |project|
      xlabels = CardXAxisLabels.new(project.find_property_definition('planning iteration'), {})
      assert_equal ["#2 iteration1", "#3 iteration2"], xlabels.labels
    end
  end

  def test_card_property_definition_labels_should_be_restricted_by_x_labels_conditions
    with_three_level_tree_project do |project|
      xlabels = CardXAxisLabels.new(nil,:x_labels_conditions => "type = story")
      assert_equal ["#4 story1", "#5 story2"], xlabels.labels
    end
  end

  def test_tree_relationship_property_definition_should_restrict_by_card_type
    with_three_level_tree_project do |project|
      planning_release = project.find_property_definition("Planning release")
      xlabels = CardXAxisLabels.new(planning_release, :from_tree => 'three level tree')
      assert_equal ["#1 release1"], xlabels.labels
    end
  end

  def test_card_property_definition_labels_from_tree_should_be_restricted_by_tree_conditions
    with_three_level_tree_project do |project|
      login_as_admin
      create_card!(:name => "I'm not in tree")
      status = project.find_property_definition('status')
      xlabels = CardXAxisLabelsFromTree.new(status, {}, :from_tree => "three level tree")
      assert_equal ["release1",
                    "release1 > iteration1",
                    "release1 > iteration1 > story1",
                    "release1 > iteration1 > story2",
                    "release1 > iteration2"], xlabels.labels
    end
  end

  def test_card_property_definition_labels_should_be_restricted_by_x_labels_conditions
    with_three_level_tree_project do |project|
      login_as_admin
      create_card!(:name => "I'm not in tree")
      status = project.find_property_definition('status')
      xlabels = CardXAxisLabelsFromTree.new(status, {}, :from_tree => "three level tree", :x_labels_conditions => "type = story")
      assert_equal ["release1 > iteration1 > story1", "release1 > iteration1 > story2"], xlabels.labels
    end
  end

  def test_stack_bar_chart_should_restrict_by_labels_query
    with_three_level_tree_project do |project|
      login_as_admin
      related_card = project.find_property_definition('related card')
      iteration1 = project.cards.find_by_name('iteration1')

      card = create_card!(:name => "I am a story", :card_type => 'story')
      card.update_attribute(:cp_related_card_card_id, iteration1.id)

      labels_query = CardQuery.parse("SELECT 'related card'")
      xlabels = StackBarChartXAxisLabels.new(related_card, :labels_query => labels_query)
      assert_equal ["#2 iteration1", nil], xlabels.labels
    end
  end

  def test_stack_bar_chart_card_property_should_sort_name
    with_three_level_tree_project do |project|
      login_as_admin
      related_card = project.find_property_definition('related card')
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      iteration1.update_attribute(:number, 10)

      card = create_card!(:name => "I am a story", :card_type => 'story')
      card.update_attribute(:cp_related_card_card_id, iteration1.id)
      
      card2 = create_card!(:name => "I am another story", :card_type => 'story')
      card2.update_attribute(:cp_related_card_card_id, iteration2.id)      
      
      labels_query = CardQuery.parse("SELECT 'related card'")
      xlabels = StackBarChartXAxisLabelsCardPropertyDefintion.new(related_card, :labels_query => labels_query)
      assert_equal [nil, "#10 iteration1", "#3 iteration2"], xlabels.labels
    end
  end
  
  
  def test_stack_bar_chart_for_card_labels_should_restrict_by_labels_and_from_tree
    with_three_level_tree_project do |project|
      login_as_admin
      related_card = project.find_property_definition('related card')
      iteration1 = project.cards.find_by_name('iteration1')
      iteration4 = create_card!(:name => "I am iteration but not in the tree", :card_type => 'iteration')

      story1 = create_card!(:name => "I am story 1", :card_type => 'story')
      story1.update_attribute(:cp_related_card_card_id, iteration1.id)      
      story2 = create_card!(:name => "I am story 2", :card_type => 'story')
      story2.update_attribute(:cp_related_card_card_id, iteration4.id)
      planning_iteration = project.find_property_definition('planning iteration')
      labels_query = CardQuery.parse("SELECT 'related card'")
      xlabels = StackBarChartXAxisLabelsFromTree.new(planning_iteration, :labels_query => labels_query, :from_tree => "three level tree")
      assert_equal ["release1 > iteration1"], xlabels.labels
    end
  end
  
  def test_when_labels_query_finds_no_results_should_return_empty_labels
    with_three_level_tree_project do |project|
      login_as_admin
      planning_iteration = project.find_property_definition('planning iteration')
      query_with_no_results = CardQuery.parse("SELECT 'related card'")
      xlabels = StackBarChartXAxisLabelsFromTree.new(planning_iteration, :labels_query => query_with_no_results, :from_tree => "three level tree")
      
      assert_equal [], xlabels.labels
    end
  end
  
  def test_reformat_should_return_labels_as_default
    xlables = XAxisLabels.new(@project.find_property_definition('status'))
    assert_equal xlables.labels, xlables.reformat_values_from
  end

  def test_reformat_should_for_labels_using_from_tree
    with_three_level_tree_project do |project|
      login_as_admin
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      planning_iteration = project.find_property_definition('planning iteration')
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "three level tree", :@x_labels_conditions => "type=iteration")
      values = ["release1 > iteration1", "release1 > iteration2"]
      assert_equal ["##{iteration1.number} iteration1", "##{iteration2.number} iteration2"], xlabels.reformat_values_from(:x_labels_tree =>  "three level tree", :series_project => project)
    end
  end
  
  
  def test_should_differentiate_two_cards_with_same_name_when_reformat_values_for_from_tree
    with_three_level_tree_project do |project|
      login_as_admin
      
      tree = project.find_tree_configuration('three level tree')
      
      
      release1 = project.cards.find_by_name('release1')
      
      iteration_4 = create_card!(:name => 'iteration4', :card_type => 'iteration')
      another_iteration_4 = create_card!(:name => 'iteration4', :card_type => 'iteration')
      
      tree.add_child(another_iteration_4, :to => release1)
      
      story1 = create_card!(:name => "I am story 1", :card_type => 'story')
      story1.update_attribute(:cp_related_card_card_id, another_iteration_4.id)
      
      release_planning = project.find_property_definition('planning iteration')    
      
      labels_query = CardQuery.parse("SELECT 'related card'")
      
      xlabels = StackBarChartXAxisLabelsFromTree.new(release_planning, :labels_query => labels_query, :from_tree => "three level tree")
      
      assert_equal ["##{another_iteration_4.number} iteration4"], xlabels.reformat_values_from(:series_project => project, :x_labels_tree => tree.name)
    end
  end
  
  def test_xlabels_from_tree_should_work_when_card_in_tree_on_first_project_but_not_in_tree_in_other_project
    login_as_admin
    first_project = with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      tree = project.find_tree_configuration('three_level_tree')
      tree.remove_card project.cards.find_by_name('iteration2')
      project
    end
    with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      planning_iteration = project.find_property_definition('planning iteration')
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "three_level_tree")
      
      reformated_values = xlabels.reformat_values_from(:series_project => first_project, :x_labels_tree => 'three_level_tree')
      assert_equal ["##{iteration1.number} iteration1", "release1 > iteration2"], reformated_values
    end
  end
  
  def test_xlabels_should_use_specific_project_not_the_current_project
    login_as_admin
    planning_iteration = nil
    with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      planning_iteration = project.find_property_definition('planning iteration')
    end
    
    with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "three_level_tree")
      assert_equal ["release1 > iteration1", "release1 > iteration2"], xlabels.labels
    end
  end
  
  def test_reformat_date_str_from_another_project
    xlabels = DateXAxisLabels.new(@project.find_property_definition('Entered Scope On'),:date_format => @project.date_format)
    another_project = OpenStruct.new(:date_format => '%y %b %d')
    assert_equal '26 Nov 2007', xlabels.reformat_values_from(:another_project => another_project).first
  end
  
  def test_should_know_when_x_labels_tree_does_not_exist    
    with_three_level_tree_project do |project|
      planning_iteration = project.find_property_definition('planning iteration')
      assert_raise_message(XAxisLabelsError, /doesnt exist/) do
        CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "doesnt exist")
      end 
    end
  end  
  
  def test_should_retunr_values_when_the_tree_does_not_exist_in_the_series_project
    with_three_level_tree_project do |project|
      planning_iteration = project.find_property_definition('planning iteration')
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "three level tree")
      assert_equal ["release1 > iteration1", "release1 > iteration2"], xlabels.reformat_values_from(:series_project => project, :x_labels_tree => 'not exist tree name') 
    end
  end
  
  def test_labels_should_not_raise_error_when_there_is_no_any_cards_in_series_project
    with_new_project do |project|
      init_planning_tree_types
      configuration = project.tree_configurations.create(:name => 'planning tree')
      init_empty_planning_tree(configuration)
      planning_iteration = project.find_property_definition('planning iteration')
      
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "planning tree")
      assert_equal [], xlabels.labels
    end
  end
  
  # bugs 5825, 5826

  def test_labels_for_numeric_formula_should_be_in_ascending_order_and_in_string_format
    with_pie_chart_test_project do |project|
      project.cards.create!(:name => 'Buella', :cp_size => '10', :card_type_name => 'Card')
      formula_property_definition = project.find_property_definition('size_times_two')
      x_labels = FreeNumericXAxisLabels.new(formula_property_definition)
      assert_equal ['2', '4', '6', '20'], x_labels.labels
    end
  end

  def test_should_return_original_values_when_the_expanded_node_does_not_exist_in_the_series_project
    with_three_level_tree_project do |project|
      planning_iteration = project.find_property_definition('planning iteration')
      xlabels = CardXAxisLabelsFromTree.new(planning_iteration, {}, :from_tree => "three level tree")
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      tree_configuration.remove_card(project.cards.find_by_name('release1'))
      assert_equal ["release1 > iteration1", "release1 > iteration2"], xlabels.reformat_values_from(:series_project => project, :x_labels_tree => "three level tree")
    end
  end
end
