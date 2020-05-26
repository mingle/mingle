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


class M146ProjectVariable < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}project_variables"
end

class M146CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  serialize :params
end


class M146TreeFilters
  class << self
    def create_key(card_type_name)
      "tf_#{card_type_name}"
    end
  end  
end

class M146CardType < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types"
end

class M146Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class RenamePlvsUsingUserInputTransitionLabels < ActiveRecord::Migration
  POSTFIX_SEPERATOR = '_' unless defined?(POSTFIX_SEPERATOR)
  
  def self.up
    M146Project.find(:all).each do |project|
      old_name_to_new_name = {}
      results = ActiveRecord::Base.connection.select_all("SELECT id, name FROM #{M146ProjectVariable.quoted_table_name} WHERE (LOWER(name) = 'user input - required' OR LOWER(name) = 'user input - optional') AND project_id = #{project.id}")
      
      results.each do |result|
        similarly_named_ones = M146ProjectVariable.find(:all, :conditions => "(LOWER(name) LIKE '#{result['name'].downcase}#{POSTFIX_SEPERATOR}%') AND project_id = #{project.id}").collect(&:name).collect(&:downcase)
        new_name = next_available_name(result['name'], similarly_named_ones)
        ActiveRecord::Base.connection.execute("UPDATE #{M146ProjectVariable.quoted_table_name} SET name = '#{new_name}' WHERE id = #{result['id']}")
        old_name_to_new_name["(#{result['name']})"] = "(#{new_name})"
      end
      
      all_card_type_names = ActiveRecord::Base.connection.select_all("SELECT name FROM #{M146CardType.quoted_table_name} WHERE project_id = #{project.id}").collect(&:values).flatten.uniq
      
      M146CardListView.find(:all, :conditions => "project_id = #{project.id}").each do |view|
        replace_filters_for_key(:filters, view, old_name_to_new_name)
        
        all_card_type_names.each do |card_type_name|
          tree_filter_key = M146TreeFilters.create_key(card_type_name).to_sym
          replace_filters_for_key(tree_filter_key, view, old_name_to_new_name)
        end
        
        # these canonical strings seem to always have with downcased values, so we make sure to downcase the new value names
        view.canonical_string = replace_filters_in_string(view.canonical_string, old_name_to_new_name, :downcase_value => true) unless view.canonical_string.blank?
        view.canonical_filter_string = replace_filters_in_string(view.canonical_filter_string, old_name_to_new_name, :downcase_value => true) unless view.canonical_filter_string.blank?
        view.save
      end
    end
  end
  
  def self.replace_filters_for_key(key, view, old_name_to_new_name)
    if view.params.keys.collect { |the_key| the_key.to_s.downcase }.include?(key.to_s.downcase)
      actual_key = view.params.keys.detect { |the_key| the_key.to_s.downcase == key.to_s.downcase }
      view.params[actual_key] = (view.params[actual_key] || []).collect do |filter_string|
        replace_filters_in_string(filter_string, old_name_to_new_name)
      end
    end
  end
  
  def self.replace_filters_in_string(str, old_name_to_new_name, options = {})
    # this nasty reg exp matches on [characters other than square brackets][characters other than square brackets][characters other than square brackets]
    # so, for example, we will iterate over two matches in the string "[type][is][card],[tea][is][nice]"
    new_str = str.gsub(/\[([^\[\]]*)\]\[([^\[\]]*)\]\[([^\[\]]*)\]/) do |match|
      property_definition_name = $1
      old_value = $3
      new_name = old_name_to_new_name.find_ignore_case(old_value)
      new_name = new_name.downcase if options[:downcase_value] && !new_name.blank?
      new_name.blank? ? match : "[#{$1}][#{$2}][#{new_name}]"
    end
    new_str ? new_str : str
  end
  
  def self.next_available_name(name, similarly_named_ones)
    i = 1
    i+=1 while (similarly_named_ones.include?("#{name.downcase}#{POSTFIX_SEPERATOR}#{i}"))
    "#{name}#{POSTFIX_SEPERATOR}#{i}"
  end
  
  def self.down
  end
end
