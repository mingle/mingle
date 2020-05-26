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

class FixCardsTableColumns < ActiveRecord::Migration
  def self.up
    add_column :cards, :project_card_rank, :integer
    add_column :cards, :caching_stamp, :integer, :null => false, :default => 0

    remove_column :cards, :name
    remove_column :cards, :created_by_user_id
    remove_column :cards, :modified_by_user_id
    add_column :cards, :name, :string, :null => false
    add_column :cards, :created_by_user_id, :integer, :null => false
    add_column :cards, :modified_by_user_id, :integer, :null => false

    remove_column :cards, :tag_list
  end

  def self.down
    remove_column :cards, :caching_stamp
    remove_column :cards, :project_card_rank

    remove_column :cards, :name
    remove_column :cards, :created_by_user_id
    remove_column :cards, :modified_by_user_id
    add_column :cards, :name, :string, :null => false, :default => ''
    add_column :cards, :created_by_user_id, :integer, :null => false, :default => 0
    add_column :cards, :modified_by_user_id, :integer, :null => false, :default => 0

    add_column :cards, :tag_list, :text
  end
end
