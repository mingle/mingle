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

module Loaders
  class DataSeriesChartProject
    include TreeFixtures::PlanningTree
   
    def execute
      UnitTestDataLoader.delete_project('data_series_chart_project')
      Project.create!(:name => 'data_series_chart_project', :identifier => 'data_series_chart_project', 
                      :secret_key => 'this is secret', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('first'))
        project.add_member(User.find_by_login('bob'))
        project.add_member(User.find_by_login('longbob'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        tree_configuration = project.tree_configurations.create(:name => 'planning tree')
        init_planning_tree_types
        type_release = project.find_card_type('release')
        type_iteration = project.find_card_type('iteration')
        type_story = project.find_card_type('story')
        tree_configuration.update_card_types({
          type_release => {:position => 0, :relationship_name => 'Planning release'}, 
          type_iteration => {:position => 1, :relationship_name => 'Planning iteration'}, 
          type_story => {:position => 2}
        })

        release1 = tree_configuration.add_child(project.cards.create!(:name => 'release1', :card_type => type_release))
        release2 = tree_configuration.add_child(project.cards.create!(:name => 'release2', :card_type => type_release))

        UnitTestDataLoader.setup_property_definitions(
          :Priority => ['low', 'medium', 'high'],
          :Status => ['New', 'Open', 'Closed'],
          :Release  => ['1.0', '1.1', '2.0'], 
          :Feature => ['Dashboard', 'Applications', 'User administration']
        )

        iterations = (1..5).to_a
        prop = UnitTestDataLoader.setup_numeric_property_definition('Size', iterations)
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_numeric_property_definition('Entered Scope Iteration', iterations)
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_numeric_property_definition('Analysis Complete Iteration', iterations)
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_numeric_property_definition('Development Complete Iteration', iterations + [6,7])
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_numeric_property_definition('Accepted Iteration', iterations)
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_date_property_definition('accepted on')
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_date_property_definition('entered scope on')
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_numeric_text_property_definition('free number')
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_user_definition('owner')
        prop.card_types = [type_story]
        prop.save!
        prop = UnitTestDataLoader.setup_formula_property_definition('double size', 'size * 2')
        prop.card_types = [type_story]
        prop.save!
        project.reload
        iteration1 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration1', :card_type => type_iteration), :to => release1)
        iteration2 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration2', :card_type => type_iteration), :to => release1)
        iteration3 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration3', :card_type => type_iteration), :to => release1)
        iteration4 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration4', :card_type => type_iteration), :to => release1)
        iteration5 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration5 ', :card_type => type_iteration), :to => release1)

        iteration1_r2 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration1', :card_type => type_iteration), :to => release2)
        iteration2_r2 = tree_configuration.add_child(project.cards.create!(
          :name => 'iteration2', :card_type => type_iteration), :to => release2)

        # not in tree
        project.cards.create!(:name => 'iteration6', :card_type => type_iteration)
        project.cards.create!(:name => 'iteration7', :card_type => type_iteration)

        # iteration 1 (26 nov 2007 through 9 dec 2007)
        # -- entered scope points: 29
        # -- analysis complete points: 27
        # -- dev complete points: 10
        # -- accepted points:

        # iteration 2 (10 dec 2007 through 23 dec 2007)
        # -- entered scope points: 14
        # -- analysis complete points: 4
        # -- dev complete points: 7
        # -- accepted points:

        # iteration 3 (24 dec 2007 through 6 jan 2008)
        # -- entered scope points:
        # -- analysis complete points: 12
        # -- dev complete points: 4
        # -- accepted points: 18

        # iteration 4 (7 jan 2008 through 20 jan 2008)
        # -- entered scope points:
        # -- analysis complete points:
        # -- dev complete points: 12
        # -- accepted points: 3

        # iteration 5 (21 jan 2008 through 3 feb 2008)
        # -- entered scope points:
        # -- analysis complete points:
        # -- dev complete points:
        # -- accepted points: 8
        
        @member = User.find_by_login('member')
        @first = User.find_by_login('first')

        story1 = UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '2', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => '1', :'accepted iteration' => '3',
             :'entered scope on' => '26 nov 2007', :'accepted on' => '27 dec 2007', 
             :release => '2.0', :card_type => type_story, :'free number' => 2, :owner => @member.id, :'Planning iteration' => iteration1.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '8', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => '1', :'accepted iteration' => '3', 
             :'entered scope on' => '28 nov 2007', :'accepted on' => '28 dec 2007', 
             :release => '2.0', :card_type => type_story, :'free number' => 2.0, :owner => @member.id, :'Planning iteration' => iteration1.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '4', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => '2', :'accepted iteration' => '3',
             :'entered scope on' => '30 nov 2007', :'accepted on' => '2 jan 2008', 
             :release => '2.0', :card_type => type_story, :'free number' => 2.00, :'Planning iteration' => iteration2.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '2', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => '2', :'accepted iteration' => '4', 
             :'entered scope on' => '30 nov 2007', :'accepted on' => '9 jan 2008', 
             :release => '2.0', :card_type => type_story, :'free number' => 3, :owner => @first.id, :'Planning iteration' => iteration2.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '8', :'entered scope iteration' => '2', :'analysis complete iteration' => '3', 
             :'development complete iteration' => '4', :'accepted iteration' => '5', 
             :'entered scope on' => '10 dec 2007', :'accepted on' => '2 feb 2008', 
             :release => '2.0', :card_type => type_story, :'free number' => 3.0, :'Planning iteration' => iteration2.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '1', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => '2', :'accepted iteration' => '4',
             :'entered scope on' => '3 dec 2007', :'accepted on' => '18 jan 2007', 
             :release => '2.0', :card_type => type_story, :'free number' => 3.00, :'Planning iteration' => iteration2.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '4', :'entered scope iteration' => '2', :'analysis complete iteration' => '2', 
             :'development complete iteration' => '3', :'accepted iteration' => '3',
             :'entered scope on' => '13 dec 2007', :'accepted on' => '4 jan 2007', 
             :release => '2.0', :card_type => type_story, :'free number' => 4, :'Planning iteration' => iteration3.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '4', :'entered scope iteration' => '1', :'analysis complete iteration' => '3', 
             :'development complete iteration' => '4', :'accepted iteration' => nil, 
             :'entered scope on' => '26 nov 2007', :'accepted on' => nil, 
             :release => '2.0', :card_type => type_story, :'free number' => 4.0, :owner => @first.id, :'Planning iteration' => iteration4.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '8', :'entered scope iteration' => '1', :'analysis complete iteration' => '1', 
             :'development complete iteration' => nil, :'accepted iteration' => nil, 
             :'entered scope on' => '4 dec 2007', :'accepted on' => nil, 
             :release => '2.0', :card_type => type_story, :'free number' => 4.00, :'Planning iteration' => iteration4.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
            {:size => '2', :'entered scope iteration' => '2', :'analysis complete iteration' => '1', 
             :'development complete iteration' => nil, :'accepted iteration' => nil, 
             :'entered scope on' => '20 dec 2007', :'accepted on' => nil, 
             :release => '2.0', :card_type => type_story, :'free number' => 5, :'Planning iteration' => iteration4.id})

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'blab'},
           {:size => '2', :'entered scope iteration' => nil, :'analysis complete iteration' => nil, 
            :'development complete iteration' => nil, :'accepted iteration' => nil, 
            :'entered scope on' => nil, :'accepted on' => nil, 
            :release => '2.0', :card_type => type_story, :'free number' => 5})

      end
    end
    
  end
end
