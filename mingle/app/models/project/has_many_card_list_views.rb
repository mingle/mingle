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

class Project
  module HasManyCardListViews

    def self.included(base)
      base.has_many :all_card_list_views, :class_name => 'CardListView', :order => "#{ActiveRecord::Base.table_name_prefix}card_list_views.name", :include => :favorite
    end

    def card_list_views
      all_card_list_views
    end

    def card_list_views_with_sort
      card_list_views.smart_sort_by(&:name)
    end

    def find_or_construct_team_card_list_view(params)
      if params[:filter_tags]
        filter_tags = Tag.parse(params[:filter_tags])
        CardListView.construct_from_params(self, params.merge(:tagged_with => filter_tags))
      elsif params[:view]
        params[:view] = { :name => params[:view] } if params[:view].is_a?(String)
        result = card_list_views.find(:first, :include => :favorite, :conditions => ['LOWER(card_list_views.name) = LOWER(?) AND favorites.user_id IS NULL', params[:view][:name]])
        return nil if !result
        result.fetch_descriptions = params[:format] == "xml" || params[:api_version].present?
        result.page = params[:page] if params[:page]
        result.maximized = params[:maximized] if params[:maximized]
        result
      else
        CardListView.construct_from_params(self, params, true)
      end
    end
  end
end
