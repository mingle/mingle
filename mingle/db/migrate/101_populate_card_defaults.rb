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

class M100CardDefaults < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_defaults"
  belongs_to :project, :class_name => 'M100Project', :foreign_key => 'project_id'
  belongs_to :card_type, :class_name => 'M100CardType', :foreign_key => 'card_type_id'
end

class M100CardType < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types"
  belongs_to :project, :class_name => 'M100Project', :foreign_key => 'project_id'
  has_one :card_defaults, :class_name => 'M100CardDefaults', :foreign_key => 'card_type_id'
end

class M100Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M100PropertyDefinition', :foreign_key => 'project_id'
  has_many :card_types, :class_name => 'M100CardType', :foreign_key => 'project_id'
  
  cattr_accessor :current
  def activate
    @@current = self
  end

  def deactivate
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

class PopulateCardDefaults < ActiveRecord::Migration
  def self.up
    M100Project.find(:all).each do |project|
      project.card_types.each do |card_type|
        unless card_type.card_defaults
          M100CardDefaults.create!(:card_type_id => card_type.id, :project_id => project.id)
        end
      end
    end
  end

  def self.down
  end
end
