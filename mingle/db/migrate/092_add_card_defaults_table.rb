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

class M92TransitionAction < ActiveRecord::Base
  set_table_name :transition_actions
  belongs_to :executor, :polymorphic => true
end

class M92PropertyDefinition < ActiveRecord::Base
  set_table_name :property_definitions
  self.inheritance_column = 'm92_type' # disable single table inheritance
  belongs_to :project, :class_name => 'M92Project', :foreign_key => 'project_id'
end

class OldCardDefaults < ActiveRecord::Base
  belongs_to :project, :class_name => 'M92Project', :foreign_key => 'project_id'
end

class M92CardDefault < ActiveRecord::Base
  set_table_name :card_defaults
  belongs_to :project, :class_name => 'M92Project', :foreign_key => 'project_id'
end


class M92Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :old_card_defaults, :class_name => 'OldCardDefaults', :foreign_key => 'project_id'
  has_many :property_definitions, :class_name => 'M92PropertyDefinition', :foreign_key => 'project_id'

  cattr_accessor :current
  def activate
    @@current = self
    OldCardDefaults.set_table_name("#{ActiveRecord::Base.table_name_prefix}#{identifier}_card_defaults")
    OldCardDefaults.reset_column_information
  end

  def deactivate
    OldCardDefaults.set_table_name nil
    @@current = nil
  end

  def with_active_project
    previous_active_project = @@current
    begin
      if previous_active_project
        previous_active_project.deactivate
      end
      activate
      yield(self)
    ensure
      deactivate
      if previous_active_project
        previous_active_project.activate
      end
    end
  end
end



class AddCardDefaultsTable < ActiveRecord::Migration
  def self.up
    drop_table 'card_defaults' if table_exists?("#{ActiveRecord::Base.table_name_prefix}card_defaults")
    
    create_table :card_defaults do |t|
      t.column "card_type_id",           :integer,  :null => false
      t.column "project_id",             :integer,  :null => false
      t.column "description",            :text
    end

    M92Project.find(:all).each do |project| 
      next unless table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_card_defaults")
      project.with_active_project do |project|
        project.old_card_defaults.each do |old_card_defaults|
          new_card_default = M92CardDefault.create!(:card_type_id => old_card_defaults.card_type_id, :project_id => project.id, :description => old_card_defaults.description)
          
          project.property_definitions.each do |prop_def|
            db_identifier = old_card_defaults.send(prop_def.column_name)
            db_identifier = (db_identifier.blank? ? nil : db_identifier.to_s)
            M92TransitionAction.create!(:executor_id => new_card_default.id, :executor_type => 'CardDefaults', :property_definition_id => prop_def.id, :value => db_identifier) if db_identifier
          end
        end
      end
      
      drop_table "#{project.identifier}_card_defaults"
      if (sequence = Sequence.find(:first, :conditions => {:name => "card_defaults"}, :lock => true))
        sequence.destroy
      end  
    end  
  end

  def self.down
  end
end
