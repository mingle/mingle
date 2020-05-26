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

class MapProjectsToProgramInPlanProject < ActiveRecord::Migration
  def self.up
    add_column :plan_projects, :program_id, :integer

    plan_projects_table_name = ActiveRecord::Base.connection.safe_table_name('plan_projects')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')

    ActiveRecord::Base.connection.execute <<-SQL
    UPDATE #{plan_projects_table_name} plan_projects 
        SET program_id = (SELECT program_id FROM #{plans_table_name} plans WHERE plans.id = plan_id)
    SQL
    
    remove_column :plan_projects, :plan_id
  end

  def self.down
    add_column :plan_projects, :plan_id, :integer

    plan_projects_table_name = ActiveRecord::Base.connection.safe_table_name('plan_projects')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')

    ActiveRecord::Base.connection.execute <<-SQL
    UPDATE #{plan_projects_table_name} plan_projects 
        SET plan_id = (SELECT id FROM #{plans_table_name} plans WHERE plans.program_id = program_id),
    SQL
    
    remove_column :plan_projects, :program_id
  end
end
