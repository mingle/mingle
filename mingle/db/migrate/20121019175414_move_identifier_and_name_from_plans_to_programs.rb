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

class MoveIdentifierAndNameFromPlansToPrograms < ActiveRecord::Migration
  def self.up
    add_column :programs, :identifier, :string
    add_column :programs, :name, :string
    
    programs_table_name = ActiveRecord::Base.connection.safe_table_name('programs')
    plans_table_name = ActiveRecord::Base.connection.safe_table_name('deliverables')
    
    ActiveRecord::Base.connection.execute <<-SQL
    UPDATE #{programs_table_name} programs 
        SET identifier = (SELECT identifier FROM #{plans_table_name} plans WHERE plans.program_id = programs.id AND plans.type='Plan'),
            name = (SELECT name FROM #{plans_table_name} plans WHERE plans.program_id = programs.id and plans.type='Plan')
        WHERE EXISTS (SELECT identifier FROM #{plans_table_name} plans WHERE plans.program_id = programs.id AND plans.type='Plan')
    SQL
    
    change_column :programs, :identifier, :string, :null => false
    change_column :programs, :name, :string, :null => false
  end

  def self.down
    remove_column :programs, :identifier
    remove_column :programs, :name
  end
end
