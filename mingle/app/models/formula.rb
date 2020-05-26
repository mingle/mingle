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
  attr_reader :formula

  def initialize(formula, parentheses=['(', ')'])
    @formula = formula
    @parentheses = parentheses
  end

  def +(another)
    self.value + another.value
  end

  def -(another)
    self.value - another.value
  end

  def -@
    -self.value
  end

  def *(another)
    self.value * another.value
  end

  def /(another)
    self.value / another.value
  end

  def to_f
    self.value.to_f
  end

  def value(card = nil)
    bind_to(card) if card
    @formula.value
  end

  def bind_to(card)
    @formula.bind_to(card)
  end

  def to_s
    "#{@parentheses.first}#{@formula}#{@parentheses.last}"
  end

  def to_sql(table_name = Card.table_name, cast_as_integer = false, property_overrides = {})
    output_type.to_expression_sql(@formula.to_sql(table_name, cast_as_integer, property_overrides), cast_as_integer, property_overrides)
  end

  def undefined?
    @formula.undefined?
  end

  def describe_type
    output_type.describe
  end

  def describe_self_with_type
    "#{describe_type} (#{to_s.bold})"
  end

  def output_type
    @formula.output_type
  end
  memoize :output_type

  def select_card_values(column_name)
    output_type.select_card_values(column_name)
  end

  def to_output_format(value)
    output_type.to_output_format(value)
  end

  def valid?
    Formula::ValidFormulaVisitor.new(self).valid?
  end

  def errors
    Formula::ValidFormulaVisitor.new(self).errors
  end

  def rename_property(old_name, new_name)
    @formula.rename_property(old_name, new_name)
  end

  def used_property_definitions
    Formula::PropertyDefinitionDetector.new(self).directly_related_property_definitions
  end

  def invalid_properties
    @formula.invalid_properties
  end

  def describe_invalid_operations
    @formula.describe_invalid_operations
  end

  def can_be_added_to_date?
    false
  end

  def accept(operation)
    operation.visit_formula(self)
    @formula.accept(operation)
  end
end

class Formula::UnsupportedOperationException < StandardError; end

require 'formula/primitive'
require 'formula/date_primitive'
require 'formula/numeric_primitive'
require 'formula/null'
require 'formula/card_property_value'

require 'formula/number'
require 'formula/date'
require 'formula/null_type'

require 'formula/operator'
require 'formula/addition'
require 'formula/negation'
require 'formula/subtraction'
require 'formula/multiplication'
require 'formula/division'
