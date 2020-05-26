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
  class AverageMacroTestProject
    
    def execute
      UnitTestDataLoader.delete_project('average_macro_test_project')
      Project.create!(:name => 'average_macro_test_project', :identifier => 'average_macro_test_project', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        UnitTestDataLoader.setup_property_definitions :Feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'], 
          :Status => ['New', 'In Progress', 'Done', 'Closed'], :old_type => ['Story'], :Iteration => [1,2,3]
        UnitTestDataLoader.setup_text_property_definition 'freetext'
        UnitTestDataLoader.setup_date_property_definition 'date_created'
        UnitTestDataLoader.setup_numeric_property_definition 'Size', [1,2,3,4,5]

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #1'}, :date_created => '2007-01-01', :freetext => '1', :size => '1', :iteration => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #2'}, :date_created => '2007-01-02', :freetext => '2', :size => '1', :iteration => '2')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #3'}, :date_created => '2007-01-02', :freetext => '2', :size => '2', :iteration => '2')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #4'}, :date_created => '2007-01-01', :freetext => '1', :size => '3', :iteration => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #5'}, :date_created => '2007-01-02', :freetext => '2', :size => '2', :iteration => '2')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #6'}, :date_created => '2007-01-03', :freetext => '3', :size => '5', :iteration => '3')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #6'}, :date_created => '2007-01-03', :freetext => '3', :size => '5', :iteration => '3')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #7'}, :date_created => '2007-01-05', :freetext => '5', :size => '5')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #7'}, :date_created => '2007-01-05', :freetext => '5', :size => '6.515', :iteration => '6')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #8'}, :size => nil, :iteration => '8')
      end
      
    end
    
  end
end
