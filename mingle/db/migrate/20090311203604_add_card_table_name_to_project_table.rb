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

class Project20090311203604 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class AddCardTableNameToProjectTable < ActiveRecord::Migration
  def self.up
    add_column :projects, :cards_table, :string
    add_column :projects, :card_versions_table, :string
    Project.reset_column_information

    Project20090311203604.find(:all).each do |project|
      card_table_name = CardSchema.generate_cards_table_name(project.identifier)
      card_version_table_name = CardSchema.generate_card_versions_table_name(project.identifier)
      execute("UPDATE #{Project20090311203604.table_name} SET cards_table='#{safe_table_name(card_table_name)}', card_versions_table='#{safe_table_name(card_version_table_name)}' WHERE id=#{project.id}")
    end
  end

  def self.down
    remove_column :projects, :cards_table
    remove_column :projects, :card_versions_table
    Project.reset_column_information
  end
end
