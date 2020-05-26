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

class M58CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  serialize :params
  
  IGNORED_IDENTIFIER = ":ignore" unless defined?(IGNORED_IDENTIFIER)

  def change_filters_to_new_form!
    old_filters = self.params.delete(:filter_properties)
    return unless old_filters
    self.params.merge!(:filters => new_filters_from(old_filters))
    save!
  end
  
  def new_filters_from(old_filters)
    old_filters.inject([]) do |result, property_name_value_pair|
      property_name, value = property_name_value_pair
      result << (value == IGNORED_IDENTIFIER ? nil : "[#{property_name}][is][#{value}]")
    end.compact
  end  
end

class ChangeOldSavedViewsToNewFilterFormat < ActiveRecord::Migration
  def self.up
    M58CardListView.find(:all).each do |view|
      begin
        view.change_filters_to_new_form!
      rescue Exception => e
        begin
          view.delete
          M58CardListView.logger.error("Unexpected error while migrating saved view named '#{view.name}'")
          M58CardListView.logger.error("Deleting saved view '#{view.name}' to prevent data corruption")
          M58CardListView.logger.error(e)
        rescue Exception => e
          #Can't do anything, really. Ignore.
        end    
      end    
    end  
  end

  def self.down
    M58CardListView.delete_all
  end
end
