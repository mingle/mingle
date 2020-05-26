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

class M104CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  serialize :params

  def canonicalize!
    non_serialized_parameters = {:tab => nil, :all_cards_selected => nil, :expanded => nil}
    action =  params.delete(:action)
    state_params = params.merge(non_serialized_parameters)
    state_params = state_params.merge(:style => action.blank? ? 'list' : action) if params[:style].blank?
    update_attributes(:canonical_string => state_params.joined_ordered_values_by_smart_sorted_keys)

    sorted_filters = (params[:filters] || []).smart_sort.join(',')
    sorted_tags = (params[:tagged_with] || '').split(',').collect(&:downcase).smart_sort.join(',')
    filter_strings = []
    filter_strings << "filters=#{sorted_filters}" unless sorted_filters.blank?
    filter_strings << "tagged_with=#{sorted_tags}" unless sorted_tags.blank?
    update_attributes(:canonical_filter_string => filter_strings.join(','))
  end 
end

class AddCanonicalStringFormToCardListViews < ActiveRecord::Migration
  def self.up
    add_column :card_list_views, :canonical_string, :text, :default => nil
    add_column :card_list_views, :canonical_filter_string, :text, :default => nil
    M104CardListView.find(:all).each(&:canonicalize!)
  end

  def self.down
    remove_column :card_list_views, :canonical_string, :text
    remove_column :card_list_views, :canonical_filter_string, :text
  end
end
