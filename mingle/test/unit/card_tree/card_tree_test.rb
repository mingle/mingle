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

##################################################################
#                       Planning tree
#                            |
#                    ----- release1----  
#                   |                 |
#            ---iteration1----    iteration2
#           |                |
#       story1            story2        
#            
##################################################################
class CardTreeTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    login_as_admin
    @project = three_level_tree_project
    @project.activate
    @configuration = @project.tree_configurations.find_by_name('three level tree')
    @type_release, @type_iteration, @type_story = find_planning_tree_types
    @tree = CardTree.new(@configuration, {})
  end
  
  def setup_created_project_tree
    @project = create_project
    @configuration = @project.tree_configurations.create(:name => 'Planning')    
    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end
  
  def test_find_node_by_name
    story1 = @tree.find_node_by_name('story1')
    iteration1 = @tree.find_node_by_name('iteration1')
    assert_equal iteration1, story1.parent
    assert_nil @tree.find_node_by_name('no exist')
  end  
    
  def test_root_name_should_be_samed_with_tree_name
    assert_equal 'three level tree', @tree.root.name
  end
  
  def test_should_load_correct_children_when_load_nodes
    assert_equal 1, @tree.root.children.size
    assert_equal 2, @tree.find_node_by_name('release1').children.size
    assert_equal 2, @tree.find_node_by_name('iteration1').children.size
    assert_equal 0, @tree.find_node_by_name('iteration2').children.size
    assert_equal 0, @tree.find_node_by_name('story1').children.size
    assert_equal 0, @tree.find_node_by_name('story2').children.size
  end
  
  def test_should_set_parent_when_load_nodes
    release1 = @tree.find_node_by_name('release1')
    assert_equal @tree.root, release1.parent
    iteration1 = @tree.find_node_by_name('iteration1')
    assert_equal release1, iteration1.parent
    story1 = @tree.find_node_by_name('story1')
    assert_equal iteration1, story1.parent
  end
  
  def test_each_decendants_should_go_through_all_nodes
    iteration1 = @tree.find_node_by_name('iteration1')
    result = []
    iteration1.each_descendant { |node| result << node.name  }
    assert_sort_equal ['iteration1', 'story1', 'story2'], result
  end

  def test_decendants_should_go_through_all_nodes
    iteration1 = @tree.find_node_by_name('iteration1')
    assert_equal ['story1', 'story2'], @tree.find_node_by_name('iteration1').descendants.collect(&:name).smart_sort
    release1 = @tree.find_node_by_name('release1')
    assert_equal ['iteration1', 'iteration2', 'story1', 'story2'], release1.descendants.collect(&:name).smart_sort
  end

  def test_nodes_load_should_not_depending_on_add_to_tree_order
    setup_created_project_tree
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'release'}, 
      @type_iteration => {:position => 1, :relationship_name => 'iteration'}, 
      @type_story => {:position => 2}
    })
    s1 = @configuration.add_child(create_card!(:name => 'story1', :card_type => @type_story), :to => :root)
    i1 = @configuration.add_child(create_card!(:name => 'iteration1', :card_type => @type_iteration), :to => :root)
    r1 = @configuration.add_child(create_card!(:name => 'release1', :card_type => @type_release), :to => :root)
    @configuration.add_child(i1, :to => r1)
    @configuration.add_child(s1, :to => i1)
    tree = @configuration.create_tree
    assert_name_equal i1, tree.find_node_by_name('story1').parent
  end 
  
  def test_nodes_should_be_in_left_first_order
    setup_created_project_tree
    tree = init_planning_tree_with_multi_types_in_levels(@configuration)
    
    expected_node_levels = {"story5"=>1, "iteration1"=>2, "iteration2"=>1, "story1"=>3, "story2"=>3, "Planning"=>0, "story3"=>2, "story4"=>2, "release1"=>1}
    actual_node_levels = tree.nodes.inject({}) { |res, node| res[node.name] = node.level; res }
    
    assert_equal expected_node_levels, actual_node_levels
  end
  
  def test_each_node_knows_its_card_count
    setup_created_project_tree
    tree = init_planning_tree_with_multi_types_in_levels(@configuration)
    
    expected_node_card_counts = {"story5"=>0, "iteration1"=>2, "iteration2"=>1, "story1"=>0, "story2"=>0, "Planning"=>8, "story3"=>0, "story4"=>0, "release1"=>4}
    actual_node_card_counts = tree.nodes.inject({}) { |res, node| res[node.name] = node.partial_tree_card_count; res }

    assert_equal expected_node_card_counts, actual_node_card_counts
  end
  
  def test_card_count_should_only_include_cards_in_base_query
    with_filtering_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('filtering tree')
      conditions = TreeFilters.new(project, {:excluded => ['iteration', 'story', 'task', 'minutia']}, tree_configuration).as_card_query_conditions
      tree = tree_configuration.create_tree(:base_query => CardQuery.new(:conditions => conditions))
      
      assert_equal [2, 0, 0], tree.nodes.collect(&:partial_tree_card_count)
    end
  end
  
  def test_node_should_respond_to_xml
    setup_created_project_tree
    tree = init_planning_tree_with_multi_types_in_levels(@configuration)
    story3 = tree.find_node_by_name('story3')
    assert story3.respond_to?(:to_xml)
  end   
    
  def test_node_to_json_not_including_children
    iteration1 = @tree.find_node_by_name('iteration1').to_json({:exclude_children => true}).json_to_hash
    assert_equal 'iteration1', iteration1[:name]
    assert_equal [], iteration1[:children]
  end
  
  def test_multi_level_tree_to_json
    # '{name: "Planning", children: 
    #      [{name: "release1", children: 
    #           [{name: "iteration1", children: 
    #               [{name: "story1", children: [], number: 4, html_id: "card_475"}, 
    #               {name: "story2", children: [], number: 5, html_id: "card_476"}], number: 2, html_id: "card_473"}, 
    #           {name: "iteration2", children: [], number: 3, html_id: "card_474"}], number: 1, html_id: "card_472"}], number: 0, html_id: "node_0"}'

    structure = @tree.to_json.json_to_hash
    release1 = structure[:children].first
    iteration1 = release1[:children].detect { |c| c[:name] == 'iteration1' }

    assert_equal 'three level tree', structure[:name]
    assert_equal 0, structure[:number]
    assert_equal 1, structure[:children].size
    assert_equal 'release1', release1[:name]
    assert_equal ['iteration1', 'iteration2'], release1[:children].collect { |c| c[:name] }.sort
    assert_equal ['story1', 'story2'], iteration1[:children].collect { |c| c[:name] }.sort
  end
  
  def test_to_json_should_respect_tree_order
    @configuration.add_child(create_card!(:name => 'story11', :card_type => @type_story), :to => :root)
    @configuration.add_child(create_card!(:name => 'story12', :card_type => @type_story), :to => :root)
    @configuration.add_child(create_card!(:name => 'story13', :card_type => @type_story), :to => :root)
    @configuration.add_child(create_card!(:name => 'story14', :card_type => @type_story), :to => :root)
    @tree = CardTree.new(@configuration, :order_by => [CardQuery::Column.new('name', 'DESC')])
    structure = @tree.to_json.json_to_hash
    assert_equal ["story14", "story13", "story12", "story11", "release1"], structure[:children].collect { |c| c[:name] }
    assert_equal @tree.root.children.collect(&:name), structure[:children].collect { |c| c[:name] }
  end
  
  def test_to_json_should_tell_nodes_descendant_count
    iteration1 = @tree.find_node_by_name('iteration1').to_json(:include_descendant_count => true).json_to_hash
    assert_equal 2, iteration1[:descendantCount]
    
    release1 = @tree.find_node_by_name('release1').to_json(:include_descendant_count => true).json_to_hash
    iteration1 = release1[:children].detect{ |hash| hash[:name] == 'iteration1' }
    assert_equal 2, iteration1[:descendantCount]
    
    root = @tree.to_json(:include_descendant_count => true).json_to_hash
    assert_equal 5, root[:descendantCount]
  end
  
  def test_to_json_should_tell_nodes_acceptable_child_card_types
    iteration1 = @tree.find_node_by_name('iteration1').to_json.json_to_hash
    assert_equal [@type_story.html_id], iteration1[:acceptableChildCardTypes]
    root = @tree.to_json.json_to_hash
    assert_equal [@type_release.html_id, @type_iteration.html_id, @type_story.html_id], root[:acceptableChildCardTypes]

    release1 = root.to_json.json_to_hash[:children].first
    assert_sort_equal [@type_story.html_id, @type_iteration.html_id], release1[:acceptableChildCardTypes]
    
    iteration2 = release1[:children].detect{|card_node_hash| card_node_hash[:name] == 'iteration2'}
    assert_equal [@type_story.html_id], iteration2[:acceptableChildCardTypes]
  end
  
  def test_should_be_able_select_a_partial_tree_base_on_one_card_query
    setup_created_project_tree
    init_planning_tree_with_multi_types_in_levels(@configuration)
    query = CardQuery.new(:conditions => CardQuery::ExplicitIn.new(CardQuery::Column.new('Name'), ['iteration1', 'story1']))
    
    tree = @configuration.create_tree(:base_query => query)
    assert_equal ['iteration1'], tree.root.children.collect(&:name)
    assert_equal ['story1'], tree.find_node_by_name('iteration1').children.collect(&:name)
  end
  
  def test_each_breadth_first_descendant
    release1 = @project.cards.find_by_name('release1')
    descendants = []
    @tree.find_node_by_card(release1).each_breadth_first_descendant { |descendant| descendants << descendant }
    assert_sort_equal ['iteration1', 'iteration2', 'story1', 'story2'], descendants.collect(&:name)
  end
  
  def test_root_should_know_when_it_has_children
    assert @tree.root.has_children?
  end
  
  def test_root_should_know_when_it_does_not_have_children
    with_new_project do |project| 
      release, iteration, story = ['release', 'iteration', 'story'].collect { |card_type_name| project.card_types.create(:name => card_type_name) }
      tree = setup_tree(project, 'ris', :types => [release, iteration, story], :relationship_names => ['ris-release', 'ris-iteration'])
      empty_tree = tree.create_tree
      assert !empty_tree.root.has_children?
    end
  end
  
  def test_card_nodes_know_if_they_have_children
    ['release1', 'iteration1'].each { |card_name| assert @tree.find_node_by_name(card_name).has_children?, "#{card_name} should have children" }
    ['iteration2', 'story1', 'story2'].each { |card_name| assert !@tree.find_node_by_name(card_name).has_children? }
  end
  
  def test_partial_tree_without_middle_type_level_should_attach_nodes_to_their_grand_parents
    tr = CardTree.new(@configuration, {:base_query => CardQuery.parse("Type != '#{@type_iteration.name}'")})
    assert_name_equal tr.root, tr['release1'].parent
    assert_name_equal tr['release1'], tr['story1'].parent
    assert_name_equal tr['release1'], tr['story2'].parent
  end
  
  def test_card_nodes_should_keep_position_when_tree_initialized
    tree = CardTree.new(@configuration, {:order_by => [CardQuery::Column.new('name')]})
    assert_equal ['iteration1','iteration2'], tree.root.children.first.children.sort_by(&:position).collect(&:name)    
    tree = CardTree.new(@configuration, {:order_by => [CardQuery::Column.new('name', 'DESC')]})
    assert_equal ['iteration2','iteration1'], tree.root.children.first.children.sort_by(&:position).collect(&:name)
  end
  
  def test_sorted_children
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration2 = @project.cards.find_by_name('iteration2')
    
    tree = CardTree.new(@configuration, {})
    assert_equal [iteration2, iteration1], tree.root.children.first.children
    
    tree = CardTree.new(@configuration, {:order_by => [CardQuery::Column.new('number')]})
    assert_equal [iteration1, iteration2].collect(&:number), tree.root.children.first.children.collect(&:number)      
    
    tree = CardTree.new(@configuration, {:order_by => [CardQuery::Column.new('number', 'DESC')]})
    assert_equal [iteration2, iteration1], tree.root.children.first.children
  end
  
  def test_node_level_should_be_path_lenght_to_root
    tree = CardTree.new(@configuration, {})
    assert_equal 0, tree.card_level(:root)
    assert_equal 1, tree.card_level(@project.cards.find_by_name('release1'))
    assert_equal 3, tree.card_level(@project.cards.find_by_name('story1'))
  end
  
  def test_should_add_level_offset_to_each_nodes_level
    tree = CardTree.new(@configuration, {:level_offset => 2})
    assert_equal 2, tree.root.level
    assert_equal 3, tree.find_node_by_name('release1').level
    assert_equal 4, tree.find_node_by_name('iteration1').level
    assert_equal 5, tree.find_node_by_name('story1').level
  end
end
