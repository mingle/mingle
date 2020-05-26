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

class ChangeStreamIdentifiersToLowerCase < ActiveRecord::Migration
  def self.up
    downcase_identifiers_for_existing_streams 
  end

  def self.down
  end
  
  def self.downcase_identifiers_for_existing_streams 
    MI20120529231940Stream.all.each do |stream|
      stream.identifier = stream.identifier.downcase
      stream.save!
    end
  end
end

class MI20120529231940Stream < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}streams"
end
