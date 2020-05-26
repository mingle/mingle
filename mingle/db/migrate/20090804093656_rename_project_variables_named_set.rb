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

class ProjectVariable20090804093656 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}project_variables"
end

class CardListView20090804093656 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  serialize :params
end


class TreeFilters20090804093656
  class << self
    def create_key(card_type_name)
      "tf_#{card_type_name}"
    end
  end  
end

class CardType20090804093656 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types"
end

class Project20090804093656 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class RenameProjectVariablesNamedSet < ActiveRecord::Migration
  POSTFIX_SEPERATOR = '_' unless defined?(POSTFIX_SEPERATOR)
  def self.up
    # Can be temporary. This was just an initial class naming mistake.
    execute("UPDATE #{safe_table_name('transition_prerequisites')} SET type = 'HasAnyValue' WHERE type = 'HasSetValue'")
    
    Project20090804093656.find(:all).each do |project|
      old_name_to_new_name = {}
      results = ActiveRecord::Base.connection.select_all("SELECT id, name FROM #{ProjectVariable20090804093656.quoted_table_name} WHERE (LOWER(name) = 'set') AND project_id = #{project.id}")
      
      results.each do |result|
        similarly_named_ones = ProjectVariable20090804093656.find(:all, :conditions => "(LOWER(name) LIKE '#{result['name'].downcase}#{POSTFIX_SEPERATOR}%') AND project_id = #{project.id}").collect(&:name).collect(&:downcase)
        new_name = next_available_name(result['name'], similarly_named_ones)
        ActiveRecord::Base.connection.execute("UPDATE #{ProjectVariable20090804093656.quoted_table_name} SET name = '#{new_name}' WHERE id = #{result['id']}")
        old_name_to_new_name["(#{result['name']})"] = "(#{new_name})"
      end
      
      all_card_type_names = ActiveRecord::Base.connection.select_all("SELECT name FROM #{CardType20090804093656.quoted_table_name} WHERE project_id = #{project.id}").collect(&:values).flatten.uniq
      
      CardListView20090804093656.find(:all, :conditions => "project_id = #{project.id}").each do |view|
        replace_filters_for_key(:filters, view, old_name_to_new_name)
        
        all_card_type_names.each do |card_type_name|
          tree_filter_key = TreeFilters20090804093656.create_key(card_type_name).to_sym
          replace_filters_for_key(tree_filter_key, view, old_name_to_new_name)
        end
        
        # these canonical strings seem to always have with downcased values, so we make sure to downcase the new value names
        view.canonical_string = replace_filters_in_string(view.canonical_string, old_name_to_new_name, :downcase_value => true) unless view.canonical_string.blank?
        view.save
      end
    end
  end
  
  def self.replace_filters_for_key(key, view, old_name_to_new_name)
    if view.params.keys.collect { |the_key| the_key.to_s.downcase }.include?(key.to_s.downcase)
      actual_key = view.params.keys.detect { |the_key| the_key.to_s.downcase == key.to_s.downcase }
      if no_mql_filters(view.params[actual_key])
        original_value = view.params[actual_key] || []
        new_value = original_value.collect do |filter_string|
          replace_filters_in_string(filter_string, old_name_to_new_name)
        end
        view.params[actual_key] = new_value if original_value != new_value
      end
    end
  end
  
  def self.no_mql_filters(param)
    !(param || []).any? { |filter_string| mql_filter?(filter_string) }
  end
  
  def self.mql_filter?(filter_string)
    Array === filter_string
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
