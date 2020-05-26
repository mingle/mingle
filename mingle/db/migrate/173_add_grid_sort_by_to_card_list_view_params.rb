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

class AddGridSortByToCardListViewParams < ActiveRecord::Migration
  class M171CardListView < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
    serialize :params
    before_save :build_canonical_string
    
    def build_canonical_string
      self.canonical_string = self.params.joined_ordered_values_by_smart_sorted_keys
    end
  end

  def self.up
    M171CardListView.find(:all).each do |view|
      view.params[:grid_sort_by] = view.params[:color_by] if view.params[:color_by]
      view.save!
    end
  end

  def self.down
    M171CardListView.find(:all).each do |view|
      view.params.delete(:grid_sort_by)
      view.save!
    end
  end
end
