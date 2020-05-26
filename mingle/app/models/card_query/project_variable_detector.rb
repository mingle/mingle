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
  class ProjectVariableDetector < Visitor
    attr_writer :usages
    
    def initialize(acceptor)
      acceptor.accept(self)
    end
    
    def execute
      usages.uniq
    end

    def visit_comparison_with_plv(column, operator, card_query_plv)
      usages << card_query_plv.plv
    end
    
    def visit_and_condition(*conditions)      
      self.usages += conditions.collect { |condition| translate(condition) }.flatten
    end
    
    def visit_or_condition(*conditions)
      self.usages += conditions.collect { |condition| translate(condition) }.flatten
    end
    
    def visit_not_condition(negated_condition)
      self.usages += translate(negated_condition)
    end
    
    def usages
      @usages ||= []
    end
    
    private
    
    def translate(acceptor)
      self.class.new(acceptor).execute
    end  
    
  end
end
