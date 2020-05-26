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

class ReallyFixDuplicateRubyNames < ActiveRecord::Migration
  def self.up
    M20120821135500Project.find(:all).each do |project|
      card_schema = project.card_schema
      user_and_card_pds = project.all_property_definitions
      user_and_card_pds.each do |pd|
        next unless user_and_card_pds.count { |p| p.ruby_name == pd.ruby_name } > 1
        new_ruby_name = card_schema.send(:generate_unique_column_name, pd.ruby_name, nil)
        pd.update_attributes(:ruby_name => new_ruby_name)
      end
    end

    add_index :property_definitions, [:project_id, :ruby_name], :unique => true, :name => my_idx_name
  end

  def self.down
    if self.index_exists? my_idx_name
      remove_index :property_definitions, :name => my_idx_name
    end
  end
  
  def self.my_idx_name
    "#{ActiveRecord::Base.table_name_prefix}M20120821135500_idx"
  end
  
  def self.index_exists?(index_name)
    ActiveRecord::Base.connection.indexes("#{ActiveRecord::Base.table_name_prefix}property_definitions").any? {|p| p.name == index_name}
  end
end

class M20120821135500Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}deliverables"
  self.inheritance_column = '9328jkjoji_type' # disable single table inheretance
  has_many :all_property_definitions, :class_name => 'M20120821135500PropertyDefinition', :foreign_key => 'project_id'
  has_many :property_definitions_with_hidden_for_migration, :class_name => 'M20120821135500PropertyDefinition', :foreign_key => 'project_id'
  
  def card_schema
    CardSchema.new(self)
  end
  
end

class M20120821135500PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'zzzzz_type' # disable single table inheretance
  belongs_to :project, :class_name => "M20120821135500Project", :foreign_key => "project_id"
end
