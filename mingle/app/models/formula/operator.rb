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
  class Operator < Formula
    def bind_to(card)
      operands.each { |operand| operand.bind_to(card) }
    end

    def rename_property(old_name, new_name)
      operands.each { |operand| operand.rename_property(old_name, new_name) }
    end

    def invalid_properties
      operands.collect(&:invalid_properties).flatten
    end

    def describe_invalid_operations
      return [] unless undefined?
      return [reason_operation_is_invalid] unless operands.any?(&:undefined?)
      operands.select(&:undefined?).collect(&:describe_invalid_operations).flatten
    end

    def invalid_operation_message
      ["The expression #{to_s.bold} is invalid because #{reason_operation_is_invalid}.", supported_operations_message].reject(&:blank?).join(" ")
    end

    def undefined?
      operands.any?(&:undefined?) || operand_output_types.all?(&:date?)
    end

    def operand_output_types
      operands.map(&:output_type)
    end
    memoize :operand_output_types

    private
    def supported_operations_message
      return "" unless operands.size > 1
      supported_ops = operands.first.output_type.describe_operations(operands.last.output_type)
      "The supported #{'operation'.plural(supported_ops.size)} #{'is'.plural(supported_ops.size)} #{supported_ops.join(", ")}."
    end
  end
end
