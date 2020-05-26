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

class AddNumberSequenceToDependencyTable < ActiveRecord::Migration
  def self.up
    add_column :dependencies, :number, :integer
    if supports_sequences? && ActiveRecord::Base.table_name_prefix.blank?
      unless sequence_exists?(:dependency_numbers)
        create_sequence(:dependency_numbers, 1, :strict_counter => true)
      end
    end
  end

  def self.down
    remove_column :dependencies, :number
    if supports_sequences? && ActiveRecord::Base.table_name_prefix.blank?
      drop_sequence :dependency_numbers
    end
  end
end
