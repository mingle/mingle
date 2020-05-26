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
  class SimpleProgram
    
    IDENTIFIER = 'simple_program'
   
    def execute
      if program = Program.find_by_identifier(IDENTIFIER)
        program.destroy
      end

      program = Program.create!(:name => 'simple program', :identifier => IDENTIFIER)
      plan = program.plan
      plan.update_attributes({:start_at => "15 Feb 2011", :end_at => "1 Sep 2011" })
      
      program.objectives.planned.create!({:name => 'objective a', :start_at => "20 Feb 2011", :end_at => "1 Mar 2011"})
      program.objectives.planned.create!({:name => 'objective b', :start_at => "22 Feb 2011", :end_at => "15 Mar 2011"})
      program.objectives.planned.create!({:name => 'objective c', :start_at => "25 Apr 2011", :end_at => "3 May 2011"})

      sp_first_project = create_project("sp_first_project", 2)
      program.projects << sp_first_project
      program.projects << create_project("sp_second_project", 3)
      create_project("sp_unassigned_project", 3)

      unless program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
        raise "Error: #{plan.errors.full_messages}"
      end
    end

    def create_project(identifier, card_count)
      UnitTestDataLoader.delete_project(identifier)
      Project.create!(:name => "Simple Program #{identifier}", :identifier => identifier, :corruption_checked => true).with_active_project do |project|
        project.generate_secret_key!
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        create_cards(project, card_count)
        setup_basic_properties
        project
      end
    end

    def setup_basic_properties
      UnitTestDataLoader.setup_property_definitions(
        :status => ['new', 'open', 'in progress', 'closed'],
        :priority => ['low', 'medium', 'high'],
        :estimate => [1, 2, 4, 8]
      )
      UnitTestDataLoader.setup_user_definition('owner')
      UnitTestDataLoader.setup_date_property_definition('due date')
      UnitTestDataLoader.setup_numeric_property_definition('Pi', [3, 1, 4])
    end

    def create_cards(project, count)
      count.times do |index|
        project.cards.create!(:number => index + 1, :name => "#{project.identifier} card #{index + 1}", :card_type => project.card_types.first)
      end
    end

  end
end
