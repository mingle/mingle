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

class AssociateBacklogsWithExistingPrograms < ActiveRecord::Migration
  class M20121002172101Backlog < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("backlogs")
    self.inheritance_column = '9328jkjoji_type' # disable single table inheretance
    
    belongs_to :program, :class_name => 'AssociateBacklogsWithExistingPrograms::M20121002172101Program', :foreign_key => 'program_id'
  end

  class M20121002172101Program < ActiveRecord::Base
    set_table_name MigrationHelper::safe_table_name("programs")
    has_one :backlog, :class_name => 'AssociateBacklogsWithExistingPrograms::M20121002172101Backlog', :foreign_key => 'program_id'
  end

  def self.up
    M20121002172101Program.all.each do |program|
      program.backlog = M20121002172101Backlog.new
      program.save!
    end
  end

  def self.down
    M20121002172101Program.all.each do |program|
      program.backlog.destroy!
      program.backlog = nil
      program.save!
    end
  end
end
