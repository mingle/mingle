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

class RemovePersonalFavoritesFromOldTemplates < ActiveRecord::Migration
  def self.up
    M20110107222440Project.all(:conditions => { :template => true }).each do |template|
      view_favorites_to_delete = template.favorites.all(:conditions => "favorited_type = 'CardListView' AND user_id IS NOT NULL")
      views_to_delete = template.card_list_views.find(view_favorites_to_delete.map(&:favorited_id))

      view_favorites_to_delete.each(&:destroy)
      views_to_delete.each(&:destroy)

      page_favorites_to_delete = template.favorites.all(:conditions => "favorited_type = 'Page' AND user_id IS NOT NULL")
      page_favorites_to_delete.each(&:destroy)
    end
  end

  def self.down
  end
end

class M20110107222440Favorite < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}favorites"
  self.inheritance_column = 'M20110107222440_type' #disable single table inheretance

  belongs_to :project, :foreign_key => 'project_id', :class_name => 'M20110107222440Project'
end

class M20110107222440CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  belongs_to :project, :foreign_key => 'project_id', :class_name => 'M20110107222440Project'
end

class M20110107222440Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :card_list_views, :class_name => 'M20110107222440CardListView', :foreign_key => 'project_id'
  has_many :favorites, :class_name => 'M20110107222440Favorite', :foreign_key => 'project_id'
end
