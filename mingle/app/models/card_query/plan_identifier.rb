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

class CardQuery
  
  class PlanNotExistError < DomainException; end
  
  class PlanIdentifier
    def initialize(name)
      program = Program.find(:first, :conditions => ["LOWER(name) = LOWER(?) AND #{ProgramProject.table_name}.project_id = ?", name, Project.current.id], :joins => :program_projects)
      raise PlanNotExistError.new("Plan with name #{name.bold} does not exist or has not been associated with this project.") unless program
      @plan = program.plan
    end

    def db_identifier
      @plan.id
    end

    def to_s
      "PLAN #{@plan.name.inspect}"
    end
  end
end
