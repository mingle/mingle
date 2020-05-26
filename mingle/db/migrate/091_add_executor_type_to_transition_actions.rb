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

require File.expand_path(File.dirname(__FILE__) + '/../../app/models/transition.rb')

class AddExecutorTypeToTransitionActions < ActiveRecord::Migration
  def self.up
    rename_column :transition_actions, :transition_id, :executor_id
    add_column :transition_actions, :executor_type, :string
    execute "UPDATE #{safe_table_name('transition_actions')} SET executor_type='Transition'"
    create_not_null_constraint :transition_actions, :executor_type
    TransitionAction.reset_column_information
  end

  def self.down
    rename_column :transition_actions, :executor_id, :transition_id
    remove_column :transition_actions, :executor_type
  end
end
