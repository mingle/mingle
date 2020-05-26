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

module TreeFixtures
  module FeatureTree
    TYPES = %w(module feature story)
    
    def init_feature_tree_types
      TYPES.collect do |type_name|
        Project.current.card_types.create :name => type_name
      end
    end
    
    def find_feature_tree_types
      TYPES.collect do |type_name|
        Project.current.card_types.find_by_name(type_name)
      end
    end
    
    ##################################################################
    #                             System breakdown
    #                                 |
    #                    -----------CRM -----------
    #                   |                         |
    #            -----user man----         ----reporting--
    #           |                |        |              |
    #       story21            story22   story23      story24
    #            
    ##################################################################
      
    def init_three_level_feature_tree(configuration)
      type_module, type_feature, type_story = find_feature_tree_types
      configuration.update_card_types({
        type_module => {:position => 0, :relationship_name => 'System breakdown module'}, 
        type_feature => {:position => 1, :relationship_name => 'System breakdown feature'}, 
        type_story => {:position => 2}
      })
      
      crm = configuration.add_child(create_card('CRM', type_module), :to => :root)
      user_man = configuration.add_child(create_card('user man', type_feature), :to => crm)
      story21 = configuration.add_child(create_card('story21', type_story), :to => user_man)
      story22 = configuration.add_child(create_card('story22', type_story), :to => user_man)
      reporting = configuration.add_child(create_card('reporting', type_feature), :to => crm)
      story23 = configuration.add_child(create_card('story23', type_story), :to => reporting)
      story24 = configuration.add_child(create_card('story24', type_story), :to => reporting)
    end
    
    def create_three_level_feature_tree
      init_feature_tree_types
      configuration = Project.current.tree_configurations.create!(:name => 'System breakdown')
      init_three_level_feature_tree(configuration)
      configuration
    end
    
    
    def create_card(name, type)
      Project.current.cards.create!(:name => name, :card_type => type)
    end
    
    
  end
  
  module PlanningTree
    def init_planning_tree_types
      type_story = Project.current.card_types.create :name => 'story'      
      type_iteration = Project.current.card_types.create :name => 'iteration'
      type_release = Project.current.card_types.create :name => 'release'
      [type_release, type_iteration, type_story]
    end
    
    def find_planning_tree_types
      type_release = Project.current.card_types.find_by_name('release')
      type_iteration = Project.current.card_types.find_by_name('iteration')
      type_story = Project.current.card_types.find_by_name('story')
      [type_release, type_iteration, type_story]
    end
    
    def find_five_level_tree_types
      type_release, type_iteration, type_story = find_planning_tree_types
      type_task = Project.current.card_types.find_by_name('task')
      type_minutia = Project.current.card_types.find_by_name('minutia')
      [type_release, type_iteration, type_story, type_task, type_minutia]
    end
    

    ##################################################################################################
    #                                 ---------------Planning tree-----------------
    #                                |                                            |
    #                    ----- release1----                                -----release2-----
    #                   |                 |                               |                 |
    #              iteration1      iteration2                       iteration3          iteration4
    #                  |                                                 |
    #           ---story1----                                         story2        
    #          |           |
    #       task1   -----task2----
    #              |             |  
    #          minutia1       minutia2      
    #           
    ##################################################################################################
    def init_five_level_tree(configuration)
      type_task = Project.current.card_types.create(:name => 'task')
      type_minutia = Project.current.card_types.create(:name => 'minutia')
      
      type_story = Project.current.card_types.find_by_name('story')
      type_iteration = Project.current.card_types.find_by_name('iteration')
      type_release = Project.current.card_types.find_by_name('release')
      
      configuration.update_card_types({
        type_release => {:position => 0, :relationship_name => 'Planning release'}, 
        type_iteration => {:position => 1, :relationship_name => 'Planning iteration'}, 
        type_story => {:position => 2, :relationship_name => 'Planning story'},
        type_task => {:position => 3, :relationship_name => 'Planning task'},
        type_minutia => {:position => 4}
      })
      release1 = configuration.add_child(Project.current.cards.create!(:name => 'release1', :card_type => type_release))
      release2 = configuration.add_child(Project.current.cards.create!(:name => 'release2', :card_type => type_release))
      iteration1 = configuration.add_child(Project.current.cards.create!(:name => 'iteration1', :card_type => type_iteration), :to => release1)
      iteration2 = configuration.add_child(Project.current.cards.create!(:name => 'iteration2', :card_type => type_iteration), :to => release1)
      iteration3 = configuration.add_child(Project.current.cards.create!(:name => 'iteration3', :card_type => type_iteration), :to => release2)
      iteration4 = configuration.add_child(Project.current.cards.create!(:name => 'iteration4', :card_type => type_iteration), :to => release2)
      
      story1 = configuration.add_child(Project.current.cards.create!(:name => 'story1', :card_type => type_story), :to => iteration1)
      story2 = configuration.add_child(Project.current.cards.create!(:name => 'story2', :card_type => type_story), :to => iteration3)

      task1 = configuration.add_child(Project.current.cards.create!(:name => 'task1', :card_type => type_task), :to => story1)
      task2 = configuration.add_child(Project.current.cards.create!(:name => 'task2', :card_type => type_task), :to => story1)

      configuration.add_child(Project.current.cards.create!(:name => 'minutia1', :card_type => type_minutia), :to => task2)
      configuration.add_child(Project.current.cards.create!(:name => 'minutia2', :card_type => type_minutia), :to => task2)
      
      configuration.create_tree
    end

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
    def init_three_level_tree(configuration)
      project = configuration.project
      configure_three_level_tree(configuration) do |type_release, type_iteration, type_story|
        release1 = configuration.add_child(project.cards.create!(:name => 'release1', :card_type => type_release))
        iteration1 = configuration.add_child(project.cards.create!(:name => 'iteration1', :card_type => type_iteration), :to => release1)
        iteration2 = configuration.add_child(project.cards.create!(:name => 'iteration2', :card_type => type_iteration), :to => release1)
        configuration.add_child(project.cards.create!(:name => 'story1', :card_type => type_story), :to => iteration1)
        configuration.add_child(project.cards.create!(:name => 'story2', :card_type => type_story), :to => iteration1)
      end
    end
    
    def create_three_level_tree
      configuration = Project.current.tree_configurations.create!(:name => 'three_level_tree')
      init_three_level_tree(configuration)
    end
    
    def create_five_level_tree
      init_planning_tree_types
      configuration = Project.current.tree_configurations.create!(:name => 'five_level_tree')
      init_five_level_tree(configuration)
    end
    
    ##################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2
    #                   |                 |             |
    #            ---iteration1----    iteration2    iteration3
    #           |                |
    #       story1            story2        
    #            
    ##################################################################
    def init_two_release_planning_tree(configuration)
      configure_three_level_tree(configuration) do |type_release, type_iteration, type_story|
        release1 = configuration.add_child(create_card!(:name => 'release1', :card_type => type_release), :to => :root)
        release2 = configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)

        iteration1 = configuration.add_child(create_card!(:name => 'iteration1', :card_type => type_iteration), :to => release1)
        iteration2 = configuration.add_child(create_card!(:name => 'iteration2', :card_type => type_iteration), :to => release1)
        iteration3 = configuration.add_child(create_card!(:name => 'iteration3', :card_type => type_iteration), :to => release2)

        configuration.add_child(create_card!(:name => 'story1', :card_type => type_story), :to => iteration1)
        configuration.add_child(create_card!(:name => 'story2', :card_type => type_story), :to => iteration1)
      end
    end
    
    def create_two_release_planning_tree
      configuration = Project.current.tree_configurations.create!(:name => 'two_release_planning_tree')
      init_two_release_planning_tree(configuration)
    end

    #####################################################################################
    #                                            Planning tree
    #                             --------------------|-----------------
    #                            |                    |                |
    #                    ----- release1----       iteration2        story5
    #                   |                 |           |
    #            ---iteration1----    story3       story4
    #           |                |
    #       story1            story2
    #            
    #####################################################################################
    def init_planning_tree_with_multi_types_in_levels(configuration)
      project = configuration.project
      configure_three_level_tree(configuration) do |type_release, type_iteration, type_story|
        release1 = configuration.add_child(project.cards.create!(:name => 'release1', :card_type => type_release), :to => :root)
        iteration2 = configuration.add_child(project.cards.create!(:name => 'iteration2', :card_type => type_iteration), :to => :root)
        story4 = configuration.add_child(project.cards.create!(:name => 'story4', :card_type => type_story), :to => iteration2)
        story5 = configuration.add_child(project.cards.create!(:name => 'story5', :card_type => type_story), :to => :root)

        iteration1 = configuration.add_child(project.cards.create!(:name => 'iteration1', :card_type => type_iteration), :to => release1)
        story3 = configuration.add_child(project.cards.create!(:name => 'story3', :card_type => type_story), :to => release1)

        configuration.add_child(project.cards.create!(:name => 'story1', :card_type => type_story), :to => iteration1)
        configuration.add_child(project.cards.create!(:name => 'story2', :card_type => type_story), :to => iteration1)
      end
    end
    
    def init_empty_planning_tree(configuration)
      configure_three_level_tree(configuration)
    end
    
    ##################################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2--------
    #                   |                 |             |            |
    #            ---iteration1----    iteration2    iteration1     iteration2---
    #           |                |                      |           |          |
    #       story1            story2                  story3      story4    story5
    #            
    ##################################################################################
    def init_planning_tree_with_duplicate_iteration_names(configuration)
      configure_three_level_tree(configuration) do |type_release, type_iteration, type_story|
        release1 = configuration.add_child(create_card!(:name => 'release1', :card_type => type_release), :to => :root)
        iteration11 = configuration.add_child(create_card!(:name => 'iteration1', :card_type => type_iteration), :to => release1)
        story1 = configuration.add_child(create_card!(:name => 'story1', :card_type => type_story), :to => iteration11)
        story2 = configuration.add_child(create_card!(:name => 'story2', :card_type => type_story), :to => iteration11)

        iteration12 = configuration.add_child(create_card!(:name => 'iteration2', :card_type => type_iteration), :to => release1)
        
        release2 = configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)
        
        iteration21 = configuration.add_child(create_card!(:name => 'iteration1', :card_type => type_iteration), :to => release2)
        story3 = configuration.add_child(create_card!(:name => 'story3', :card_type => type_story), :to => iteration21)
        
        iteration22 = configuration.add_child(create_card!(:name => 'iteration2', :card_type => type_iteration), :to => release2)
        story4 = configuration.add_child(create_card!(:name => 'story4', :card_type => type_story), :to => iteration22)
        story5 = configuration.add_child(create_card!(:name => 'story5', :card_type => type_story), :to => iteration22)
      end      
    end
    
    def create_planning_tree_with_multi_types_in_levels
      configuration = Project.current.tree_configurations.create!(:name => 'multi_types_in_levels')
      init_planning_tree_with_multi_types_in_levels(configuration)
    end
    
    def create_planning_tree_with_duplicate_iteration_names
      configuration = Project.current.tree_configurations.create!(:name => 'duplicate_iteration_names')
      init_planning_tree_with_duplicate_iteration_names(configuration)
    end
    
    def create_planning_tree_project(&block)
      create_tree_project(:init_planning_tree_with_multi_types_in_levels, &block)
    end
    
    def create_tree_project(init_tree_method)
      proj_admin = User.find_by_login('proj_admin')
      with_new_project(:admins => [proj_admin]) do |project|
        configuration = project.tree_configurations.create!(:name => 'Planning')
        init_planning_tree_types
        self.send(init_tree_method, configuration)
        tree = configuration.create_tree
        if block_given?
          yield(project, tree, configuration)
        else
          return project, tree, configuration
        end
      end
    end
    
    private
    def configure_three_level_tree(configuration)
      # Planning tree > Release > Iteration > Story.
      release_type = Project.current.card_types.detect { |ct| ct.name.downcase == 'release' }
      if release_type
        iteration_type = Project.current.card_types.detect { |ct| ct.name.downcase == 'iteration' }
        story_type = Project.current.card_types.detect { |ct| ct.name.downcase == 'story' }
      else
        release_type, iteration_type, story_type = init_planning_tree_types
      end
      
      planning_release_relationship = Project.current.find_property_definition_or_nil('Planning release')
      planning_iteration_relationship = Project.current.find_property_definition_or_nil('Planning iteration')
      planning_release_name = planning_release_relationship ? "Planning release #{Time.now.to_i}" : "Planning release"
      planning_iteration_name = planning_iteration_relationship ? "Planning iteration #{Time.now.to_i}" : "Planning iteration"
      
      configuration.update_card_types({
        release_type => {:position => 0, :relationship_name => planning_release_name}, 
        iteration_type => {:position => 1, :relationship_name => planning_iteration_name}, 
        story_type => {:position => 2}
      })
      
      yield(release_type, iteration_type, story_type) if block_given?
      
      configuration.create_tree
    end
  end
end           
