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
  class RenderableTestProject
    
    def execute
      UnitTestDataLoader.delete_project('renderable_test_project')
      Project.create!(:name => 'renderable_test_project', :identifier => 'renderable_test_project', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))    
        UnitTestDataLoader.setup_property_definitions(:iteration => ['one', 'two'], :old_type => ['story'],  
          :release => ['one'], :size => [5,7], :status => ['done', 'open'])
        UnitTestDataLoader.setup_numeric_property_definition('estimate', ['1', '2', '4', '8'])
        card1 = project.cards.create!(:name => 'card1', :card_type => project.card_types.first)
        card1.update_attributes(:cp_old_type => 'story', :cp_release => 'one', :cp_iteration => 'one', 
          :cp_size => '5', :cp_status => 'done')
        card2 = project.cards.create!(:name => 'card2', :card_type => project.card_types.first)
        card2.update_attributes(:cp_old_type => 'story', :cp_release => 'one', :cp_iteration => 'two', 
          :cp_size => '7', :cp_status => 'open')
      end
      
    end
  end
end
