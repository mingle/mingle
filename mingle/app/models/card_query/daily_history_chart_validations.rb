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
  class DailyHistoryChartValidations < Visitor
    attr_writer :validations
    
    def initialize(acceptor)
      acceptor.accept(self)
    end
    
    def execute
      validations.uniq
    end
        
    def visit_today_comparison(column, operator, today)
      self.validations << "#{'Today'.bold} is not supported in the daily history chart."
    end
    
    def visit_and_condition(*conditions)
      self.validations += conditions.collect { |condition| translate(condition) }.flatten
    end
    alias :visit_or_condition :visit_and_condition
    
    def visit_is_current_user_condition(column, current_user_login)
      self.validations << "#{'Current User'.bold} is not supported in the daily history chart."
    end
    
    def visit_not_condition(negated_condition)
      self.validations += translate(negated_condition)
    end

    def visit_this_card_property_comparison(column, operator, this_card_property)
      self.validations << "#{"THIS CARD.#{this_card_property.name}".bold} is not supported in the daily history chart chart-conditions or series conditions parameters."
    end
    
    def visit_tagged_with_condition(tag)
      self.validations << "#{'TAGGED WITH'.bold} is not supported in the daily history chart."
    end

    def visit_in_plan_condition(plan)
      self.validations << "#{'IN PLAN'.bold} is not supported in the daily history chart."
    end
    
    def visit_from_tree_condition(tree_condition, other_conditions)
      self.validations << "#{'FROM TREE'.bold} is not supported in the daily history chart."
    end

    def validations
      @validations ||= []
    end

    private

    def translate(acceptor)
      DailyHistoryChartValidations.new(acceptor).execute
    end 
        
  end
end
