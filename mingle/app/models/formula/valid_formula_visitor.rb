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
  class ValidFormulaVisitor < Visitor
    
    def initialize(acceptor)
      @valid = true
      @non_numeric_properties, @formula_properties, @aggregate_properties, @invalid_operation_messages = [], [], [], []
      acceptor.accept(self)
    end
    
    def valid?
      @valid
    end
    
    def errors
      errors = []
      errors << ("Property".plural(@formula_properties.size) << ' ' << @formula_properties.bold.to_sentence << ' ' << "is".plural(@formula_properties.size) << (@formula_properties.size > 1 ? "" : " a") << " formula " << "property".plural(@formula_properties.size) << " and cannot be used within another formula.") if @formula_properties.any?
      errors << ("Property".plural(@non_numeric_properties.size) << ' ' << @non_numeric_properties.bold.to_sentence << ' ' << "is".plural(@non_numeric_properties.size) << " not numeric.") if @non_numeric_properties.any?
      errors << ("Property".plural(@aggregate_properties.size) << ' ' << @aggregate_properties.bold.to_sentence << ' ' << "is".plural(@aggregate_properties.size) << (@aggregate_properties.size > 1 ? "" : " an") << " aggregate " << "property".plural(@aggregate_properties.size) << " and cannot be used in a formula.") if @aggregate_properties.any?
      
      errors = @invalid_operation_messages if errors.empty?
      errors
    end
    
    def visit_addition_operator(operation, lhs, rhs)
      with_helpful_error_messages_check_null_or_incompatible_output_types(operation, lhs, rhs) do |output_types| 
        output_types.all?(&:date?)
      end
    end
    
    def visit_subtraction_operator(operation, lhs, rhs)
      with_helpful_error_messages_check_null_or_incompatible_output_types(operation, lhs, rhs) do |lhs_output, rhs_output| 
        lhs_output.numeric? && rhs_output.date?
      end
    end
    
    def visit_multiplication_operator(operation, lhs, rhs)
      with_helpful_error_messages_check_null_or_incompatible_output_types(operation, lhs, rhs) do |output_types|
        output_types.any?(&:date?)
      end
    end

    def visit_division_operator(operation, lhs, rhs)
      with_helpful_error_messages_check_null_or_incompatible_output_types(operation, lhs, rhs) do |output_types|
        output_types.any?(&:date?) 
      end
    end
    
    def visit_negation_operator(operation, operand)
      with_helpful_error_messages_check_null_or_incompatible_output_types(operation, operand) do |output_types|
        output_types.any?(&:date?) 
      end
    end
    
    def visit_card_property_value(property_definition)
      if property_definition.class.predefined?(property_definition.name)
        @valid &= false
        @invalid_operation_messages << "#{property_definition.name.bold} is predefined property and is not supported in formula properties."
      end
      
      unless (property_definition.numeric? && !property_definition.formulaic? || property_definition.date?)
        @valid &= false
        (property_definition.formulaic? ? @formula_properties : @non_numeric_properties) << property_definition.name
      end
    end
    
    private
    def with_helpful_error_messages_check_null_or_incompatible_output_types(operation, *operands, &incompatible_output_type_check)
      with_null_checks_for(*operands) do |output_types|
        with_helpful_error_messages_for_type_errors(operation) do
          yield output_types
        end
      end
    end
    
    def with_helpful_error_messages_for_type_errors(operation, &incompatible_output_type_check)
      !check_incompatible_output_types(operation.invalid_operation_message, &incompatible_output_type_check)
    end
    
    def check_incompatible_output_types(help_message, &incompatible_output_type_check)
      yield.tap do |is_incompatible|
        @invalid_operation_messages << help_message if is_incompatible
      end
    end
    
    def with_null_checks_for(*operands, &block)
      output_types = operands.map(&:output_type)
      @valid &= output_types.none?(&:null?) && yield(output_types)
    end
  end
end
