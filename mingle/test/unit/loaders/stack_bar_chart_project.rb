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
  class StackBarChartProject
   
    def execute
      UnitTestDataLoader.delete_project('stack_bar_chart_project')
      Project.create!(:name => 'stack_bar_chart_project', :identifier => 'stack_bar_chart_project', 
                      :secret_key => 'this is secret', :corruption_checked => true).with_active_project do |project|
        @first = User.find_by_login('first')
        @member = User.find_by_login('member')
        @bob = User.find_by_login('bob')
        @longbob = User.find_by_login('longbob')

        project.add_member(@member)
        project.add_member(@first)
        project.add_member(@bob)
        project.add_member(@longbob)
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        UnitTestDataLoader.setup_property_definitions(
          :old_type => ['story'], 
          :Priority => ['low', 'medium'],
          :Status => ['New', 'In Progress', 'Done', 'Closed'],
          :Release  => [1, 2], 
          :Iteration => (1..5).to_a, 
          :Feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'],
          'In Scope'.humanize => ['Yes', 'No'],
          'Completed On Iteration'.humanize => [],
          'Came Into Scope on Iteration'.humanize => [1,2,3],
          'Planned for Iteration'.humanize => [1,2],
          'Development Done in Iteration'.humanize => [],
          'Analysis Done in Iteration'.humanize => []
        )

        UnitTestDataLoader.setup_text_property_definition('text_iteration')
        UnitTestDataLoader.setup_text_property_definition('text_old_type')
        UnitTestDataLoader.setup_date_property_definition('date_created')
        UnitTestDataLoader.setup_user_definition('owner')

        UnitTestDataLoader.setup_numeric_property_definition('Size', (1..5).to_a)

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '5', :'came into scope on iteration' => '1', :iteration => '1', :text_iteration => '1', :'planned for iteration' => '1', :date_created => '2007-01-01', :status => 'Closed', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @first.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '1', :'came into scope on iteration' => '1', :iteration => '1', :text_iteration => '1', :'planned for iteration' => '1', :date_created => '2007-01-01', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @bob.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '2', :'came into scope on iteration' => '1', :iteration => '2', :text_iteration => '2', :'planned for iteration' => '1', :date_created => '2007-01-02', :status => 'Closed', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @longbob.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '3', :'came into scope on iteration' => '1', :iteration => '2', :text_iteration => '2', :'planned for iteration' => '1', :date_created => '2007-01-02', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @first.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '2', :'came into scope on iteration' => '1', :iteration => '2', :text_iteration => '2', :'planned for iteration' => '2', :date_created => '2007-01-02', :status => 'Closed', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @bob.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '2', :'came into scope on iteration' => '2', :iteration => '3', :text_iteration => '3', :'planned for iteration' => '2', :date_created => '2007-01-02', :status => 'In Progress', :old_type => 'story', :text_old_type => 'story', :release => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '3', :'came into scope on iteration' => '1', :iteration => '3', :text_iteration => '3', :'planned for iteration' => '2', :date_created => '2007-01-03', :status => 'Closed', :old_type => 'story', :text_old_type => 'story', :release => '1', :owner => @longbob.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '3', :'came into scope on iteration' => '1', :iteration => '3', :text_iteration => '3', :'planned for iteration' => '2', :date_created => '2007-01-06', :status => 'Closed', :old_type => 'story', :text_old_type => 'story', :release => '2', :owner => @first.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'})
      end
    end
    
  end
end
