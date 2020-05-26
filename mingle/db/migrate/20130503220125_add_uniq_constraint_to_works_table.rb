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

class AddUniqConstraintToWorksTable < ActiveRecord::Migration
  def self.up
    execute("delete from #{safe_table_name('works')} where id not in (select min(id) as id from #{safe_table_name('works')} group by card_number, project_id, objective_id)")
    add_index(:works, [:objective_id, :card_number, :project_id], :unique => true, :name => "#{ActiveRecord::Base.table_name_prefix}idx_card_work")
  end

  def self.down
    remove_index(:works, :name => "#{ActiveRecord::Base.table_name_prefix}idx_card_work")
  end
end
