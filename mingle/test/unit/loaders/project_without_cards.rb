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
  class ProjectWithoutCards
   
    def execute
      UnitTestDataLoader.delete_project('project_without_cards')
      Project.create!(:name => 'Project Without Cards', :identifier => 'project_without_cards', 
                      :secret_key => 'this is secret', :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('first'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        UnitTestDataLoader.setup_property_definitions(
          :Release => ['1', '2'],
          :Act => ['first', 'second'],
          :Foo => ['bar'],
          :Iteration => ['1', '2', 'one', '12'],
          :Status => ['new', 'old', 'open', 'fixed', 'limbo', 'in progress', 'closed'],
          :Priority => ['high', 'urgent', 'low'],
          :old_type => ['bug', 'card', 'story'],
          :Position  => ['second', 'first', 'third'],
          :'Test status' => ['open', 'close'],
          :Likeanumber => [],
          :Junk => [],
          :Component => [], 
          :Version => [], 
          :Milestone => [],
          :Severity => [],
          :Owner => [], 
          :Created => [],
          :Feature => ['email'],
          :Summary => [],
          :Kind => [],
          :Id => [],
          :Assigned_to => ['Badri', 'Jon'],
          :Developer => [],
          :'Completed in iteration' => [1,2,3]
        )

        UnitTestDataLoader.setup_user_definition('dev')
        UnitTestDataLoader.setup_date_property_definition('startdate')
        UnitTestDataLoader.setup_formula_property_definition('day after start date', "startdate + 1")
      end
    end
    
  end
end
