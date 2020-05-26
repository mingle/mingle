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

class AddProjectCardRankToCardsTable < ActiveRecord::Migration
  def self.up
    select_values("SELECT identifier FROM #{safe_table_name('projects')}").each do |project_identifier|
      add_column "#{project_identifier}_cards", :project_card_rank, :integer
      
      execute <<-EOS
        UPDATE #{quote_table_name(safe_table_name("#{project_identifier}_cards"))}
           SET project_card_rank = #{ quote_column_name('number') }
      EOS
    end
  end

  def self.down
    select_values("SELECT identifier FROM #{safe_table_name('projects')}").each do |project_identifier|
      remove_column "#{project_identifier}_cards", :project_card_rank
    end
  end
end
