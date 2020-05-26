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

class AddIdentifierToStream < ActiveRecord::Migration
  def self.up
    add_column :streams, :identifier, :string, :limit => safe_limit(40)
    generate_identifiers_for_existing_streams
  end

  def self.down
    remove_column :streams, :identifier
  end

  def self.generate_identifiers_for_existing_streams
    MI20120517192314Stream.all.each do |stream|
      stream.identifier = stream.name.gsub(/ /, "_") unless stream.identifier
      stream.save!
    end
  end
end


class MI20120517192314Stream < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}streams"
end
