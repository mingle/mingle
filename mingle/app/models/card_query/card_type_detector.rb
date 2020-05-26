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

class CardQuery  
  class CardTypeDetector < Visitor
    
    def initialize(acceptor)
      @included, @excluded = [], []
      acceptor.accept(self)
    end
    
    def execute
      { :included => @included, :excluded => @excluded }
    end
    
    def uses?(card_type_name)
      (@included + @excluded).ignore_case_include?(card_type_name)
    end
    
    def visit_comparison_with_value(column, operator, value)
      return unless column.property_definition.kind_of?(CardTypeDefinition)
      case operator
        when Operator.equals     then add_to_included_without_dup(value)
        when Operator.not_equals then add_to_excluded_without_dup(value)
      end
    end
    
    def visit_explicit_in_condition(column, values, options = {})
      return unless column.property_definition.kind_of?(CardTypeDefinition)
      values.each { |value| add_to_included_without_dup(value) }
    end
    
    def visit_and_condition(*conditions)
      conditions.each { |condition| translate(condition) }
    end
    alias :visit_or_condition :visit_and_condition
    
    def visit_not_condition(negated_condition)
      @included, @excluded = @excluded, @included
      negated_condition.flatten_condition.each do |condition|
        translate(condition)
      end
      @excluded, @included = @included, @excluded
    end
    
    private
    
    def translate(acceptor)
      acceptor.accept(self)
    end
    
    def add_to_included_without_dup(value)
      @included << value unless @included.include?(value)
    end
    
    def add_to_excluded_without_dup(value)
      @excluded << value unless @excluded.include?(value)
    end
    
  end
end
