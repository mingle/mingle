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

class CardTreesHelperTest < ActiveSupport::TestCase
  include CardTreesHelper, TreeFixtures::PlanningTree, ActionView::Helpers::FormTagHelper, ActionView::Helpers::FormOptionsHelper
  
  
  def setup
    login_as_admin
    @project = create_project
    @tree_config = @project.tree_configurations.create(:name => 'Release tree')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    
    @iteration_size = setup_numeric_text_property_definition('iteration size')
    @story_size = setup_numeric_text_property_definition('story size')
    
    @type_iteration.add_property_definition(@iteration_size)
    @type_story.add_property_definition(@story_size)
  end
  
  def test_options_for_children
    assert_equal "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>", options_for_children(@type_iteration)
    assert_equal "<option value=\"\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\" selected=\"selected\">#{@iteration_size.name}</option>", options_for_children(@type_iteration, @iteration_size.id)
  end
  
  def test_options_for_children_include_hidden_properties
    @iteration_size.hidden = true
    @iteration_size.save!
    test_options_for_children
  end
  
  def test_options_for_descendants_include_hidden_properties
    @story_size.hidden = true
    @story_size.save!
    test_options_for_descendants
  end
  
  def test_options_for_descendants
    assert_equal "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>\n<option value=\"#{@story_size.id}\">#{@story_size.name}</option>", options_for_descendants([@type_iteration, @type_story])

    assert_equal "<option value=\"\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>\n<option value=\"#{@story_size.id}\" selected=\"selected\">#{@story_size.name}</option>", options_for_descendants([@type_iteration, @type_story], @story_size.id)
  end
  
  def test_aggregate_scopes
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      @type_story => {:position => 2}
    })
    @aggregate_property_definition = setup_aggregate_property_definition('release size', AggregateType::SUM, @story_size, @tree_config.id, @type_release.id, @type_iteration)
    
    expected_scopes = [["Choose a scope...", "Choose a scope..."], 
                       ['All descendants', nil], 
                       [@type_iteration.name, @type_iteration.id], 
                       [@type_story.name, @type_story.id], 
                       [AggregateScope::DEFINE_CONDITION, AggregateScope::DEFINE_CONDITION]]
    assert_equal expected_scopes, aggregate_scopes
  end
  
  def test_options_for_aggregrate_property_does_not_include_aggregate_properties
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      @type_story => {:position => 2}
    })
    sum_size = setup_aggregate_property_definition('sum size', AggregateType::SUM, @story_size, @tree_config.id, @type_release.id, @type_iteration)
    @type_iteration.add_property_definition(sum_size)
    
    @aggregate_property_definition = setup_aggregate_property_definition('release size', AggregateType::SUM, @story_size, @tree_config.id, @type_release.id, @type_iteration)
    assert_equal "<option value=\"\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>",
                 options_for_aggregate_property(@type_iteration, [@type_iteration, @type_story])

    @aggregate_property_definition.aggregate_scope = AggregateScope::ALL_DESCENDANTS
    @aggregate_property_definition.save!
    assert_equal "<option value=\"\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>\n<option value=\"#{@story_size.id}\" selected=\"selected\">#{@story_size.name}</option>", options_for_aggregate_property(@type_iteration, [@type_iteration, @type_story])
  end
  
  def test_options_for_descendants_do_not_include_date_formula_properties
    setup_date_property_definition('somedate')
    @formula_prop_def = setup_formula_property_definition('form prop def', 'somedate + 2')
    @type_story.add_property_definition(@formula_prop_def)
    test_options_for_descendants
  end
  
  def test_options_for_descendants_do_include_numeric_formula_properties
    @formula_prop_def = setup_formula_property_definition('form prop def', '1 + 2')
    @type_iteration.add_property_definition(@formula_prop_def)
    
    assert_equal "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>\n<option value=\"#{@formula_prop_def.id}\">#{@formula_prop_def.name}</option>\n<option value=\"#{@story_size.id}\">#{@story_size.name}</option>", options_for_descendants([@type_iteration, @type_story])
  end
  
  def test_options_for_children_do_not_include_date_formula_properties
    setup_date_property_definition('somedate')
    @formula_prop_def = setup_formula_property_definition('form prop def', 'somedate + 2')
    @type_story.add_property_definition(@formula_prop_def)
    test_options_for_children
  end
  
  def test_options_for_children_do_include_numeric_formula_properties
    @formula_prop_def = setup_formula_property_definition('form prop def', '1 + 2')
    @type_iteration.add_property_definition(@formula_prop_def)
    assert_equal "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">#{@iteration_size.name}</option>\n<option value=\"#{@formula_prop_def.id}\">#{@formula_prop_def.name}</option>", options_for_children(@type_iteration)
  end
  
  def test_selected_aggregate_scope
    params['aggregate_property_definition'] = {}
    params['aggregate_property_definition']['aggregate_scope_card_type_id'] = 10
    assert_equal 10, selected_aggregate_scope
    
    params['aggregate_property_definition']['aggregate_scope_card_type_id'] = 'Choose a scope...'
    assert_equal 'Choose a scope...', selected_aggregate_scope
    
    params['aggregate_property_definition']['aggregate_scope_card_type_id'] = nil
    assert_equal nil, selected_aggregate_scope
    
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      @type_story => {:position => 2}
    })
    
    @params = nil
    @aggregate_property_definition = setup_aggregate_property_definition('sum size', AggregateType::SUM, @story_size, @tree_config.id, @type_release.id, @type_iteration)
    assert_equal @type_iteration.id, selected_aggregate_scope
    
    @aggregate_property_definition.aggregate_condition = '1=1'
    assert_equal AggregateScope::DEFINE_CONDITION, selected_aggregate_scope
  end
  
  def test_type_id_to_child_options_map
    descendant_types = [@type_iteration, @type_story]
    
    expected_map = {}
    expected_map[@type_story.id] = "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@story_size.id}\">story size</option>"
    expected_map[@type_iteration.id] = "<option value=\"\" selected=\"selected\">What you want to aggregate...</option>\n<option value=\"#{@iteration_size.id}\">iteration size</option>"
    
    assert_equal expected_map, type_id_to_child_options_map(descendant_types)
  end
  
  def test_aggregate_description_should_not_be_html_escaped_in_aggregate_type_description
    aggregate_name_with_html_tag = '<h1>sum size</h1>'
    property_name_with_html_tag = '<h1>size</h1>'
    @story_size.update_attribute('name', property_name_with_html_tag)
    @tree_config.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      @type_story => {:position => 2}
    })
    aggregate_property_definition = setup_aggregate_property_definition(aggregate_name_with_html_tag, AggregateType::SUM, @story_size, @tree_config.id, @type_release.id, @type_iteration)
    assert_include(aggregate_name_with_html_tag, aggregate_description(aggregate_property_definition))
    assert_include(property_name_with_html_tag, aggregate_description(aggregate_property_definition))
  end
  
  def params
    @params ||= {}
  end
end


