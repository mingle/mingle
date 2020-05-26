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

class ChangeStaleAggregatesToAccomodateStaleFormulas < ActiveRecord::Migration
  def self.up
    rename_column("stale_aggregates", "aggregate_prop_def_id", "prop_def_id")    
    rename_table("stale_aggregates", "#{ActiveRecord::Base.table_name_prefix}stale_prop_defs")
  end

  def self.down
    rename_table("stale_prop_defs", "stale_aggregates")
    rename_column("stale_aggregates", "prop_def_id", "aggregate_prop_def_id")
  end
end
