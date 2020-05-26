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

class M69Project < ActiveRecord::Base
  INTERNAL_TABLE_PREFIX_PATTERN = /^mi_\d{6}/ unless defined?(INTERNAL_TABLE_PREFIX_PATTERN)
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  def card_versions_table_name
    "#{ActiveRecord::Base.table_name_prefix}#{identifier}_card_versions"
  end
end
class AddIndexToCardVersionTables < ActiveRecord::Migration
  def self.up
    M69Project.find(:all).each do |project|
      unless project.card_versions_table_name =~ M69Project::INTERNAL_TABLE_PREFIX_PATTERN
        add_index(project.card_versions_table_name, :version)
        add_index(project.card_versions_table_name, :card_id)
      end
    end
  end

  def self.down
    M69Project.find(:all).each do |project|
      unless project.card_versions_table_name =~ M69Project::INTERNAL_TABLE_PREFIX_PATTERN
        remove_index(project.card_versions_table_name, :version)
        remove_index(project.card_versions_table_name, :card_id)
      end
    end
  end
end
