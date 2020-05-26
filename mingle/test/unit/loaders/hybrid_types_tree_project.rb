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
  class HybridTypesTreeProject
    include TreeFixtures::PlanningTree 
   
    def execute
      UnitTestDataLoader.delete_project('multi_types_in_same_level_tree_project')
      Project.create!(:name => 'hybrid_types_tree_project', :identifier => 'hybrid_types_tree_project', :corruption_checked => true).with_active_project do |project|
        project.generate_secret_key!
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)
        configuration = project.tree_configurations.create(:name => 'planning tree')
        init_planning_tree_types
        init_planning_tree_with_multi_types_in_levels(configuration)
      end
      
    end
    
  end
end
