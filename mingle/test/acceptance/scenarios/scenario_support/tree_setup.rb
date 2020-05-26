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

module TreeSetup
  
  module InstanceMethods
    private
    
    ##################################################################
    #                       three_level_tree
    #                            |
    #                    ----- release1---------------------------------
    #                   |                                              |
    #            ---iteration1(Status => closed)--------             iteration2(Status => closed)
    #           |                                      |
    #       story1(Status => new, Est => 1)         story2(Status => new, Est => 1)
    ##################################################################
    def setup_tree_and_card_properties
      init_planning_tree_types
      create_three_level_tree

      @story = Project.current.card_types.find_by_name('story')
      @iteration = Project.current.card_types.find_by_name('iteration')

      status = setup_managed_text_definition(:Status, %w(New Open Closed))
      associate_property_definition_with_card_type(status, @iteration)
      associate_property_definition_with_card_type(status, @story)

      estimation = setup_managed_number_list_definition(:Estimation, [1, 2, 4, 8])
      associate_property_definition_with_card_type(estimation, @story)

      Project.current.cards.find_all_by_card_type_name("iteration").each do |card|
        card.cp_status = 'Closed'
        card.save!
      end

      Project.current.cards.find_all_by_card_type_name("story").each do |card|
        card.cp_status = 'New'
        card.cp_estimation = 4
        card.save!
      end
    end

    def associate_property_definition_with_card_type(prop_def, card_type)
      card_type.add_property_definition(prop_def)
      card_type.save!
      @project.reload
    end
  end
  
  def self.included(receiver)
    receiver.send :include, TreeFixtures::PlanningTree, InstanceMethods
  end
end
