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

class ShortenTableNameForOracleCompatibility < ActiveRecord::Migration
  def self.up
    rename_table :card_types_property_definitions, safe_table_name('property_type_mappings')
    rename_table :update_renderable_cache_requests, safe_table_name('recache_renderable_reqs')
  end

  def self.down
    rename_table :recache_renderable_reqs, safe_table_name('update_renderable_cache_requests')
    rename_table :property_type_mappings, safe_table_name('card_types_property_definitions')
  end
end
