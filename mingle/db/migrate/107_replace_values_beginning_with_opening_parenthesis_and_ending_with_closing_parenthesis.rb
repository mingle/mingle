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

class Project107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'PropertyDefinition107', :foreign_key => 'project_id'
  has_many :cards, :class_name => 'Card107', :foreign_key => 'project_id'
  has_many :transitions, :class_name => 'Transition107', :foreign_key => 'project_id'
  has_many :card_defaults, :class_name => 'CardDefaults107', :foreign_key => 'project_id'
  has_many :card_list_views, :class_name => 'CardListView107', :foreign_key => 'project_id'

  def activate
    Card107.set_table_name "#{ActiveRecord::Base.table_name_prefix}#{identifier}_cards"
    Card107.reset_column_information
  end
end

class EnumerationValue107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}enumeration_values"
  belongs_to :property_definition, :class_name => "EnumeratedPropertyDefinition107", :foreign_key => "property_definition_id"
end

class PropertyDefinition107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'disable_single_table_inheritance'
  has_many :enumeration_values, :class_name => 'EnumerationValue107', :foreign_key => 'property_definition_id'
  belongs_to :project, :class_name => 'Project107', :foreign_key => 'project_id'
end

class CardListView107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  belongs_to :project, :class_name => 'Project107', :foreign_key => 'project_id'
end

class Card107 < ActiveRecord::Base
  belongs_to :project, :class_name => 'Project107', :foreign_key => 'project_id'
end

class CardDefaults107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_defaults"
  belongs_to :project, :class_name => 'Project107', :foreign_key => 'project_id'
  has_many :actions, :conditions => ["#{MigrationHelper.safe_table_name('transition_actions')}.executor_type = ?", 'CardDefaults'], :class_name => 'TransitionActions107', :foreign_key => 'executor_id'
  
end

class Transition107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transitions"
  belongs_to :project, :class_name => 'Project107', :foreign_key => 'project_id'
  has_many :prerequisites, :conditions => ["#{MigrationHelper.safe_table_name('transition_prerequisites')}.type = ?", 'HasValue'], :class_name => 'TransitionPrerequisites107', :foreign_key => 'transition_id'
  has_many :actions, :conditions => ["#{MigrationHelper.safe_table_name('transition_actions')}.executor_type = ?", 'Transition'], :class_name => 'TransitionActions107', :foreign_key => 'executor_id'
  
end

class TransitionPrerequisites107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transition_prerequisites"
  self.inheritance_column = 'disable_single_table_inheritance'
  belongs_to :property_definition, :class_name => 'EnumeratedPropertyDefinition107', :foreign_key => 'property_definition_id'
  belongs_to :transition, :class_name => 'Transition107', :foreign_key => 'transition_id'
  
end

class TransitionActions107 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transition_actions"
  belongs_to :property_definition, :class_name => 'EnumeratedPropertyDefinition107', :foreign_key => 'property_definition_id'
  belongs_to :transition, :class_name => 'Transition107', :foreign_key => 'executor_id'
  belongs_to :card_defaults, :class_name => 'Transition107', :foreign_key => 'executor_id'
end

class ReplaceValuesBeginningWithOpeningParenthesisAndEndingWithClosingParenthesis < ActiveRecord::Migration
  def self.up
    PropertyDefinition107.find_all_by_type('EnumeratedPropertyDefinition').each do |property_definition|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{property_definition.project.identifier}_cards")
      
      property_definition.project.activate
      enumeration_values = property_definition.enumeration_values
      enumeration_value_values = enumeration_values.collect(&:value)
      property_definition.enumeration_values.each do |enum_value|
        if (core_value = enum_value.value =~ /^\((.*)\)$/ ? $1 : nil)
          from_value = "(#{core_value})"
          to_value = next_available_name(from_value, "|#{core_value}|", enumeration_value_values)
          
          enum_value = enumeration_values.detect{ |value| value.value.downcase == from_value.downcase }
          enum_value.update_attribute :value, to_value
          
          (project = property_definition.project).cards.find(:all, :conditions => ["#{quote_column_name property_definition.column_name} = ?", from_value]).each do |card|
            card.update_attribute property_definition.column_name.to_sym, to_value
          end
          
          project.transitions.each do |transition|
            prerequisites = transition.prerequisites
            rename_prerequisites_or_actions(prerequisites, property_definition.id, from_value, to_value)
            rename_prerequisites_or_actions transition.actions, property_definition.id, from_value, to_value
          end
          
          project.card_defaults.each do |card_default|
            rename_prerequisites_or_actions card_default.actions, property_definition.id, from_value, to_value
          end
          
          project.card_list_views.each do |card_list_view|
            [:params, :canonical_string, :canonical_filter_string].each do |column|
              card_list_view.send(column).gsub!(/#{Regexp.escape(from_value)}/, to_value) if card_list_view.send(column)
            end
            card_list_view.save
          end
        end
      end
    end
  end
  
  def self.down
    # without a paddle.
  end
  
  private
  
  def self.next_available_name(name, to_name, similarly_named_ones)
    similarly_named_ones = similarly_named_ones.collect(&:downcase)
    i = 1
    i+=1 while (similarly_named_ones.include?("#{to_name.downcase}_#{i}"))
    "#{to_name}_#{i}"
  end
  
  def self.rename_prerequisites_or_actions(prerequisites_or_actions, property_definition_id, from_value, to_value)
    prerequisites_or_actions.find(:all, :conditions => ["property_definition_id = ? AND value = ?", property_definition_id, from_value]).each do |prerequisite_or_action|
      prerequisite_or_action.value = to_value
      prerequisite_or_action.save
    end
  end
end
