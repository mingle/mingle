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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')
require 'card_trees_controller'

class CardTreesControllerAggregateTest < ActionController::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper
  
  def setup
    @controller = create_controller CardTreesController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @project = create_project
    @tree_configuration = @project.tree_configurations.create(:name => 'Release tree')
    @first_id = @tree_configuration.id
    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end
  
  def test_create_aggregate_property_definition_computes_aggregates
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')
    
    post :create_aggregate_property_definition, :id => @tree_configuration.id, :project_id => @project.identifier,
         :aggregate_property_definition => {:name => 'count of cards', :aggregate_type => AggregateType::COUNT,
           :aggregate_scope => AggregateScope::ALL_DESCENDANTS, :aggregate_card_type_id => @type_release.id, :tree_configuration_id => @tree_configuration.id }
    AggregateComputation.run_once
    count_of_cards = @project.reload.find_property_definition('count of cards')
    assert_equal 4, count_of_cards.value(release1.reload)
  end
  
  def test_update_aggregate_property_definition_recomputes_aggregate
    init_three_level_tree(@tree_configuration)
    size = setup_numeric_text_property_definition('size')
    @type_story.add_property_definition(size)
    
    release1 = @project.cards.find_by_name('release1')
    story2 = @project.cards.find_by_name('story2')
    
    size.update_card(story2, '10')
    story2.save!
    
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @tree_configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    release_size.update_cards
    AggregateComputation.run_once
    assert_equal 10, release_size.value(release1.reload)
    
    post :update_aggregate_property_definition, :id => release_size.id, :project_id => @project.identifier, 
         :aggregate_property_definition => {:name => 'new name', :aggregate_type => AggregateType::COUNT}
    AggregateComputation.run_once
    assert_equal 4, release_size.value(release1.reload)
  end
  

end
