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

# use const missing to preload project
Project
class Project
  def create_text_list_definition!(options)
    create_property_definition_of_type(EnumeratedPropertyDefinition, options)
  end

  def create_any_text_definition!(options)
    create_property_definition_of_type(TextPropertyDefinition, options)
  end

  def create_formula_property_definition!(options)
    create_property_definition_of_type(FormulaPropertyDefinition, options)
  end

  def create_date_property_definition!(options)
    create_property_definition_of_type(DatePropertyDefinition, options)
  end

  def create_user_definition!(options)
    create_property_definition_of_type(UserPropertyDefinition, options)
  end

  def create_card_property_definition!(options)
    create_property_definition_of_type(CardPropertyDefinition, options)
  end

  def create_aggregate_property_definition!(options)
    create_property_definition_of_type(AggregatePropertyDefinition, options.merge(:is_numeric => true))
  end

  def create_card_relationship_property_definition!(options)
    create_property_definition_of_type(CardRelationshipPropertyDefinition, options)
  end

  def create_property_definition_of_type(klass, options = {})
    klass.create!(options.merge(:project_id => self.id)).tap do |prop|
      self.all_property_definitions.reload
      [Card, Card::Version].each do |m|
        self.connection.add_column(m.table_name, prop.column_name, prop.column_type, :references => nil)
        m.reset_column_information
      end
    end
  end
end
