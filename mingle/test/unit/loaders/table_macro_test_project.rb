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
  class TableMacroTestProject
    
    def execute
      UnitTestDataLoader.delete_project('table_macro_test_project')
      @member = User.find_by_login('member')
      UnitTestDataLoader.create_card_query_project('table_macro_test_project', false).with_active_project do |project|
        project.add_member(@member)
        project.update_attributes(:date_format => "%d %b %Y")
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #1'}, :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'story', :iteration => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #2'}, :feature => 'Applications', :size => '1', :status => 'New', :old_type => 'story', :iteration => '1', :'assigned to' => @member.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #3'}, :feature => 'Applications', :size => '2', :old_type => 'story', :iteration => '1', :'assigned to' => @member.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #4'}, :feature => 'Rate calculator', :size => '3', :status => 'New', :old_type => 'story', :iteration => '1', :'assigned to' => @member.id)
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #5'}, :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'story', :iteration => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #6'}, :feature => 'Profile builder', :size => '5', :old_type => 'story', :iteration => '1')
        UnitTestDataLoader.create_card_with_property_name(project, {:name => 'Blah #7'}, :size => '5', :old_type => 'story')
      end
    end
    
  end
end
