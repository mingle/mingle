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

class ChangePlanMembershipsToProgram < ActiveRecord::Migration
  def self.up
    user_memberships_table_name = ActiveRecord::Base.connection.safe_table_name('user_memberships')
    groups_table_name = ActiveRecord::Base.connection.safe_table_name('groups')
    programs_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')

    ActiveRecord::Base.connection.execute <<-SQL
      DELETE FROM #{user_memberships_table_name} user_memberships WHERE user_memberships.group_id IN
        (SELECT groups.id FROM #{groups_table_name} groups WHERE groups.deliverable_id IN
          (SELECT programs.id FROM #{programs_table_name} programs WHERE programs.type = 'Program'))
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      DELETE FROM #{groups_table_name} groups WHERE groups.deliverable_id IN
        (SELECT programs.id FROM #{programs_table_name} programs WHERE programs.type = 'Program')
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{groups_table_name} g set deliverable_id = (SELECT pr.program_id FROM #{programs_table_name} pr WHERE pr.id = g.deliverable_id)
        WHERE EXISTS (select pl.id from #{plans_table_name} pl where pl.type = 'Plan' and pl.id = g.deliverable_id)
    SQL
  end

  def self.down
    groups_table_name = ActiveRecord::Base.connection.safe_table_name('groups')
    programs_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')

    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{groups_table_name} g set deliverable_id = (SELECT pl.id FROM #{plans_table_name} pl WHERE pl.type = 'Plan' AND pl.program_id = g.deliverable_id)
        WHERE EXISTS (select pr.id from #{programs_table_name} pr where pr.type = 'Program' and pr.id = g.deliverable_id)
    SQL
  end
end
