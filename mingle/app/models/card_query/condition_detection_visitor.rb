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
  class ConditionDetectionVisitor < Visitor
    def initialize(acceptor)
      @detected = false
      acceptor.accept(self)
    end

    def execute
      @detected
    end

    def visit_and_condition(*conditions)
      return true if @detected
      @detected = conditions.any? { |condition| translate(condition) }
    end
    alias_method :visit_or_condition, :visit_and_condition

    def visit_not_condition(negated_condition)
      return true if @detected
      @detected = translate(negated_condition)
    end

    private

    def translate(acceptor)
      acceptor.accept(self)
      execute
    end
  end
end
