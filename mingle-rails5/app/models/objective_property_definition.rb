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

class ObjectivePropertyDefinition < ApplicationRecord
  self.table_name = :obj_prop_defs
  belongs_to :program, required: true
  has_many :objective_property_mappings, foreign_key: :obj_prop_def_id, :dependent => :destroy
  has_many :objective_property_values, foreign_key: :obj_prop_def_id, dependent: :destroy

  validates_uniqueness_of :name, :scope => :program_id, :case_sensitive => false, message: 'already used for an existing property in your Program.', length: {maximum: 40}
  scope :default, -> {where(name: %w(Size Value))}

  class << self
    def create_default_properties(program_id)
      property_defs = {}
      property_defs[:size] = ManagedNumber.create!(name: 'Size', program_id: program_id)
      property_defs[:size].create_default_property_values
      property_defs[:value] = ManagedNumber.create!(name: 'Value', program_id: program_id)
      property_defs[:value].create_default_property_values
      property_defs
    end
  end


  def managed?
    false
  end

  def numeric?
    false
  end

  def to_params
    attributes.symbolize_keys.except(:updated_at, :created_at).merge(managed: managed?, numeric: numeric?)
  end

  def create_default_property_values
    11.times do |value|
      value = value * 10
      self.objective_property_values.create(value:value)
    end
  end
end
