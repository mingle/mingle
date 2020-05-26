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
  class CardSelectionProject
   
    def execute
      UnitTestDataLoader.delete_project('card_selection_project')
      Project.create!(:name => 'card_selection_project', :identifier => 'card_selection_project', 
                      :secret_key => 'this is secret', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)
        UnitTestDataLoader.setup_property_definitions(
          :Status => ['open', 'closed'], 
          :Iteration => [1, 2],
          :Priority => ['high', 'low']
        )    

        UnitTestDataLoader.setup_user_definition('owner')
        UnitTestDataLoader.setup_text_property_definition('id')
        UnitTestDataLoader.setup_date_property_definition('start date')

        project.cards.create!(:number => 1, :name => 'first card', :card_type => project.card_types.first)
        project.cards.create!(:number => 2, :name => 'second card', :card_type => project.card_types.first)
        project.cards.create!(:number => 3, :name => 'third card', :card_type => project.card_types.first)

        project.reset_card_number_sequence
      end
    end
    
  end
end
