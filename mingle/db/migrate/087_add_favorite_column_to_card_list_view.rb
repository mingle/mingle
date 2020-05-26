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

class CardListView087 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  self.inheritance_column = 'm87_type' # disable single table inheritance
end

class AddFavoriteColumnToCardListView < ActiveRecord::Migration
  def self.up
    add_column :card_list_views, :favorite, :boolean, :default => true
    change_column_default :card_list_views, :tab_view, false
    CardListView.reset_column_information
    
    CardListView087.find(:all).each do |favorite|
      favorite.tab_view ||= false
      favorite.favorite = !favorite.tab_view
      favorite.save!
    end
  end

  def self.down
    remove_column :card_list_views, :favorite
    change_column_default :card_list_views, :tab_view, nil
    CardListView.reset_column_information
  end
end
