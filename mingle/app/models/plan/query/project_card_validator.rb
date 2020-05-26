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

class Plan
  module Query
    # Moved project card query validators out of project card query class
    module ProjectCardValidator
      class Error < StandardError
      end

      def before_transform_validator
        lambda do |t|
          t.match(:comparision) do |column, op, value|
            validate_ops(column, op)
            unless value.is_a?(Ast::Node)
              validate_comparison_value(column, value)
            end
          end
        end
      end

      def sql_ast_validator
        lambda do |t|
          t.match(:comparision, [t.any, t.any, :column]) do |column1, op, column2|
            validate_columns_data_type(column1, op, column2)
          end
        end
      end

      def validate_ops(column, op)
        if column.ast[:definition].is_a?(AssociationPropertyDefinition) && ['>', '<', '>=', '<='].include?(op)
          raise Error, "Property #{column.ast[:definition].name.bold} can only be compared by '=' and '!='."
        end
      end

      def validate_comparison_value(column, value)
        if column.ast[:definition].numeric? && !(value.blank? || value.numeric?)
          invalid_comparison_value(column.ast[:definition], value)
        end
        begin
          column.ast[:definition].comparison_value(value)
        rescue PropertyDefinition::InvalidValueException => e
          invalid_comparison_value(column.ast[:definition], value)
        rescue EnumeratedPropertyDefinition::ValueRestrictedException => e
          # I think it's better to keep the origin error
          # Doing this only want to make it clear, we're expecting comparison_value method to do validation for us
          raise e
        end
      end
      def invalid_comparison_value(property_definition, value)
        notice_msg = if @project.find_property_definition_or_nil(value)
          " Value #{value.to_s.bold} is a property, please use #{"PROPERTY #{value}".bold}."
        end
        property_type = property_definition.property_type
        example = property_type.is_a?(PropertyType::DateType) ? 'Example: 05 Oct 2011' : ''
        raise Error, "Property #{property_definition.name.bold} is #{property_type}, and value #{value.to_s.bold} is not #{property_type}. Only #{property_type} values can be compared with #{property_definition.name.bold}.#{notice_msg} #{example}"
      end

      def validate_columns_data_type(column1, op, column2)
        if data_type(column1) != data_type(column2)
          raise Error, "Cannot compare 2 different data type properties: #{column1.ast[:name].bold} #{op} #{column2.ast[:name].bold}."
        end
      end
    end
  end
end
