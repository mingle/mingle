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

class AddPositionToTaggings < ActiveRecord::Migration[5.0]
  def self.up
    add_column :taggings, :position, :integer, :null => false, :default => 0 unless column_exists?(:taggings, :position)
    Tagging.reset_column_information
  end

  def self.down
    remove_column :taggings, :position
    Tagging.reset_column_information
  end
end
