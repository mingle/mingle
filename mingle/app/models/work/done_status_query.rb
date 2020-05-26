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

class DoneStatusQuery
  
  attr_accessor :done_value_select, :join_sql, :where_condition
  
  def self.for(program_project)
    if program_project.completed_status_property_value.nil?
      UnknownDoneStatusQuery.new
    else
      DoneStatusQuery.new(program_project)
    end
  end

  private
  
  def initialize(program_project)
    @program_project = program_project
    @program_project.project.with_active_project do
      @where_condition = as_card_query.to_conditions
      @done_value_select = card_completed_status_sql
      @join_sql = get_join_sql
    end
  end

  def card_completed_status
    @program_project.completed_status_property_value
  end
  
  def card_completed_status_sql
    SqlHelper.sanitize_sql(SqlHelper.as_boolean(SqlHelper.case_when(where_condition, '?', '?')), true, false)
  end

  def get_join_sql
    as_card_query.joins_clause_sql
  end
  
  def as_card_query
    CardQuery.parse(@program_project.done_status_definition.as_mql)
  end

end

class UnknownDoneStatusQuery

  ERROR_MESSAGE = "Done status unknown"
  
  def done_value_select
    "NULL"
  end
  
  def join_sql
    ""
  end
  
  def where_condition
    raise ERROR_MESSAGE
  end
  
end
