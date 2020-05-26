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
class CardTreeExpandingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_admin
    @project = filtering_tree_project
    @project.activate
    @configuration = @project.tree_configurations.find_by_name('filtering tree')
  end
  
  
  ##################################################################################################
  #   expand: release1
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                    ----- release1---                     release2
  #                   |                 |                        
  #              iteration1      iteration2                      
  #           
  ##################################################################################################
  def test_expand_single_first_level_node
    tree = @configuration.create_expanded_tree(numbers_of('release1'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('release2'), []
    assert_children tree.find_node_by_name('iteration1'), []
    assert_children tree.find_node_by_name('iteration2'), []
  end

  ##################################################################################################
  #   expand: release1, iteration1  
  #   result:                       ---------------Planning tree---------
  #                                |                                    |
  #                    ----- release1----                            release2
  #                   |                 |                         
  #              iteration1      iteration2                       
  #                  |                                            
  #               story1                                      
  ##################################################################################################
  def test_can_expand_different_level_nodes
    tree = @configuration.create_expanded_tree(numbers_of('release1', 'iteration1'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('release2'), []
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('story1'), []
  end
  
  ##################################################################################################
  #   expand: release1, iteration1, story1, task1
  #   resutl:                       ---------------Planning tree-----------------
  #                                |                                            |
  #                    ----- release1----                                   release2
  #                   |                 |   
  #              iteration1      iteration2                 
  #                  |                                      
  #           ---story1----                                 
  #          |           |
  #       task1   -----task2----
  #              |             |  
  #          minutia1       minutia2      
  #           
  ##################################################################################################
  def test_can_expand_to_deepest_level
    tree = @configuration.create_expanded_tree(numbers_of('release1', 'iteration1', 'story1', 'task2'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('release2'), []
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), ['minutia1', 'minutia2']
    assert_children tree.find_node_by_name('minutia1'), []
    assert_children tree.find_node_by_name('minutia2'), []
  end
  
  ##################################################################################################
  #   expand: release1, iteration1, story1, task1
  #   basequery : type != release
  #   resutl:                     
  #                               
  #                    ----- Planning tree---------------------------
  #                   |                     |        |              |
  #              iteration1           iteration2   iteration3    iteration4         
  #                  |                                      
  #           ---story1----                                 
  #          |           |
  #       task1   -----task2----
  #              |             |  
  #          minutia1       minutia2      
  #           
  ##################################################################################################
  def test_can_expand_with_basequery
    tree = @configuration.create_expanded_tree(numbers_of('release1', 'iteration1', 'story1', 'task2'), :base_query => CardQuery.parse('type != release'))
    assert_children tree.root, ['iteration1', 'iteration2', 'iteration3', 'iteration4']
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('iteration3'), []
    assert_children tree.find_node_by_name('iteration4'), []
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), ['minutia1', 'minutia2']
    assert_children tree.find_node_by_name('minutia1'), []
    assert_children tree.find_node_by_name('minutia2'), []
  end
  
  ##################################################################################################
  #                                 ---------------Planning tree---------
  #                                |                                   |
  #                           release1                            release2
  #                              |                                      
  #                           story1         
  ##################################################################################################
  
  def test_remove_middle_level
    tree = @configuration.create_expanded_tree(numbers_of('release1', 'iteration1'), :base_query => CardQuery.parse('type != iteration'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), ['story1']
    assert_children tree.find_node_by_name('release2'), []
    assert_children tree.find_node_by_name('story1'), []
  end
  
  ##################################################################################################
  #   expand: story1, task2
  #   resutl:                       ---------------Planning tree-----------------
  #                                |                                            |
  #                           release1                                     release2   
  ##################################################################################################
  def test_should_ignore_card_that_grandparent_is_not_in_the_tree
    tree = @configuration.create_expanded_tree(numbers_of('story1','task2'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), []
    assert_children tree.find_node_by_name('release2'), []
  end

  ##################################################################################################
  #   expand: task2
  #   resutl:                       ---------------Planning tree-----------------
  #                                |                                            |
  #                           release1                                     release2   
  ##################################################################################################
  def test_should_ignore_card_that_parent_is_not_in_the_tree
    tree = @configuration.create_expanded_tree(numbers_of('task2'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), []
    assert_children tree.find_node_by_name('release2'), []
  end
    
  ##################################################################################################
  #   expand: release1, release1
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                    ----- release1----                     release2
  #                   |                 |                        
  #              iteration1      iteration2                      
  #           
  ##################################################################################################
  def test_should_ignore_duplicated_expanded_node
    tree = @configuration.create_expanded_tree(numbers_of('release1','release1'))
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), ['iteration1','iteration2']
    assert_children tree.find_node_by_name('release2'), []
  end
  
  
  ##################################################################################################
  #   expand: nil, '22333'
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                            release1                        release2
  ##################################################################################################
  def test_should_ignore_card_not_exist
    not_in_tree_card = create_card!(:name => 'not in the tree')
    tree = @configuration.create_expanded_tree([nil, '22233'])
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), []
    assert_children tree.find_node_by_name('release2'), []
  end
  
  ##################################################################################################
  #   expand: not_in_the_tree
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                            release1                        release2
  ##################################################################################################
  def test_should_ignore_card_not_in_the_tree
    not_in_tree_card = create_card!(:name => 'not in the tree')
    tree = @configuration.create_expanded_tree([not_in_tree_card.number])
    assert_children tree.root, ['release1', 'release2']
    assert_children tree.find_node_by_name('release1'), []
    assert_children tree.find_node_by_name('release2'), []
  end
  
  ##################################################################################################
  #   expand: release1
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                    ----- release1----                     release2
  #                   |                 |                        
  #              iteration1      iteration2                      
  #           
  ##################################################################################################
  def test_can_tell_partial_tree_children_count
    tree = @configuration.create_expanded_tree(numbers_of('release1'))
    assert tree.find_node_by_name('release1').has_children?
    assert tree.find_node_by_name('release2').has_children?
    assert tree.find_node_by_name('iteration1').has_children?    
    assert !tree.find_node_by_name('iteration2').has_children?
  end
  
  ##################################################################################################
  #   expand: release1
  #   result:                       ---------Planning tree--------
  #                                |                              |
  #                    ----- release1(-)--                     release2(+)
  #                   |                 |                        
  #              iteration1(+)    iteration2()
  #           
  ##################################################################################################
  def test_can_tell_node_expanding_status
    tree = @configuration.create_expanded_tree(numbers_of('release1'))
    assert tree.find_node_by_name('release1').expanded?
    assert !tree.find_node_by_name('release2').expanded?
    assert !tree.find_node_by_name('iteration1').expanded?
    assert !tree.find_node_by_name('iteration2').expanded?
  end
  
  ##################################################################################################
  # root: release1
  # result : 
  #                    ----- release1----    
  #                   |                 |    
  #              iteration1      iteration2  
  ##################################################################################################
  def test_should_load_given_sub_tree
    release1 = @project.cards.find_by_name('release1')
    tree = @configuration.create_expanded_tree([], :root => release1)
    assert_children tree.root, ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('iteration1'), []
    assert_children tree.find_node_by_name('iteration2'), []  
  end
  
  ##################################################################################################
  # root: release1
  # expanded: iteration1, story1
  #
  # result:
  #                    ----- release1----              
  #                   |                 |              
  #              iteration1      iteration2            
  #                  |                                 
  #           ---story1----                            
  #          |           |
  #       task1       task2
  ##################################################################################################
  def test_should_load_given_subtree_with_expanded_nodes
    release1 = @project.cards.find_by_name('release1')
    tree = @configuration.create_expanded_tree(numbers_of('iteration1', 'story1'), :root => release1)
    assert_children tree.root, ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), []
  end
  
  ##################################################################################################
  # root: release1
  # expanded: iteration1, release2, iteration3,story1
  #
  # result:
  #                    ----- release1----              
  #                   |                 |              
  #              iteration1      iteration2            
  #                  |                                 
  #           ---story1----                            
  #          |           |
  #       task1       task2
  ##################################################################################################
  def test_should_load_given_subtree_and_ignore_expanded_nodes_which_are_not_in_it
    release1 = @project.cards.find_by_name('release1')
    tree = @configuration.create_expanded_tree(numbers_of('iteration1', 'release2', 'iteration3','story1'), :root => release1)
    assert_children tree.root, ['iteration1', 'iteration2']
    assert_children tree.find_node_by_name('iteration1'), ['story1']
    assert_children tree.find_node_by_name('iteration2'), []
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), []
  end
  
  ##################################################################################################
  # root: release1
  # expanded: story1
  # base query: 'Type != iteration'
  # result:
  #                 release1           
  #                   |                         
  #           ---story1----                           
  #          |           |                            
  #       task1        task2                      
  #           
  ##################################################################################################
  def test_should_load_subtree_with_given_expanded_nodes_and_base_query
    release1 = @project.cards.find_by_name('release1')
    tree = @configuration.create_expanded_tree(numbers_of('story1'), :root => release1, :base_query => CardQuery.parse('Type != iteration'))
    assert_children tree.root, ['story1']
    assert_children tree.find_node_by_name('story1'), ['task1', 'task2']
    assert_children tree.find_node_by_name('task1'), []
    assert_children tree.find_node_by_name('task2'), []
  end
  
  def test_subtree_naturally_has_one_level_expanded
    release1 = @project.cards.find_by_name('release1')
    tree = @configuration.create_expanded_tree([], :root => release1)
    assert tree.root.expanded?
    assert_children tree.root, ['iteration1', 'iteration2']
  end
  
  private
  
  def assert_children(parent, expected_children_name)
    assert_sort_equal expected_children_name, parent.children.collect(&:name)
  end  
end
