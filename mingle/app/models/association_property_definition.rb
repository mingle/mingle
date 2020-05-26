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

class AssociationPropertyDefinition < PropertyDefinition
  
  subclass_responsibility :reference_class, :values
  
  def generate_column_name
    return if name.blank? # rely upon validates_presence_of :name
    unique_column_name = project.card_schema.unique_column_name_from_name(name, 'cp', reference_class.name.foreign_key).downcase
    self.column_name = connection.column_name(unique_column_name)
    raise "Invalid column name #{column_name}" unless unique_column_name =~ Regexp.new("(.+)_#{reference_class.name.foreign_key}$")
    self.ruby_name = $1
  end

  def column_type
    :integer
  end
  
  def include_association
    association_name
  end

  def update_card_by_obj(card, obj)
    card.send(:write_attribute, column_name, obj.nil? ? nil : obj.id)
  end
  
  def support_inline_creating?
    false
  end
  
  def finite_valued?
    true
  end
  
  def lockable?
    false
  end  
  
  def colorable?
    false
  end  
  
  def property_values
    property_values_from_db(all_db_identifiers)
  end
  memoize :property_values
  
  private
  
  def top_level_reference_class_name
    "::#{reference_class.name}"
  end
  
  def association_name
    ruby_name.to_sym
  end  
end
