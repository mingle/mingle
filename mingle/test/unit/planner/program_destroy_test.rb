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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class ProgramDestroyTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = create_program
    @plan = @program.plan
  end

  def test_destroy_program_should_cleanup_plan
    assign_all_work_to_new_objective(@program, first_project)
    program_objective_ids = @program.objectives.collect(&:id)
    plan_work_ids = @plan.works.collect(&:id)
    program_project_ids = @program.program_projects.collect(&:id)
    
    assert @program.destroy
    assert_equal [], program_objective_ids.select{|id| Objective.find_by_id(id)}
    assert_equal [], plan_work_ids.select{|id| Work.find_by_id(id) }
    assert_equal [], program_project_ids.select{|id| ProgramProject.find_by_id(id) }

  end
  
  def test_destroy_program_should_cleanup_backlog
    backlog_objective = @program.objectives.backlog.create!(:name => 'I should be deleted')
    assert @program.destroy
    assert_false @program.objectives.backlog.exists?(backlog_objective.id)
  end

end
