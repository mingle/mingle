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

class MakeProgramADeliverable < ActiveRecord::Migration
  def self.up
    deliverables_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    programs_table_name = ActiveRecord::Base.connection.safe_table_name('programs')
    backlogs_table_name = ActiveRecord::Base.connection.safe_table_name('backlogs')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    program_project_table_name = ActiveRecord::Base.connection.safe_table_name('program_projects')

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO #{deliverables_table_name} (id, identifier, name, created_at, updated_at, type)
          SELECT (#{ActiveRecord::Base.connection.next_id_sql(deliverables_table_name)}), identifier, name, created_at, updated_at, 'Program' FROM #{programs_table_name}
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{backlogs_table_name} backlogs
        SET program_id = (SELECT deliverables.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE programs.id = backlogs.program_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{plans_table_name} plans
        SET program_id = (SELECT deliverables.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE programs.id = plans.program_id)
        WHERE type = 'Plan'
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{program_project_table_name} program_projects
        SET program_id = (SELECT deliverables.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE programs.id = program_projects.program_id)
    SQL

    drop_table :programs
  end

  def self.down
    create_table :programs do |table|
      table.string :identifier
      table.string :name
      table.timestamps
    end

    deliverables_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    programs_table_name = ActiveRecord::Base.connection.safe_table_name('programs')
    backlogs_table_name = ActiveRecord::Base.connection.safe_table_name('backlogs')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    program_project_table_name = ActiveRecord::Base.connection.safe_table_name('program_projects')

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO #{programs_table_name} (id, identifier, name, created_at, updated_at)
          SELECT (#{ActiveRecord::Base.connection.next_id_sql(programs_table_name)}), identifier, name, created_at, updated_at FROM #{deliverables_table_name} WHERE type = 'Program'
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{backlogs_table_name} backlogs
        SET program_id = (SELECT programs.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE deliverables.id = backlogs.program_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{plans_table_name} plans
        SET program_id = (SELECT programs.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE deliverables.id = plans.program_id)
        WHERE type = 'Plan'
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{program_project_table_name} program_projects
        SET program_id = (SELECT programs.id AS new_id FROM #{programs_table_name} programs
          INNER JOIN #{deliverables_table_name} deliverables ON deliverables.identifier = programs.identifier AND deliverables.type = 'Program'
          WHERE deliverables.id = program_projects.program_id)
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      DELETE FROM #{deliverables_table_name} WHERE type = 'Program'
    SQL

  end
end
