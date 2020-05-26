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

class Formula
  class CardPropertyValue < Formula
    include SqlHelper

    attr_reader :invalid_properties

    def initialize(property_name, null_is_zero=false)
      @property_name = property_name
      @null_is_zero = null_is_zero
      @invalid_properties = []
    end

    def value
      raise 'Cannot evaluate a CardPropertyValue formula without binding it to a card first' unless @value
      @value
    end

    def bind_to(card)
      property_definition = card.project.find_property_definition(@property_name, :with_hidden => true)
      card_value = property_definition.value(card)
      unless card_value
        @value = evaluate_null_as_zero? ? Formula::Primitive.create(0) : Formula::Null.new
        return
      end
      @value = if property_definition.numeric?
                 Formula::Primitive.create(card_value.to_num)
               else
                 Formula::Primitive.create(card_value)
               end
    end

    def to_f
      value.to_f if @value
    end

    def to_s
      if @property_name =~ /'.*"|".*'/
        property_name = @property_name.gsub(/'/, "''").gsub(/"/, '""')
      else
        property_name = @property_name
      end

      if property_name.gsub(/''/, "") =~ /'/
        "\"#{property_name}\""
      elsif property_name =~ /\s/ || has_special_characters(property_name) || has_a_math_operator(property_name) || just_numbers(property_name)
        "'#{property_name}'"
      elsif property_name =~ /\(|\)/
        "'#{property_name}'"
      elsif property_name.gsub(/""/, "") =~ /"/
        "'#{property_name}'"
      else
        property_name
      end
    end

    def to_sql(table_name = Card.table_name, cast_to_integer = false, property_overrides = {})
      unless property_overrides.keys.include?(property_definition)
        column_value_sql = sql_cast_column("#{quote_table_name(table_name)}.#{property_definition.quoted_column_name}", cast_to_integer)
        return evaluate_null_as_zero? ? "COALESCE(#{column_value_sql}, 0)" : column_value_sql
      end
      value = computed_value(property_overrides[property_definition])
      sql_cast_value(value, cast_to_integer)
    end

    def output_type
      property_definition.numeric? ? Formula::Number.new : Formula::Date.new
    end

    def undefined?
      false
    end

    def rename_property(old_name, new_name)
      if @property_name.downcase.strip == old_name.downcase
        @property_name = new_name
      end
    end

    def property_definition
      Project.current.find_property_definition(@property_name, :with_hidden => true)
    end

    def describe_invalid_operations
      []
    end

    def accept(operation)
      operation.visit_card_property_value(property_definition)
    end

    private

    def evaluate_null_as_zero?
      @null_is_zero && property_definition.numeric?
    end

    def sql_cast_value(value, cast_to_integer = false)
      if property_definition.numeric?
        cast_to_integer ? as_integer(value) : as_number(value)
      else
        connection.date_insert_sql(value)
      end
    end

    def sql_cast_column(column_name, cast_to_integer = false)
      if property_definition.numeric?
        cast_to_integer ? as_integer(column_name) : as_number(column_name)
      else
        column_name
      end
    end

    def computed_value(db_identifier)
      property_definition.property_value_from_db(db_identifier).computed_value
    end

    def has_a_math_operator(str)
      str =~ /[+\-*\/]+/
    end

    def just_numbers(str)
      str =~ /\A\d+\Z/
    end

    def has_special_characters(str)
      str =~ /[^a-z0-9_]/i
    end

  end
end
