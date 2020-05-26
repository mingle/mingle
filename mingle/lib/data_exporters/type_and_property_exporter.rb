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

class TypeAndPropertyExporter < BaseDataExporter

  def name
    'Types and Properties'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.card_types.each do |card_type|
      card_defaults = card_type.card_defaults
      card_type.property_definitions_with_hidden_in_smart_order.each do |property|
        index = add_row(card_defaults, card_type, index, property, sheet)
      end
    end
    Rails.logger.info("Exported project variables to sheet")
  end

  def exportable?
    Project.current.property_definitions_with_hidden.count > 0
  end

  private

  def headings
    ['Card Type', 'Property', 'Default value']
  end

  def add_row(card_defaults, card_type, index, property, sheet)
    begin
      sheet.insert_row(index, [card_type.name, property.name, property_value(property, card_defaults)])
      index.next
    rescue PropertyDefinition::InvalidValueException => e
      Rails.logger.error "Ignoring exception on property value export. PropertyDefinition::InvalidValueException: Project: #{Project.current.name}. Property: #{property.name}\n message: #{e.message}"
      index
    end
  end

  def property_value(property, card_defaults)
    return '(calculated)' if property.calculated?
    prop_value = card_defaults.property_value_for(property.name) || PropertyValue.create_from_db_identifier(property, nil)
    prop_value.display_value
  end

end
