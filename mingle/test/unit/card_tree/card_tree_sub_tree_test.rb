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


##################################################################################################
#                                 ---------------Planning tree---------
#                                |                                   |
#                    ----- release1----                     -----release2-----
#                   |                 |                    |                 |
#              iteration1      iteration2            iteration3          iteration4
#                  |                                      |
#           ---story1----                              story2        
#          |           |
#       task1   -----task2----
#              |             |  
#          minutia1       minutia2      
#           
##################################################################################################
class CardTreeSubTreeTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_admin
    @project = filtering_tree_project
    @project.activate
    @configuration = @project.tree_configurations.find_by_name('filtering tree')
  end
  
                                                                                 
  ###############################################################################
  #  root: release1                                                              
  #                                                                              
  #                    ----- release1----                                        
  #                   |                 |                                        
  #              iteration1      iteration2                                      
  #                  |                                                           
  #           ---story1----                                                      
  #          |           |                                                       
  #       task1   -----task2----                                                 
  #              |             |                                                 
  #          minutia1       minutia2                                             
  #                                                                              
  ###############################################################################
  def test_can_select_a_node_and_create_a_sub_tree_with_it_as_root_on_a_full_tree
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('release1'))
    assert_equal 'release1', tree.root.name
    assert_children tree.root, ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), ['minutia1', 'minutia2']
    assert_children tree.find_node_by_name('minutia1'), []
    assert_children tree.find_node_by_name('minutia2'), []
  end
  
  
  ###############################################################################
  #  root: story1                                                              
  #                                                                              
  #           ---story1----                                                      
  #          |           |                                                       
  #       task1   -----task2----                                                 
  #              |             |                                                 
  #          minutia1       minutia2                                             
  #                                                                              
  ###############################################################################
  def test_can_select_deeper_node_and_create_a_sub_tree_with_it_as_root_on_a_full_tree
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('story1'))
    assert_equal 'story1', tree.root.name
    assert_children tree.root, ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), ['minutia1', 'minutia2']
    assert_children tree.find_node_by_name('minutia1'), []
    assert_children tree.find_node_by_name('minutia2'), []
  end
  
  ###############################################################################
  #  root: task1                                                              
  #                                                                              
  #       task1                                                 
  ###############################################################################
  def test_select_leaf_node_should_return_one_node_tree
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('task1'))
    assert_equal 'task1', tree.root.name
    assert_children tree.root, []
  end
  
  def test_should_throw_not_in_tree_exception_if_selected_node_is_not_in_the_tree
    not_in_tree_card = create_card!(:name => 'not in the tree')
    assert_raise(CardTree::RootNotInTreeException){@configuration.create_tree(:root => not_in_tree_card)}
  end
  
  def test_should_throw_not_in_exception_if_selected_node_is_filtered_out_from_the_tree
    iteration1 = @project.cards.find_by_name('iteration1')
    assert_raise(CardTree::RootNotInTreeException){@configuration.create_tree(:root => iteration1, :base_query => CardQuery.parse('Type != iteration'))}
  end
  
  ##############################################################################
  #               release1                                                      
  #                  |                                                          
  #           ---story1----                                                     
  #          |           |                                                      
  #       task1   -----task2----                                                
  #              |             |                                                
  #          minutia1       minutia2                                            
  #                                                                             
  ##############################################################################
  def test_can_select_a_node_and_create_a_sub_tree_with_it_as_root_on_a_parital_tree
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('release1'), :base_query => CardQuery.parse('Type != iteration'))
    assert_equal 'release1', tree.root.name
    assert_children tree.root, ['story1']
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), ['minutia1', 'minutia2']
    assert_children tree.find_node_by_name('minutia1'), []
    assert_children tree.find_node_by_name('minutia2'), []
  end
  
  ##############################################################################
  #               release1                                                      
  #                  |                                                          
  #           ---story1----                                                     
  #          |           |                                                      
  #       task1   -----task2----                                                
  #              |             |                                                
  #          minutia1       minutia2                                            
  #                                                                             
  ##############################################################################
  def test_subtree_with_level_offset
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('release1'), :base_query => CardQuery.parse('Type != iteration'), :level_offset => 2)
    assert_equal 2, tree.root.level
    assert_equal 3, tree.find_node_by_name('story1').level
    assert_equal 4, tree.find_node_by_name('task1').level
    assert_equal 4, tree.find_node_by_name('task2').level
    assert_equal 5, tree.find_node_by_name('minutia1').level
    assert_equal 5, tree.find_node_by_name('minutia2').level
  end

  ##############################################################################
  #               release1                                                      
  #                  |                                                          
  #           ---story1----                                                     
  #          |           |                                                      
  #       task1   -----task2----                                                
  #              |             |                                                
  #          minutia1       minutia2                                            
  #                                                                             
  ##############################################################################  
  def test_sub_tree_all_card_count
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('release1'), :base_query => CardQuery.parse('Type != iteration'), :level_offset => 2)
    assert_equal 7, tree.root.full_tree_card_count
    assert_equal 4, tree.find_node_by_name('story1').full_tree_card_count
    assert_equal 0, tree.find_node_by_name('task1').full_tree_card_count
    assert_equal 2, tree.find_node_by_name('task2').full_tree_card_count
    assert_equal 0, tree.find_node_by_name('minutia1').full_tree_card_count
    assert_equal 0, tree.find_node_by_name('minutia2').full_tree_card_count
  end
  
  ##############################################################################
  #               release1                                                      
  #                  |                                                          
  #           ---story1----                                                     
  #          |           |                                                      
  #       task1   -----task2----                                                
  #              |             |                                                
  #          minutia1       minutia2                                            
  #                                                                             
  ##############################################################################  
  def test_sub_tree_all_card_count
    tree = @configuration.create_tree(:root => @project.cards.find_by_name('release1'), :base_query => CardQuery.parse('Type != iteration'), :level_offset => 2)
    assert_equal 5, tree.root.partial_tree_card_count
    assert_equal 4, tree.find_node_by_name('story1').partial_tree_card_count
    assert_equal 0, tree.find_node_by_name('task1').full_tree_card_count
    assert_equal 2, tree.find_node_by_name('task2').full_tree_card_count
    assert_equal 0, tree.find_node_by_name('minutia1').full_tree_card_count
    assert_equal 0, tree.find_node_by_name('minutia2').full_tree_card_count
  end
  
  
  private
  
  def assert_children(parent, expected_children_name)
    assert_sort_equal expected_children_name, parent.children.collect(&:name)
  end
end
