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
  class CardPropDefTestProject
    
    def execute
      UnitTestDataLoader.delete_project('card_prop_def_test_project')
      Project.create!(:name => 'card_prop_def_test_project', :identifier => 'card_prop_def_test_project', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        story_type = project.card_types.create :name => 'story'      
        iteration_type = project.card_types.create :name => 'iteration'
        UnitTestDataLoader.setup_card_property_definition 'iteration', iteration_type
        UnitTestDataLoader.setup_property_definitions :priority => ['high', 'low']
        UnitTestDataLoader.setup_numeric_property_definition 'size', [1, 2, 4, 8]
        ['size', 'priority'].each do |pd_name|
          prop_def = project.find_property_definition(pd_name)
          story_type.add_property_definition prop_def
        end
      end
    end
    
  end
end
