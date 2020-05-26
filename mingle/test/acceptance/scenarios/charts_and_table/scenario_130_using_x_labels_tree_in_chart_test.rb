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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')  

#Tags: chart, tree

class Scenario130UsingXLabelsTreeInChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  RELEASE = "Release"
  ITERATION = "Iteration"
  STORY = "Story"
  PLANNING_TREE= "Planning tree"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)  
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_one = create_project(:prefix => 'scenario_130', :users => [users(:proj_admin)])
    @project_two = create_project(:prefix => 'project_two', :users => [users(:proj_admin)])

    login_as_admin_user
  end

  # bug 6377
  def test_using_x_labels_tree_can_chart_across_trees_in_different_project   
    one_placeholder_to_make_card_num_different_in_two_projects= create_cards(@project_one, 1)
    setup_planning_tree_in_projects(@project_one, @project_two)
    add_cards_to_planning_tree(@project_one,2,2,true)
    add_cards_to_planning_tree(@project_two,2,2,false)

    open_project(@project_one)    
    content_with_x_labels_tree = generate_macro_content_for_data_series_chart_with_two_series(:render_as_text => true, :x_labels_tree => "#{PLANNING_TREE}", :label_1 => "project one", :label_2 => "project two", 
    :project_1 => @project_one.identifier, :project_2 => @project_two.identifier, :data_query_1 => "SELECT iteration, count(*) WHERE type=story", :data_query_2 => "SELECT iteration, count(*) WHERE type=story", :cumulative => false)
    add_macro_and_save_on(@project_one, content_with_x_labels_tree, :render_as_text => true)
    assert_chart('x_labels', "release 1 &gt; iteration 1,release 1 &gt; iteration 2,release 2 &gt; iteration 1,release 2 &gt; iteration 2")
    assert_chart('data_for_project one', "1,2,3,4")
    assert_chart('data_for_project two', "4,3,2,1")  
  end

  def test_using_x_labels_tree_can_smart_sort_card_name_for_x_label
    setup_planning_tree_in_projects(@project_one)
    add_cards_to_planning_tree(@project_one,1,10,true)
    open_project(@project_one)
    add_data_series_chart_and_save_on_overview_page(:x_labels_tree => PLANNING_TREE, :property  => "Iteration", :aggregate  => "count(*)", :render_as_text => true, :conditions  => 'type = story', :project => @project_one)
    assert_chart('x_labels', "release 1 &gt; iteration 1,release 1 &gt; iteration 2,release 1 &gt; iteration 3,release 1 &gt; iteration 4,release 1 &gt; iteration 5,release 1 &gt; iteration 6,release 1 &gt; iteration 7,release 1 &gt; iteration 8,release 1 &gt; iteration 9,release 1 &gt; iteration 10")   
  end



  private 
  def setup_planning_tree_in_projects(*projects)
    for project in projects do
      release_type = setup_card_type(project, RELEASE)
      iteration_type = setup_card_type(project, ITERATION)
      story_type = setup_card_type(project, STORY)
      project.reload.activate
      tree = setup_tree(project, PLANNING_TREE, :types => [release_type, iteration_type, story_type], :relationship_names => ["Release", "Iteration"])       
    end
  end

  # this method is used to add cards to tree, if increase_numbers_of_stories == true, then, the stories numbers of different iteration would be 1,2,3.....
  # otherwise, it would be ....3,2,1
  def add_cards_to_planning_tree(project, how_many_releases, how_many_iterations_per_release, increase_numbers_of_stories = true)
    story_type = project.card_types.find_by_name(STORY)
    iteration_type = project.card_types.find_by_name(ITERATION)
    release_type = project.card_types.find_by_name(RELEASE)
    tree = project.tree_configurations.find_by_name(PLANNING_TREE) 

    how_many_iterations = how_many_iterations_per_release * how_many_releases

    releases = create_cards(project, how_many_releases, :card_type => release_type, :card_name => 'release')
    release_index_max = how_many_releases - 1
    0.upto(release_index_max) do |release_index|
      add_card_to_tree(tree, releases[release_index])
      iterations = create_cards(project, how_many_iterations_per_release, :card_type => iteration_type, :card_name => 'iteration') 
      iteration_index_max = how_many_iterations_per_release - 1
      0.upto(iteration_index_max) do |iteration_index|
        add_card_to_tree(tree, iterations[iteration_index], releases[release_index])
        story_index_max = iteration_index + how_many_iterations_per_release * release_index
        story_index_max = how_many_iterations - (iteration_index + how_many_iterations_per_release * release_index) - 1 if increase_numbers_of_stories == false 
        stories = create_cards(project, story_index_max + 1, :card_type => story_type)                 
        0.upto(story_index_max) do |story_index|
          add_card_to_tree(tree, stories[story_index], iterations[iteration_index])           
        end
      end            
    end
  end

end
