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

class CopyPlanNameToIdentifier < ActiveRecord::Migration
  class Plan < ActiveRecord::Base
    set_table_name connection.safe_table_name('deliverables')
    self.inheritance_column = 'plan_type' #disable single table inheretance
  end
  
  def self.up
    Plan.find(:all, :conditions => ['type = ?', 'Plan']).each do |plan|
      plan.identifier = plan.name.underscored[0..30]
      plan.save!
    end
  end

  def self.down
    Plan.find(:all, :conditions => ['type = ?', 'Plan']).each do |plan|
      plan.identifier = nil
      plan.save!
    end
  end
end
