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

class M73PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm73_type' # disable single table inheritance
  belongs_to :project, :class_name => 'M73Project', :foreign_key => 'project_id'
  
  def column_type
    case attributes["type"]
      when 'UserPropertyDefinition'
        :integer
      when 'DatePropertyDefinition'  
        :date
      else  
        :string
    end
  end
end

class M73Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M73PropertyDefinition', :foreign_key => 'project_id'
  has_many :card_types, :class_name => 'M73CardType', :foreign_key => 'project_id'
end

class M73CardType < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types"
  belongs_to :project, :class_name => 'M73Project', :foreign_key => 'project_id'
end

class M73TableSequence < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}sequences"
  
  def self.next(name)
    seq = find_or_create_by_name(name)
    seq.last_value ||= 0
    seq.last_value += 1
    seq.save!
    seq.last_value
  end
end

class M73CardDefaults < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_defaults"
  before_create :generate_id

  protected
  
  def generate_id
    self.id = M73TableSequence.next('card_defaults')
  end
end

class M73CardSchema
  def initialize(project)
    @project = project
  end

  def update
    column_holders.each do |column_holder|
      add_column_to_card_defaults_table(column_holder.column_name, column_holder.column_type)
    end
  end

  def column_holders
    @project.reload.property_definitions
  end

  def add_column_to(table_name, column_name, column_type)
    return if column_defined_in_table?(table_name, column_name)
    @project.connection.add_column(table_name, column_name, column_type, :references => nil)    
  end

  def add_column_to_card_defaults_table(column_name, column_type)
    add_column_to(M73CardDefaults.table_name, column_name, column_type)
  end
  
  def column_defined_in_table?(table_name, column_name)
    connection.columns(table_name).any?{|c| c.name == column_name}
  end
  
  def connection
    @project.connection
  end
end

class CreateCardDefaults < ActiveRecord::Migration
  def self.up
    M73Project.find(:all).each do |project|
      unless project.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{card_defaults_table_name(project)}")
        create_table card_defaults_table_name(project) do |t|
          t.column "card_type_id",           :integer,  :null => false
          t.column "project_id",             :integer,  :null => false
          t.column "description",            :text
        end

        activate(project)
    
        card_schema = M73CardSchema.new(project)
        card_schema.update
      end
      
      activate(project)
      
      project.card_types.each do |card_type|
        unless (M73CardDefaults.find_by_card_type_id(card_type.id))
          M73CardDefaults.create!(:card_type_id => card_type.id, :project_id => project.id)
        end
      end
    end
  end

  def self.down
    M73Project.find(:all).each do |project|
      drop_table card_defaults_table_name(project)
    end
  end
  
  def self.card_defaults_table_name(project)
    "#{project.identifier}_card_defaults"
  end
  
  def self.activate(project)
    M73CardDefaults.set_table_name("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_card_defaults")
    M73CardDefaults.reset_column_information
  end
end
