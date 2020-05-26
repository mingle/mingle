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

class CreateProgramsForExistingPlans < ActiveRecord::Migration
  
  class M20120918202629Plan < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("deliverables")
    self.inheritance_column = '9328jkjoji_type' # disable single table inheretance
    
    belongs_to :program, :class_name => 'CreateProgramsForExistingPlans::M20120918202629Program', :foreign_key => 'program_id'
  end

  class M20120918202629Program < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("programs")
    has_one :plan, :class_name => 'CreateProgramsForExistingPlans::M20120918202629Plan', :foreign_key => 'program_id'
  end
  
  def self.up
    M20120918202629Plan.all.each do |plan|
      next if plan['type'] != 'Plan'
      plan.create_program
      plan.save!
    end
  end

  def self.down
  end
end
