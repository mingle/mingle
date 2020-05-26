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
require File.expand_path(File.dirname(__FILE__) + '/quick_add_card_support')

class QuickAddCardMqlFilterTest < ActiveSupport::TestCase
  include QuickAddCardSupport, TreeFixtures::PlanningTree, TreeFixtures::FeatureTree
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_should_show_text_properties_based_on_filters
    with_new_project do |project|
      prop = setup_text_property_definition('any text')
      create_card!(:name => 'card 1', 'any text' => '1')
      create_card!(:name => 'card 2', 'any text' => '2')
      assert_equal ["any text"], build_quick_add_card_via_mql("'any text' is '1'").displayed_inherited_property_definitions.collect(&:name)
    end
  end

  def test_blank_mql_filter
    assert_equal @project.card_types.first.name, build_quick_add_card_via_mql("").card.card_type.name
  end

  def test_specify_one_card_type
    @project.card_types.create! :name => 'Story'
    @project.card_types.create! :name => 'Epic Story'
    assert_equal "Epic Story", build_quick_add_card_via_mql("Type = 'Epic Story'").card.card_type.name
    assert_equal "Epic Story", build_quick_add_card_via_mql("Type = 'Epic Story'").card.card_type_name
  end
  
  def test_specify_multiple_card_types
    @project.card_types.create! :name => 'story'
    assert_equal "story", build_quick_add_card_via_mql("Type IN (story, card)").card.card_type.name
  end

  def test_card_type_exclusions_with_NOT_IN
    @project.card_types.create! :name => 'excluded'
    @project.card_types.create! :name => 'story'
    assert_equal "story", build_quick_add_card_via_mql("NOT Type IN (card, excluded)").card.card_type.name
  end
  
  def test_card_type_exclusions_with_NOT_IN_mixing_with_IN
    @project.card_types.create! :name => 'story'
    assert_equal "story", build_quick_add_card_via_mql("Type IN (story) OR NOT Type IN (card)").card.card_type.name
  end
  
  def test_when_the_only_card_type_is_excluded_should_still_use_that_card_type
    assert_equal "Card", build_quick_add_card_via_mql("Type != card").card.card_type.name
    assert_equal "Card", build_quick_add_card_via_mql("NOT Type IN (card)").card.card_type.name
  end
  
  def test_should_use_session_choice_when_all_card_types_are_excluded
    @project.card_types.create! :name => 'bug'
    assert_equal "bug", build_quick_add_card_via_mql("NOT Type IN (card, bug)", :card_type_from_session => 'bug').card.card_type.name
  end

  def test_should_not_use_session_choice_when_card_types_applicable_includes_card_type_from_session
    @project.card_types.create! :name => 'bug'
    assert_equal "Card", build_quick_add_card_via_mql("Type is card or type is bug", :card_type_from_session => 'bug').card.card_type.name
  end

  def test_should_only_choose_card_type_applicable
    @project.card_types.create! :name => 'bug'
    assert_equal "bug", build_quick_add_card_via_mql("Type is bug", :card_type_from_session => 'card').card.card_type.name
  end

  def test_choose_first_card_type_when_specifying_only_predefined_properties
     assert_equal "Card", build_quick_add_card_via_mql("number > 10").card.card_type.name
  end
    
  def test_choose_first_card_type_of_first_property_used_when_no_card_type_specified
    with_new_project do |project|
      expected_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      expected_type.add_property_definition(story_only_property)
      story_only_property.save!
      assert_equal expected_type, build_quick_add_card_via_mql("story_only_property = 1").card.card_type
    end
  end
  
  def test_choose_first_card_type_when_no_card_type_specified_and_predefined_properties_are_used
    with_new_project do |project|
      expected_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      expected_type.add_property_definition(story_only_property)
      story_only_property.save!
      assert_equal expected_type, build_quick_add_card_via_mql("number = 123 OR story_only_property = 1").card.card_type
    end    
  end
  
  def test_choose_explicit_card_type_when_both_card_type_and_property_filter_used
    with_new_project do |project|
      story_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      story_type.add_property_definition(story_only_property)
      story_only_property.save!
      assert_equal "Card", build_quick_add_card_via_mql("story_only_property = 1 OR Type = Card").card.card_type.name
    end
  end

  def test_choose_type_from_filter_property_when_negated_card_type_and_property_filter_used
    with_new_project do |project|
      story_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      story_type.add_property_definition(story_only_property)
      story_only_property.save!
      assert_equal "story", build_quick_add_card_via_mql("story_only_property = 1 OR Type != Card").card.card_type.name
    end
  end

  def test_choose_first_card_type_when_property_card_type_is_explicitly_excluded
    with_new_project do |project|
      story_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      story_type.add_property_definition(story_only_property)
      story_only_property.save!
      assert_equal "Card", build_quick_add_card_via_mql("story_only_property = 1 OR Type != Story").card.card_type.name
    end
  end

  def test_choose_first_card_type_when_first_property_not_associated_with_any_card_type
    with_new_project do |project|
      story_type = setup_card_type project, 'story', :properties => []      
      project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      assert_equal "Card", build_quick_add_card_via_mql("story_only_property = 1").card.card_type.name
    end
  end

  def test_displaying_properties_should_show_definitions_used_in_query
    assert_equal ['Status'], build_quick_add_card_via_mql("status = fixed").displayed_inherited_property_definitions.map(&:name)
  end

  def test_displaying_properties_should_show_hidden_properties_used_in_mql
    @project.find_property_definition('Status').update_attribute :hidden, true
    assert_equal ["Status"], build_quick_add_card_via_mql("'Created On' = TODAY OR Status = New").displayed_inherited_property_definitions.map(&:name)
  end

  def test_displaying_properties_should_only_show_properties_for_inferred_card_type_that_are_used_in_mql
    with_new_project do |project|
      card_type  = project.card_types.find_by_name('Card')
      story_type = setup_card_type project, 'story', :properties => []      
      story_only_property = project.create_text_list_definition!(:name => 'story_only_property', :is_numeric => true)
      story_type.add_property_definition(story_only_property)
      story_type.save!
      card_only_property  = project.create_text_list_definition!(:name => 'card_only_property', :is_numeric => true)
      card_type.add_property_definition(card_only_property)
      card_type.save!

      assert_equal [], build_quick_add_card_via_mql("Type = Card OR story_only_property = 3").displayed_inherited_property_definitions
      assert_equal [card_only_property], build_quick_add_card_via_mql("card_only_property = 0 OR story_only_property = 3").displayed_inherited_property_definitions
    end
  end

  def test_displaying_properties_shows_properties_used_in_mql_or_that_have_default_values
    with_new_project do |project|
      card_type  = project.card_types.find_by_name('Card')
      size_property         = project.create_text_list_definition!(:name => 'size', :is_numeric => true)
      defaultvalue_property = project.create_text_list_definition!(:name => 'has_default_value', :is_numeric => true)
      card_type.add_property_definition(size_property)
      card_type.add_property_definition(defaultvalue_property)
      card_type.save!

      card_type.card_defaults.update_properties :has_default_value => 5
      
      assert_equal ['has_default_value'], build_quick_add_card_via_mql("Type = Card").displayed_inherited_property_definitions.map(&:name)
      assert_equal ['size', 'has_default_value'], build_quick_add_card_via_mql("size = 0").displayed_inherited_property_definitions.map(&:name)
    end
  end
  
  def test_displaying_properties_should_exclude_aggregate_properties
    with_new_project do |project|
      tree_config = project.tree_configurations.create(:name => 'Christmas')
      type_release, type_iteration, type_story = init_planning_tree_types
      init_three_level_tree(tree_config)
      size         = setup_numeric_property_definition('size', [1, 2, 3])
      release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, tree_config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      
      assert_equal [], build_quick_add_card_via_mql("'release size' = 3").displayed_inherited_property_definitions
    end
  end
  
  def test_displaying_properties_should_exclude_formula_properties
    with_new_project do |project|
      setup_date_property_definition('Start Date')
      setup_formula_property_definition('New Start Date', " 'Start Date' + 1")
      assert_equal [], build_quick_add_card_via_mql("'New Start Date' = TODAY").displayed_inherited_property_definitions
    end
  end
  
  def test_displaying_properties_should_include_tree_relationship_properties_in_tree_of_FROM_TREE
    with_three_level_tree_project do |project|
      tree       = project.tree_configurations.first
      quick_card = build_quick_add_card_via_mql("FROM TREE '#{tree.name}'")
      assert_equal "story", quick_card.card.card_type_name
      assert_equal ["Planning iteration", "Planning release"], quick_card.displayed_inherited_property_definitions.map(&:name).sort
    end
  end

  def test_displaying_properties_should_include_tree_relationship_properties_in_mql
    with_new_project do |project|
      init_planning_tree_types
      init_three_level_tree(project.tree_configurations.create(:name => 'Planning Tree'))
      
      init_feature_tree_types
      init_three_level_feature_tree(project.tree_configurations.create!(:name => 'Feature Tree'))
      quick_card = build_quick_add_card_via_mql("'Planning iteration'= Number 123 OR 'System breakdown module' = Number 456")
      assert_equal "story", quick_card.card.card_type_name
      assert_equal ["Planning iteration", "Planning release", "System breakdown module"], quick_card.displayed_inherited_property_definitions.map(&:name).sort
    end
  end

  def test_prepopulate_property_values_when_there_are_card_defaults
    card_type = @project.card_types.first
    card_type.card_defaults.update_properties :status => 'New', :priority => 'low', :unused => nil
    quick = build_quick_add_card_via_mql("Type is #{card_type.name}")
    assert_equal %w(Priority Status), quick.displayed_inherited_property_definitions.map(&:name).sort
    card = quick.card
    assert_equal 'new', card.cp_status
    assert_equal 'low', card.cp_priority
    assert_nil card.cp_unused
  end

  def test_prepopulate_tags
    assert_equal 'foo', build_quick_add_card_via_mql("TAGGED WITH 'foo'").card.tag_summary
  end

  def test_prepopulate_tags_should_include_all_tags_in_OR_or_AND
    assert_equal %w(bar foo), build_quick_add_card_via_mql("TAGGED WITH 'foo' OR TAGGED WITH 'bar'").card.tags.map(&:name).sort
    assert_equal %w(bar foo), build_quick_add_card_via_mql("TAGGED WITH 'foo' AND TAGGED WITH 'bar'").card.tags.map(&:name).sort
  end
  
  def test_prepopulate_tags_should_not_include_not_tagged_with
    assert_equal '', build_quick_add_card_via_mql("NOT TAGGED WITH 'foo'").card.tag_summary
  end
  
  def test_filter_value_should_override_card_default_for_tree_properties
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      init_three_level_tree(project.tree_configurations.create(:name => 'Planning Tree'))
      type_story.card_defaults.update_properties "planning iteration" => project.cards.find_by_name("iteration1")
      quick_card = build_quick_add_card_via_mql("Type is Story and 'Planning release'= Number 123")
      assert_equal ["Planning release"], quick_card.displayed_inherited_property_definitions.map(&:name).sort
    end
  end
end
