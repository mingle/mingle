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

class FixDuplicatedRubyNameBetweenCardPropertyAndUserProperty < ActiveRecord::Migration
  def self.up
    M20110308011508Project.find(:all).each do |project|
      card_schema = project.card_schema
      user_and_card_pds = project.user_property_definitions + project.card_relationship_property_definitions + project.tree_relationship_property_definitions
      user_and_card_pds.each do |pd|
        next unless user_and_card_pds.count { |p| p.ruby_name == pd.ruby_name } > 1
        new_ruby_name = card_schema.send(:generate_unique_column_name, pd.ruby_name, nil)
        pd.update_attributes(:ruby_name => new_ruby_name)
      end
    end
  end

  def self.down
  end
end

class M20110308011508Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :all_property_definitions, :class_name => 'M20110308011508PropertyDefinition', :foreign_key => 'project_id'
  has_many :property_definitions_with_hidden_for_migration, :class_name => 'M20110308011508PropertyDefinition', :foreign_key => 'project_id'
  
  def card_schema
    CardSchema.new(self)
  end
  
  def user_property_definitions
    select_property_definitions_of_type 'UserPropertyDefinition'
  end
  
  def card_relationship_property_definitions
    select_property_definitions_of_type 'CardRelationshipPropertyDefinition'
  end

  def tree_relationship_property_definitions
    select_property_definitions_of_type 'TreeRelationshipPropertyDefinition'
  end
  
  def select_property_definitions_of_type(klass)
    all_property_definitions.select { |pd| pd.read_attribute(:type) == klass }
  end
end

class M20110308011508PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'M20110308011508_type' # disable single table inheretance
  belongs_to :project, :class_name => "M20110308011508Project", :foreign_key => "project_id"
end
