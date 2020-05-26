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
  module FavoritesAndTabs

    def self.included(base)
      base.has_many :favorites_and_tabs, :class_name => 'Favorite'
      base.has_many :favorites, :conditions => ['tab_view = ? or tab_view IS NULL', false]
      base.has_many :tabs, :conditions => { :tab_view => true }, :class_name => 'Favorite'
      base.belongs_to :landing_tab, :class_name => 'Favorite'
    end

    def ordered_tab_identifiers
      raw_value = read_attribute(:ordered_tab_identifiers)
      raw_value ? raw_value.split(',') : nil
    end

    def ordered_tab_identifiers=(value)
      stringified_value = case value
                          when String, NilClass
                            value
                          when Array
                            value.empty? ? nil : value.join(",")
                          end

      write_attribute(:ordered_tab_identifiers, stringified_value)
    end

    def gsub_ordered_tab_identifiers(old_to_new_map)
      ids = ordered_tab_identifiers
      return unless ids

      ids.each_with_index do |id, index|
        if new_id = old_to_new_map[id]
          ids[index] = new_id
        end
      end
      self.ordered_tab_identifiers = ids
    end

    def default_view_for_tab(tab_name)
      if tab_name == DisplayTabs::AllTab::NAME
        DisplayTabs::AllTab.all_cards_card_list_view_for(self)
      else
        user_defined_tab = user_defined_tab_favorites.detect { |fave| fave.favorited.name.downcase == tab_name.downcase }
        user_defined_tab.favorited if user_defined_tab
      end
    end

    def user_defined_tab_favorites
      (tabs.of_card_list_views.of_team.include_favorited + tabs.of_pages.of_team.include_favorited).smart_sort_by { |favorite| favorite.favorited.name }
    end
    memoize :user_defined_tab_favorites

  end
end
