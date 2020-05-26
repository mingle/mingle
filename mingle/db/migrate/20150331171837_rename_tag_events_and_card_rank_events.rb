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

class RenameTagEventsAndCardRankEvents < ActiveRecord::Migration
  def self.up
    type_map.each do |old_name, new_name|
      execute SqlHelper.sanitize_sql("UPDATE events SET type = ? WHERE type = ?", new_name, old_name)
    end
  end

  def self.down
    type_map.each do |old_name, new_name|
      execute SqlHelper.sanitize_sql("UPDATE events SET type = ? WHERE type = ?", old_name, new_name)
    end
  end

  def self.type_map
    {
      "TagEvent::Create" => "LiveOnlyEvents::TagCreate",
      "TagEvent::Update" => "LiveOnlyEvents::TagUpdate",
      "TagEvent::Delete" => "LiveOnlyEvents::TagDelete",
      "CardRankEvent"    => "LiveOnlyEvents::CardRank",
    }
  end
end
