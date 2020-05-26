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
  class ValueMacroTestProject
    
    def execute
      UnitTestDataLoader.delete_project('value_macro_test_project')
      Project.create!(:name => 'value_macro_test_project', :identifier => 'value_macro_test_project', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        UnitTestDataLoader.setup_property_definitions :Feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'], 
          :Status => ['New', 'In Progress', 'Done', 'Closed'], :old_type => ['Story'], :Iteration => [1,2,3]
        UnitTestDataLoader.setup_text_property_definition 'freetext'
        UnitTestDataLoader.setup_numeric_text_property_definition 'freesize'
        UnitTestDataLoader.setup_date_property_definition 'date_created'
        UnitTestDataLoader.setup_user_definition 'Owner'
        UnitTestDataLoader.setup_numeric_property_definition 'Size', [1,2,3,4,5]

        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #1'}, :size => '1', :freesize => '1', :iteration => '1', :freetext => 'one'  , :date_created => '2007-01-01')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #2'}, :size => '1', :freesize => '1', :iteration => '2', :freetext => 'two'  , :date_created => '2007-01-02')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #3'}, :size => '2', :freesize => '2', :iteration => '2', :freetext => 'two'  , :date_created => '2007-01-02')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #4'}, :size => '3', :freesize => '3', :iteration => '1', :freetext => 'one'  , :date_created => '2007-01-01')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #5'}, :size => '2', :freesize => '2', :iteration => '2', :freetext => 'two'  , :date_created => '2007-01-02')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #6'}, :size => '5', :freesize => '5', :iteration => '3', :freetext => 'three', :date_created => '2007-01-03')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #6'}, :size => '5', :freesize => '5', :iteration => '3', :freetext => 'three', :date_created => '2007-01-03')      
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #7'}, :size => '5', :freesize => '5')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '6.995')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah'}, :size => '6.995')

      end
    end
    
  end
end
