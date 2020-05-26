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

class ConvertCardListViewParamsAndCanonicalStringToNewStyle < ActiveRecord::Migration
  def self.up
    M20111116223915CardListView.find_each do |view|
      params = JvYAML.load(view.params)
      params[:aggregate_type] = {:column => params[:aggregate_type]} if params[:aggregate_type]
      params[:aggregate_property] = {:column => params[:aggregate_property]} if params[:aggregate_property]
      params[:group_by] = {'lane' => params[:group_by]} if params[:group_by].is_a?(String)
      view.params = JvYAML.dump(params)
      view.canonical_string = params.joined_ordered_values_by_smart_sorted_keys
      view.save!
    end
  end

  def self.down
  end
end

class M20111116223915CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
end
