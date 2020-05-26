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

class CardSelectorTest < ActiveSupport::TestCase
  def setup
    login_as_member
  end
  
  def test_should_return_cards_restrict_by_context_query_when_filter_with_empty_query
    with_first_project do |project|
      assert_equal [1], CardSelector.new(project, :context_mql => 'number=1').filter_by.collect(&:number)
    end
  end
  
  def test_should_return_no_cards_when_filter_by_negative_condition
    with_first_project do |project|
      assert_equal [], CardSelector.new(project, :context_mql => 'number=1').filter_by(CardQuery.parse('number!=1'))
    end
  end
  
  def test_filter_by_card_query_conditions
    with_first_project do |project|
      assert_equal [1], CardSelector.new(project, :context_mql => 'number=1').filter_by(CardQuery.parse('number=1').conditions).collect(&:number)
    end    
  end
  
  def test_should_be_all_cards_when_there_is_no_restrict_context_query
    with_first_project do |project|
      assert_sort_equal project.cards.collect(&:number), CardSelector.new(project).filter_by.collect(&:number)
    end
  end
  
  def test_card_types_should_be_project_card_types_when_no_card_type_specified_in_context_query
    with_first_project do |project|
      assert_sort_equal project.card_types.collect(&:name), CardSelector.new(project).card_types.collect(&:name)
    end
  end
  
  def test_should_restrict_card_types_by_query_context_condition
    with_first_project do |project|
      project.card_types.create!(:name => "story")
      project.card_types.create!(:name => "bug")
      assert_sort_equal ['Card', "story"], CardSelector.new(project, :context_mql => 'type = Card or type = story').card_types.collect(&:name)
    end
  end
  
  def test_should_support_pagination_to_filter_cards
    with_first_project do |project|
      assert_equal 1, CardSelector.new(project).filter_by(nil, :page => 1, :per_page => 1).size
    end
  end
  
  def test_should_be_able_to_restrict_cards_on_a_tree_by_context_mql
    with_three_level_tree_project do |project|
      card = create_card!(:name => 'not in the tree', :card_type_name => 'story')
      @cards = CardSelector.new(project, :context_mql => "FROM TREE #{project.tree_configurations.first.name.inspect} WHERE type=story").filter_by(nil)
      
      assert_sort_equal ["story2", "story1"], @cards.collect(&:name)
    end
  end
  
  def test_should_restrict_card_types_by_query_context_condition_within_a_tree
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project, :context_mql => "FROM TREE #{project.tree_configurations.first.name.inspect} WHERE type=story")
      assert_sort_equal ['story'], selector.card_types.collect(&:name)
    end    
  end
  
  def test_can_tell_card_type_filters_base_on_context_mql_implied_card_type_and_tree_configuration
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project, :context_mql => "from tree #{project.tree_configurations.first.name.inspect} where type=release or type=Card")
      assert_sort_equal ['release'], selector.card_type_filters.collect(&:value)
    end
  end
  
  def test_history_filter_should_use_card_id_card_value
    with_three_level_tree_project do |project|
      f.card('release1').update_attribute(:number, 10000)
      selector = selector_for_pd("Planning Release", :history_filter)
      assert_equal f.card('release1').id.to_s, selector.card_result_value(f.card('release1'))
    end
  end
  
  def test_interactive_filter_should_use_card_number_as_result_value
    with_three_level_tree_project do |project|
      f.card('release1').update_attribute(:number, 10000)
      selector = selector_for_pd("Planning Release", :filter)
      assert_equal f.card('release1').number.to_s, selector.card_result_value(f.card('release1'))
    end
  end
  
  def test_card_edit_should_use_card_id_as_result_value
    with_three_level_tree_project do |project|
      f.card('release1').update_attribute(:number, 10000)
      selector = selector_for_pd("Planning Release", :edit)
      assert_equal f.card('release1').id.to_s, selector.card_result_value(f.card('release1'))
    end
  end
  
  def test_context_for_filter_should_only_include_card_within_the_tree_but_edit_not
    with_three_level_tree_project do |project|
      card = create_card!(:name => 'release not in tree', :card_type => f.type("Release") )
      assert_not_include card, selector_for_pd("Planning Release", :filter).filter_by
      assert_not_include card, selector_for_pd("Planning Release", :history_filter).filter_by
      assert_include card, selector_for_pd("Planning Release", :edit).filter_by
    end    
  end
  
  def test_none_card_type_plv_context_should_not_support_card_selector
    with_first_project do |project|
      plv = create_plv!(project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE)
      assert !selector_for_plv(plv)
    end
  end
  
  def test_context_for_card_type_plv_without_type_constrain_should_imply_all_type
    with_three_level_tree_project do |project|
      card_plv = create_plv!(project, :name => 'Timmy', :data_type => ProjectVariable::CARD_DATA_TYPE)
      assert_sort_equal project.card_types.collect(&:name), selector_for_plv(card_plv).card_types.collect(&:name)
    end
  end
  
  def test_context_for_card_type_plv_with_type_constrain_should_imply_that_type
    with_three_level_tree_project do |project|
      card_plv = create_plv!(project, :name => 'Timmy', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => f.type('release'))
      assert_equal ["release"], selector_for_plv(card_plv).card_types.collect(&:name)
    end
  end
  
  def test_can_not_create_card_selector_with_card_type_definition
    with_three_level_tree_project do |project|
      assert !selector_for(CardTypeDefinition::INSTANCE, :edit)
    end    
  end
  
  def test_card_type_filters_should_be_the_type_if_there_is_only_one_card_type_implied_in_selector
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project, :context_mql => "type=release")
      assert_equal ['[Type][is][release]'], selector.card_type_filters.to_params
    end
  end
  
  def test_card_type_filters_should_empty_if_multi_types_implied_in_selector
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project, :context_mql => "type=release or type=iteration")
      assert_equal [], selector.card_type_filters.to_params
    end
  end
  
  include TreeFixtures::PlanningTree
  def test_select_card_for_filter_in_tree_whose_name_has_back_slash
    with_new_project do |project|
      tree_config = project.tree_configurations.create(:name => "hello \\ world")
      init_three_level_tree(tree_config)
      selector = selector_for_pd("Planning iteration", :filter)
      assert_sort_equal ['iteration1', 'iteration2'], selector.filter_by.collect(&:name)
    end
  end
  
  def test_translate_parent_constraint_to_filter
    with_three_level_tree_project do |project|
      release1 = f.card('release1')
      iteration1 = f.card('iteration1')
      selector = CardSelector.new(project, :context_mql => "type=story")
      filters = selector.to_filter({'Planning release' => release1.id.to_s, 'Planning iteration' => iteration1.id.to_s})
      assert_sort_equal ["story1", "story2"], selector.filter_by(filters.as_card_query).collect(&:name)
    end
  end
  
  def test_translate_empty_parent_constraint_to_filter
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project)
      filters = selector.to_filter(nil)      
      assert_sort_equal ["iteration1", "iteration2", "release1", "story1", "story2"], selector.filter_by(filters.as_card_query).collect(&:name)
    end
  end
  
  # bug 8261
  def test_to_filter_ignores_mixed_value
    with_three_level_tree_project do |project|
      release1 = f.card('release1')
      iteration1 = f.card('iteration1')
      selector = CardSelector.new(project, :context_mql => "type=story")
      
      filters = selector.to_filter('Planning release' => CardSelection::MIXED_VALUE, 'Planning iteration' => iteration1.id.to_s)
      assert_sort_equal ["story1", "story2"], selector.filter_by(filters.as_card_query).collect(&:name)
      
      filters = selector.to_filter('Planning release' => release1.id.to_s, 'Planning iteration' => CardSelection::MIXED_VALUE)
      assert_sort_equal ["story1", "story2"], selector.filter_by(filters.as_card_query).collect(&:name)
    end
  end
  
  def test_should_be_able_to_translate_parent_constraint_using_plv
    with_three_level_tree_project do |project|
      release1 = f.card('release1')
      current_release = create_plv!(project, 
        :name => 'current release', 
        :value => release1.id, 
        :card_type => f.type('release'), 
        :data_type => ProjectVariable::CARD_DATA_TYPE, 
        :property_definition_ids => [f.pd('Planning release').id])
        
      selector = CardSelector.new(project, :context_mql => "type=iteration")
      
      filter = selector.to_filter({'Planning release' => "(current release)"})
      assert_equal "[Planning release][is][(current release)]", filter.to_s
    end
    
  end
  
  private

  def f
    Finder.new(Project.current)
  end  
  
  def selector_for_pd(prop_def_name, action_type)
    selector_for(f.pd(prop_def_name), action_type)
  end
  
  def selector_for_plv(plv)
    selector_for(plv, :edit)
  end
  
  def selector_for(context_provider, action_type)
    CardSelector::Factory.create_card_selector(context_provider, action_type)
  end
  
end
