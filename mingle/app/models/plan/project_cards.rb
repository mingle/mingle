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

class Plan
  class ProjectCards
    def initialize(project, cards)
      @project = project
      @cards = cards
    end

    def criteria_not_in(objective)
      @project.with_active_project do |project|
        card_id_criteria(build_card_query.restrict_with(not_in_objective_cond(objective)))
      end
    end

  private
    def not_in_objective_cond(objective)
      CardQuery::SqlCondition.new("#{Card.quoted_table_name}.#{Work.connection.quote_column_name("number")} NOT IN	
                                  (select #{column_in_work('card_number')} from #{Work.quoted_table_name} 
                                  WHERE #{column_in_work('objective_id')} = #{objective.id} 
                                  and #{column_in_work('project_id')} = #{@project.id})")
    end
    
    def column_in_work(name)
      "#{Work.quoted_table_name}.#{name}"
    end
    
    def build_card_query
      case @cards
      when CardQuery
        @cards
      else
        card_numbers = Array(@cards)
        CardQuery.parse("NUMBER IN (#{card_numbers.join(", ")})")
      end
    end

    def card_id_criteria(card_query)
      CardIdCriteria.new("IN (#{card_query.to_card_id_sql})")
    end
  end
end
