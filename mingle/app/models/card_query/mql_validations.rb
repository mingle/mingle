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

# MqlValidations packages validations only for MQL.
# The CardQuery created by filter or other domain should not apply these validations
#
class CardQuery
  class MqlValidationError < DomainException
  end

  def validate_mql!
    @conditions.validate_mql! if @conditions
  end

  module MqlValidations
    def self.included(base)
      Condition.send(:include, EmptyValidation)
      ComparisonWithValue.send(:include, PropertyDefinitionValidation)
      UserPropertyDefinition.send(:include, CurrentUserValidation)
      DatePropertyDefinition.send(:include, TodayValidation)
      ::CardQueryParser.send(:include, Validations)
    end

    module EmptyValidation
      def validate_mql!
      end
    end

    module PropertyDefinitionValidation
      def validate_mql!
        @column.property_definition.validate_card_query_condition!(@column, @operator, @value) if @column.property_definition.respond_to?(:validate_card_query_condition!)
      end
    end

    module CurrentUserValidation
      def validate_card_query_condition!(column, operator, view_identifier)
        if property_type.is_current_user?(view_identifier)
          correct_mql = "#{column} #{operator.operator_symbol} CURRENT USER"
          msg = "#{name.bold} is a #{property_type} property, and value #{view_identifier.to_s.bold} is not #{property_type}. To use CURRENT USER do not enclose in any quotes or parenthesis."
          raise CardQuery::MqlValidationError.new(msg, project)
        end
      end
    end

    module TodayValidation
      def validate_card_query_condition!(column, operator, view_identifier)
        if property_type.project_today_identifiers?(view_identifier)
          correct_mql = "#{column} #{operator.operator_symbol} TODAY"
          msg = "#{name.bold} is a #{property_type} property, and value #{view_identifier.to_s.bold} is not #{property_type}. To use TODAY do not enclose in any quotes or parenthesis."
          raise CardQuery::MqlValidationError.new(msg, project)
        end
      end
    end

    module Validations
      def self.included(base)
        base.alias_method_chain :parse, :validation unless base.instance_methods.include?('parse_without_validation')
      end

      def parse_with_validation(*args, &block)
        parse_without_validation(*args, &block).tap do |card_query|
          card_query.validate_mql! if card_query.respond_to?(:validate_mql!)
        end
      end
    end
  end
end
