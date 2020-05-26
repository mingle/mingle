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

class Formula::Visitor
  
  def visit_formula(formula); end
  
  def visit_numeric_primitive(numeric_primitive); end

  def visit_date_primitive(date_primitive); end

  def visit_null_primitive(null_primitive = nil); end

  def visit_card_property_value(card_property_value); end

  def visit_addition_operator(operation, lhs, rhs); end

  def visit_subtraction_operator(operation, lhs, rhs); end

  def visit_multiplication_operator(operation, lhs, rhs); end

  def visit_division_operator(operation, lhs, rhs); end

  def visit_negation_operator(operation, operand); end
  
end
