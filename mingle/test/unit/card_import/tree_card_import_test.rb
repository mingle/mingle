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

class TreeCardImportTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, TreeFixtures::FeatureTree, CardImporterTestHelper
  
  self.use_transactional_fixtures = false
  
  def setup
    login_as_member
  end
  
  def test_existing_card_should_be_added_to_the_tree_if_card_trees_column_has_value
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      story = create_card!(:name => 'story3', :card_type => project.card_types.find_by_name('story'))
      assert !configuration.include_card?(story)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story.number}\tstory3\t\tstory\tyes\t\t
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      assert configuration.reload.include_card?(story)
    end
  end  
  
  def test_should_not_add_card_to_tree_if_tree_not_choosed
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      story = create_card!(:name => 'story3', :card_type => project.card_types.find_by_name('story'))
      assert !configuration.include_card?(story)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story.number}\tstory3\t\tstory\tno\t\t
      CSV
      import(import_content)
      
      assert !configuration.reload.include_card?(story)
    end
  end  
  
  def test_new_card_should_be_added_to_the_tree_if_card_trees_column_has_value
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      import_content = <<-CSV
        Name\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        story3\t\tstory\tyes\t\t
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story = project.reload.cards.find_by_name('story3')
      assert configuration.reload.include_card?(story)
    end
  end
  
  def test_should_add_to_correct_position_on_tree_if_relationship_columns_has_value
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      
      import_content = <<-CSV
        Name\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        story3\t\tstory\tyes\t##{iteration1.number}\t##{release1.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story3 = project.reload.cards.find_by_name('story3')
      assert configuration.contains?(iteration1, story3)
      assert configuration.contains?(release1, story3)
    end    
  end
  
  # bug 5462
  def test_should_new_card_to_correct_position_on_tree_if_even_if_the_type_is_used_in_transition_and_with_not_set_value
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      make_as_project_first_card_type(project, 'release')
      release1 = project.cards.find_by_name('release1')
      create_transition(project, 'remove from scope', :set_properties => { "Planning Release" => nil})
      
      import_content = <<-CSV
        Name\tDescription\tType\tPlanning\tPlanning release\tPlanning iteration
        iteration30\t\tIteration\tyes\t##{release1.number}\t
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      iteration30 = project.reload.cards.find_by_name('iteration30')
      assert configuration.contains?(release1, iteration30)
    end    
  end
  
  
  def test_existing_card_should_change_to_correct_position_on_tree_if_relationship_columns_has_value
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      release1 = project.cards.find_by_name('release1')
      story2 = project.cards.find_by_name('story2')
      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story2.number}\tstory2\t\tstory\tyes\t##{iteration2.number}\t##{release1.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story2.reload
      assert !configuration.contains?(iteration1, story2)
      assert configuration.contains?(iteration2, story2)
      assert configuration.contains?(release1, story2)
    end    
  end
  
  def test_import_card_tree_with_multipule_types
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        10\trelease2\t\trelease\tyes\t\t
        11\titeration3\t\titeration\tyes\t\t#10
        12\tstory3\t\tstory\tyes\t#11\t#10
        13\tstory4\t\tstory\tyes\t#11\t#10
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      tree = configuration.create_tree
      release2 = tree.find_node_by_name('release2')
      assert_equal 'release2', release2.name
      iteration3 = release2.children.first
      assert_equal ['story3', 'story4'], iteration3.children.collect(&:name).sort
    end  
    
  end
  
  def test_should_add_to_correct_position_on_tree_if_tree_relationship_was_changed
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        111\trelease2\t\trelease\tyes\t\t
        #{iteration1.number}\titeration1\t\titeration\tyes\t\t#111
        #{story1.number}\tstory1\t\tstory\tyes\t##{iteration1.number}\t#111
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      project.reload
      release2 = project.cards.find_by_name('release2')
      iteration1.reload
      story1.reload

      assert configuration.contains?(release2, iteration1)
      assert configuration.contains?(iteration1, story1)
    end    
  end
  
  def test_should_ignore_all_tree_columns_if_there_is_no_tree_choosed_for_import
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        111\trelease2\t\trelease\tyes\t\t\tPlanning
        #{iteration1.number}\titeration1\t\titeration\tyes\t\t#111
        #{story1.number}\tstory1\t\tstory\tyes\t##{iteration1.number}\t#111
      CSV
      import(import_content)
      
      project.reload
      release2 = project.cards.find_by_name('release2')
      iteration1.reload
      story1.reload

      assert configuration.contains?(release1, iteration1)
    end    
  end
  
  def test_should_not_update_card_if_column_for_choosed_tree_are_not_completed
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration2 = project.cards.find_by_name('iteration2')
      story_not_on_tree = create_card!(:name => 'story3', :card_type => project.card_types.find_by_name('story'))
      story_on_tree = project.cards.find_by_name('story1')
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration
        #{story_on_tree.number}\tstory1\t\tstory\tyes\t##{iteration2.number}
        #{story_not_on_tree.number}\tstory3\t\tstory\tyes\t##{iteration2.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story_not_on_tree.reload
      iteration2.reload
      story_on_tree.reload
      configuration.reload
      
      assert !configuration.include_card?(story_not_on_tree)
      assert !configuration.contains?(iteration2, story_on_tree)
    end    
  end
  
  def test_should_not_update_card_if_tree_belonging_column_for_choosed_tree_not_exist
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release1 = project.cards.find_by_name('release1')
      iteration2 = project.cards.find_by_name('iteration2')
      story_not_on_tree = create_card!(:name => 'story3', :card_type => project.card_types.find_by_name('story'))
      story_on_tree = project.cards.find_by_name('story1')
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning iteration\tPlanning release
        #{story_on_tree.number}\tstory1\t\tstory\t##{iteration2.number}\t##{release1.number}
        #{story_not_on_tree.number}\tstory3\t\tstory\t##{iteration2.number}\t##{release1.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story_not_on_tree.reload
      iteration2.reload
      story_on_tree.reload
      configuration.reload
      
      assert !configuration.include_card?(story_not_on_tree)
      assert configuration.include_card?(story_on_tree)
      assert !configuration.contains?(iteration2, story_on_tree)
    end    
  end
  
  def test_should_only_update_selected_tree_when_importing_multiple_trees
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      feature_tree = create_three_level_feature_tree
      story1 = project.cards.find_by_name('story1')
      crm_module = project.cards.find_by_name('CRM')
      reporting_feature = project.cards.find_by_name('reporting')
      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release\tSystem breakdown\tSystem breakdown module\tSystem breakdown feature
        111\trelease2\t\trelease\tyes\t\t\tno\t\t
        #{story1.number}\tstory1\t\tstory\tyes\t\t#111\tyes\t##{crm_module.number}\t##{reporting_feature.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      assert !feature_tree.reload.include_card?(story1)
      assert_equal 'release2', story1.reload.cp_planning_release.name
    end    
  end  
  
  def test_should_remove_card_from_tree_when_value_is_false_in_the_tree_belonging_column
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      assert configuration.include_card?(story1)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\t\tstory\tno\t\t\t#{release1.number} 
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story1.reload
      assert !configuration.reload.include_card?(story1)
      assert_nil story1.cp_planning_release_card_id
    end   
  end
  
  def test_import_with_tree_should_not_be_picky_on_import_data_orders
     create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{iteration1.number}\titeration1\t\titeration\tyes\t\t#111
        111\trelease2\t\trelease\tyes\t\t\tPlanning
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      project.reload
      release2 = project.cards.find_by_name('release2')
      iteration1.reload
      
      assert configuration.contains?(release2, iteration1)
    end
  end
  
  def test_should_show_errors_and_keep_old_values_when_tree_property_data_is_not_hiearachily_correct
    create_tree_project(:init_two_release_planning_tree) do |project, n, configuration|
      iteration1, iteration2, release1, release2, story1 = [n['iteration1'], n['iteration2'], n['release1'], n['release2'], n['story1']]
      import_content =  <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\t\tstory\tyes\t##{iteration2.number}\t##{release2.number}
      CSV
      import_req = failed_import(import_content, :tree_configuration_id => configuration.id)
      
      assert_equal 1, import_req.error_count
      assert_equal 0, import_req.updated_count
      assert_equal 1, import_req.reload.error_details.size

      [project, release1, iteration1, story1].each(&:reload)

      assert configuration.contains?(release1, iteration1)
      assert configuration.contains?(iteration1, story1)
    end
  end
  
  def test_should_show_errors_when_import_cards_existed_and_tree_property_data_is_not_hiearachily_correct
    create_tree_project(:init_two_release_planning_tree) do |project, tree, configuration|
      story1 = project.cards.find_by_name('story1')   
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      release2 = project.cards.find_by_name('release2')    
      
      assert configuration.contains?(iteration1, story1)
      assert configuration.contains?(release1, story1)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\t\tstory\tyes\t##{iteration1.number}\t##{release2.number}
      CSV
      import_req = failed_import(import_content, :tree_configuration_id => configuration.id)
      
      [story1, iteration1, release1, release2].each(&:reload)
      
      assert configuration.contains?(iteration1, story1)
      assert configuration.contains?(release1, story1)
    end
  end
  
  def test_should_show_errors_when_add_card_to_the_tree_that_it_can_not_be_contained
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      card1 = create_card!(:name => 'I am card1', :card_type => project.card_types.find_by_name('Card'))
      card2 = create_card!(:name => 'I am card2', :card_type => project.card_types.find_by_name('Card'))
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{card1.number}\tI am card1\t\tcard\tyes\t\t
        #{card2.number}\tI am card2\t\tcard\tno\t\t
      CSV
      import_req = failed_import(import_content, :tree_configuration_id => configuration.id)
      
      assert_equal ["Row 1: Card tree #{'Planning'.bold} cannot contain Card cards."], import_req.error_details
    end
  end
  
  def test_moving_parent_card_with_excel_import_should_moving_all_the_descendants
    create_tree_project(:init_two_release_planning_tree) do |project, n, configuration|      
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{n['iteration1'].number}\titeration1\t\titeration\tyes\t\t##{n['release2'].number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      n.reload
      assert configuration.contains?(n['release2'], n['iteration1'])
      assert configuration.contains?(n['release2'], n['story1'])
      assert configuration.contains?(n['release2'], n['story2'])
    end    
  end 
  
  def test_should_not_import_relationship_field_when_the_tree_filed_is_set_to_no
    create_tree_project(:init_two_release_planning_tree) do |project, tree, configuration|
      story1 = project.cards.find_by_name('story1')
      iteration1 = project.cards.find_by_name('iteration1')
      release2 = project.cards.find_by_name('release2')
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\t\tstory\tno\t##{iteration1.number}\t##{release2.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      assert !configuration.reload.include_card?(story1.reload)
    end
  end
  
  def test_should_throw_error_when_card_parent_is_not_on_the_tree
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      story1 = project.cards.find_by_name('story1')
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\t\tstory\tyes\t##{iteration3.number}\t
      CSV
      import_req = failed_import(import_content, :tree_configuration_id => configuration.id)
      
      assert_equal ["Row 1: Validation failed: Suggested parent card isn't on tree #{'Planning'.bold}"], import_req.error_details
    end
  end
  
  def test_should_only_create_one_version_when_removing_card_from_tree_and_renaming_card_at_same_time
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      
      original_story1_versions_size = story1.versions.size
      
      assert configuration.include_card?(story1)
      import_content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstoryNewName\t\tstory\tno\t\t\t#{release1.number} 
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      story1.reload
      assert !configuration.reload.include_card?(story1)
      assert_nil story1.cp_planning_release_card_id
      assert_equal "storyNewName", story1.name
      assert_equal original_story1_versions_size + 1, story1.versions.size
    end   
  end
  
  
  def test_removing_parent_and_child_from_tree_will_nil_out_relationship_properties
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      story1 = project.cards.find_by_name('story1')
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')
      
      import_content = <<-CSV
        Number\tName\tType\tPlanning\tPlanning iteration\tPlanning release
        #{story1.number}\tstory1\tStory\tNo\t##{iteration1.number}\t##{release1.number}
        #{iteration1.number}\titerationNewName\tIteration\tNo\t\t##{release1.number}
      CSV
      import(import_content, :tree_configuration_id => configuration.id)
      
      [story1, iteration1, release1].collect(&:reload)
      
      assert_nil iteration1.cp_planning_release_card_id
      assert_nil iteration1.cp_planning_iteration_card_id
      
      assert_nil story1.cp_planning_release_card_id
      assert_nil story1.cp_planning_iteration_card_id
    end
  end
  
end
