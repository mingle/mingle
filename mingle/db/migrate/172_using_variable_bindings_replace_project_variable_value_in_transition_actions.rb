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

module M170Utils
  
  def tbl(name)
    "#{ActiveRecord::Base.table_name_prefix}#{name}"
  end
  
end
class UsingVariableBindingsReplaceProjectVariableValueInTransitionActions < ActiveRecord::Migration
  def self.up
    add_column :transition_actions, :variable_binding_id, :integer
    M170TranstionAction.reset_column_information
    M170TranstionAction.all(:conditions => ["project_variable_id IS NOT NULL"]).each do |action|
      binding = M170VariableBinding.find_by_property_definition_id_and_project_variable_id(action.target_id, action.project_variable_id)
      binding ? action.update_attribute(:variable_binding_id, binding.id) : action.destroy
    end
    remove_column :transition_actions, :project_variable_id
  end

  def self.down
    add_column :transition_actions, :project_variable_id, :integer
    M170TranstionAction.reset_column_information
    M170TranstionAction.all(:conditions => ["variable_binding_id IS NOT NULL"]).each do |action|
      action.project_variable_id = M170VariableBinding.find(action.variable_binding_id).project_variable_id
      action.save!
    end
    remove_column :transition_actions, :variable_binding_id
  end
end

class M170TranstionAction < ActiveRecord::Base
  extend M170Utils
  set_table_name tbl("transition_actions")
  self.inheritance_column = 'disable_single_table_inheritance'
end

class M170VariableBinding < ActiveRecord::Base
  extend M170Utils
  
  set_table_name tbl("variable_bindings")
end
