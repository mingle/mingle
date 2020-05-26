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

class CardListView090 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  self.inheritance_column = 'm90_type' # disable single table inheritance
end

class Page090 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}pages"
  
  def identifier
    self.name.gsub(/ /, '_')
  end
end

class Favorite090 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}favorites"
end

class AddFavoritesTable < ActiveRecord::Migration
  def self.up
    create_table "favorites", :force => true do |t|
      t.column "project_id",      :integer, :null => false
      t.column "favorited_type",  :string,  :null => false
      t.column "favorited_id",    :integer, :null => false
      t.column "tab_view",        :boolean, :null => false, :default => false
    end
    
    card_list_views = CardListView090.find(:all)
    card_list_views.each do |card_list_view|
      card_list_view_type = card_list_view.attributes['type']
      favorited_id = card_list_view.id
      if (card_list_view_type == 'PageView')
        favorited_id = Page090.find_by_name_and_project_id(card_list_view.name, card_list_view.project_id).id
      end
      type = (card_list_view_type == 'PageView') ? 'Page' : 'CardListView'
      Favorite090.create!(:project_id => card_list_view.project_id, :favorited_type => type, :favorited_id => favorited_id, :tab_view => card_list_view.tab_view)
      card_list_view.destroy if (card_list_view_type == 'PageView')
    end
    
    remove_column :card_list_views, :favorite
    remove_column :card_list_views, :tab_view
    remove_column :card_list_views, :type
    CardListView.reset_column_information
  end

  def self.down
    add_column :card_list_views, :favorite, :boolean, :default => true
    add_column :card_list_views, :tab_view, :boolean, :default => false
    add_column :card_list_views, :type,     :string, :default => 'CardListView'
    
    Favorite090.find(:all).each do |favorite|
      card_list_view = if (favorite.favorited_type == 'Page')
        page = Page090.find_by_id(favorite.favorited_id)
        CardListView090.create!(:project_id => favorite.project_id, :name => page.name, :params => {:page_identifier => page.identifier}, :type => 'PageView')
      else
        card_list_view = CardListView090.find_by_id(favorite.favorited_id) 
        card_list_view.type = 'CardListView'
        card_list_view
      end
      card_list_view.favorite = !favorite.tab_view
      card_list_view.tab_view = favorite.tab_view
      card_list_view.save!
    end
    
    drop_table 'favorites'
    CardListView.reset_column_information
  end
end
