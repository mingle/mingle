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

class M20100623012305Project < ActiveRecord::Base
  INTERNAL_TABLE_PREFIX_PATTERN = /^mi_\d{6}/ unless defined?(INTERNAL_TABLE_PREFIX_PATTERN)
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  def card_versions_table_name
    CardSchema.generate_card_versions_table_name(self.identifier)
  end
end

class IndexCardVersionsOnUpdatedAt < ActiveRecord::Migration
  include MigrationHelper
      
  def self.up
    M20100623012305Project.find(:all).each do |project|
      next if project.card_versions_table_name =~ M20100623012305Project::INTERNAL_TABLE_PREFIX_PATTERN
      execute "CREATE INDEX #{index_name(project.card_versions_table_name, :column => 'updated_at')} ON #{safe_table_name(project.card_versions_table_name)} (UPDATED_AT DESC)"
    end
  end

  def self.down
    M20100623012305Project.find(:all).each do |project|
      next if project.card_versions_table_name =~ M20100623012305Project::INTERNAL_TABLE_PREFIX_PATTERN
      execute "DROP INDEX #{index_name(project.card_versions_table_name, :column => 'updated_at')}"
    end
  end
end
