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

class MakePlanNotADeliverable < ActiveRecord::Migration
  def self.up
    create_table :plans do |table|
      table.string :name
      table.string :identifier
      table.date :start_at
      table.date :end_at
      table.integer :program_id
      table.integer :precision, :default => 2
      table.timestamps
    end

    new_plans_table_name = ActiveRecord::Base.connection.safe_table_name('plans')
    old_plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    objectives_table_name = ActiveRecord::Base.connection.safe_table_name('objectives')
    works_table_name = ActiveRecord::Base.connection.safe_table_name('works')

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO #{new_plans_table_name} (id, identifier, name, start_at, end_at, program_id, created_at, updated_at)
          SELECT (#{ActiveRecord::Base.connection.next_id_sql(new_plans_table_name)}), identifier, name, start_at, end_at, program_id, created_at, updated_at
            FROM #{old_plans_table_name} WHERE type = 'Plan'
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{objectives_table_name} obj SET plan_id = (
        SELECT plans.id FROM #{new_plans_table_name} plans, #{old_plans_table_name} old_plans WHERE plans.identifier = old_plans.identifier AND old_plans.type = 'Plan' AND old_plans.id = obj.plan_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{works_table_name} works SET plan_id = (
        SELECT plans.id FROM #{new_plans_table_name} plans, #{old_plans_table_name} old_plans WHERE plans.identifier = old_plans.identifier AND old_plans.type = 'Plan' AND old_plans.id = works.plan_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      DELETE FROM #{old_plans_table_name} WHERE type = 'Plan'
    SQL

    remove_column :deliverables, :start_at
    remove_column :deliverables, :end_at
    remove_column :deliverables, :program_id

    Project.reset_column_information
    Plan.reset_column_information
    Program.reset_column_information
  end

  def self.down
    new_plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    old_plans_table_name = ActiveRecord::Base.connection.safe_table_name('plans')
    objectives_table_name = ActiveRecord::Base.connection.safe_table_name('objectives')
    works_table_name = ActiveRecord::Base.connection.safe_table_name('works')

    add_column :deliverables, :start_at, :date
    add_column :deliverables, :end_at, :date
    add_column :deliverables, :program_id, :integer

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO #{new_plans_table_name} (id, identifier, name, start_at, end_at, program_id, created_at, updated_at, type)
          SELECT (#{ActiveRecord::Base.connection.next_id_sql(new_plans_table_name)}), identifier, name, start_at, end_at, program_id, created_at, updated_at, 'Plan'
            FROM #{old_plans_table_name}
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{objectives_table_name} obj SET plan_id = (
        SELECT plans.id FROM #{new_plans_table_name} plans, #{old_plans_table_name} old_plans WHERE plans.identifier = old_plans.identifier AND old_plans.id = obj.plan_id AND plans.program_id = old_plans.program_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{works_table_name} works SET plan_id = (
        SELECT plans.id FROM #{new_plans_table_name} plans, #{old_plans_table_name} old_plans WHERE plans.identifier = old_plans.identifier AND old_plans.id = works.plan_id AND plans.program_id = old_plans.program_id)
    SQL

    drop_table :plans

    Project.reset_column_information
    Plan.reset_column_information
    Program.reset_column_information
  end
end
