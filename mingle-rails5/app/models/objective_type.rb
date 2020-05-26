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

class ObjectiveType < ApplicationRecord
  belongs_to :program
  has_many :objective_property_mappings, :dependent => :destroy
  has_many :objective_property_definitions, through: :objective_property_mappings

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :program_id, message: 'Already used for an existing ObjectiveType in your Program'
  before_save :sanitize_value_statement

  scope :default, -> { where(:name => default_attributes[:name])}
  scope :with_properties, -> { includes(:objective_property_definitions) }

  def sanitize_value_statement
    self.value_statement = HtmlSanitizer.new.sanitize value_statement
  end

  class << self
    def default_attributes
      {name: 'Objective', value_statement: default_value_statement}
    end

    def default_value_statement
      '<h2>Context</h2>

<h3>Business Objective</h3>

<p>Whose life are we changing?</p>

<p>What problem are we solving?</p>

<p>Why do we care about solving this?</p>

<p>What is the successful outcome?</p>

<h3>Behaviours to Target</h3>

<p>(Example: Customer signup for newsletter, submitting support tickets, etc)</p>
'
    end
  end

  def to_params(include_property_definitions = true)
    attrs = self.attributes.symbolize_keys.slice(:id, :name, :value_statement)
    attrs = attrs.merge(property_definitions: property_definitions) if include_property_definitions
    attrs
  end

  private
  def property_definitions
    self.objective_property_definitions.reduce({}) do | obj_prop_defs, obj_prop_def|
      obj_prop_defs[obj_prop_def.name.to_sym] = {
          name: obj_prop_def.name,
          value:NullPropertyValueMapping.new.value,
          allowed_values:obj_prop_def.allowed_values
      }
      obj_prop_defs
    end
  end
end
