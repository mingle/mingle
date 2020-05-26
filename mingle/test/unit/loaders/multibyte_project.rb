#encoding: UTF-8

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
  class MultibyteProject
   
    def execute
      UnitTestDataLoader.delete_project('multibyte_project')
      Project.create!(:name => 'multibyte project', :identifier => 'multibyte_project', :corruption_checked => true).with_active_project do |project|
        project.generate_secret_key!
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        project.cards.create!(:number => 1, :name => 'first', :card_type => project.card_types.first)
        project.cards.create!(:number => 2, :name => 'second', :card_type => project.card_types.first)
        project.cards.create!(:number => 3, :name => 'third', :card_type => project.card_types.first)

        UnitTestDataLoader.setup_property_definitions('专题' => ['用户管理', 'Search'])
        project.reload
        feature = project.find_property_definition('专题')
        project.cards[0..1].each{|card| feature.update_card(card, '用户管理') && card.save}
        project.cards[2..-1].each{|card| feature.update_card(card, 'Search') && card.save}
      end
    end
    
  end
end
