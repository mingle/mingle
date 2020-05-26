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

class RemoveZombieCardDefaults < ActiveRecord::Migration
  def self.up
    zombie_card_types = CardType.all(:conditions => 'project_id is null')
    zombie_card_types.each do |card_type|
      card_type.card_defaults.delete unless card_type.card_defaults.nil?
      card_type.delete
    end

    Project.all.each do |project|
      project.with_active_project do |project|
        zombie_card_defaults = project.card_defaults.select{ |card_defaults| card_defaults.card_type.nil? }
        zombie_card_defaults.each(&:delete)
      end
    end
  end

  def self.down
  end
end
