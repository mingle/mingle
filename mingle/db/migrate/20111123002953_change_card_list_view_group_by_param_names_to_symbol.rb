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

class ChangeCardListViewGroupByParamNamesToSymbol < ActiveRecord::Migration
  class MCardListView < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  end

  def self.up
    MCardListView.find_each do |view|
      params = JvYAML.load(view.params)
      if params[:group_by]
        group_by_params = {}
        group_by_params[:lane] = params[:group_by]['lane'] if params[:group_by]['lane']
        group_by_params[:row] = params[:group_by]['row'] if params[:group_by]['row']
        params[:group_by] = group_by_params
      end
      view.params = JvYAML.dump(params)
      view.save!
    end
  end

  def self.down
    MCardListView.find_each do |view|
      params = JvYAML.load(view.params)
      if params[:group_by]
        group_by_params = {}
        group_by_params['lane'] = params[:group_by][:lane] if params[:group_by][:lane]
        group_by_params['row'] = params[:group_by][:row] if params[:group_by][:row]
        params[:group_by] = group_by_params
      end
      view.params = JvYAML.dump(params)
      view.save!
    end
  end
end
