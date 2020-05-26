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

class AddNumberToObjectives < ActiveRecord::Migration
  def self.up
    add_column :objectives, :number, :integer

    M20130312215202Plan.find(:all).each do |plan|
      plan.objectives.each_with_index do |objective, index|
        objective.number = (index + 1)
        objective.save
      end
    end
    add_column :objective_versions, :number, :integer
    Objective.reset_column_information
    Objective::Version.reset_column_information
  end

  def self.down
    remove_colum :objectives, :number
    remove_colum :objective_versions, :number
  end

  class M20130312215202Plan < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("plans")
    has_many :objectives, :class_name => 'AddNumberToObjectives::M20130312215202Objective', :foreign_key => 'plan_id'
  end

  class M20130312215202Objective < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("objectives")
  end
end
