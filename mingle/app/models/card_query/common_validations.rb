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
  module CommonValidations
    def visit_and_condition(*conditions)
      self.validations += conditions.map { |condition| translate(condition) }.flatten
    end
    alias :visit_or_condition :visit_and_condition

    def visit_explicit_in_condition(column, values, options = {})
      self.validations << self.class::THIS_CARD_USED if values.any? { |value| CardQuery::ThisCardProperty === value }
    end
    alias :visit_explicit_numbers_in_condition :visit_explicit_in_condition

    def visit_not_condition(negated_condition)
      self.validations += translate(negated_condition)
    end

    def visit_this_card_comparison(column, operator, value)
      self.validations << self.class::THIS_CARD_USED
    end

    def visit_this_card_property_comparison(column, operator, this_card_property)
      self.validations << self.class::THIS_CARD_USED
    end

    protected
    def translate(acceptor)
      self.class.new(acceptor).execute
    end

  end
end
