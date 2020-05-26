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

Project
class Project
  def self.select_by_program_sql
    %{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
   LEFT JOIN #{ProgramProject.quoted_table_name}
          ON #{ProgramProject.quoted_table_name}.project_id = #{quoted_table_name}.id
       WHERE #{ProgramProject.quoted_table_name}.program_id = ?
    }
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), '../plan/program'))
Program
class Program
  class << self
    def select_by_program_sql
      "SELECT * FROM #{quoted_table_name} WHERE id = ?"
    end
  end
end

Plan
class Plan
  class << self
    def select_by_program_sql
      "SELECT * FROM #{quoted_table_name} WHERE program_id = ?"
    end
  end
end

Group
class Group
  class << self
    def select_by_program_sql
      select_by_project_sql
    end
  end
end

UserMembership
class UserMembership
  class << self
    def select_by_program_sql
      select_by_project_sql
    end
  end
end

MemberRole
class MemberRole
  class << self
    def select_by_program_sql
      <<-SQL
        SELECT #{self.all_columns_except.join(',')}
        FROM #{self.quoted_table_name}
        WHERE (deliverable_id = ?)
      SQL
    end

  end
end

User
class User
  def self.select_by_program_sql
    user_membership = UserMembership.quoted_table_name
    users = User.quoted_table_name
    %{
      SELECT #{self.all_columns_except('salt', 'password').join(',')}
      FROM #{self.quoted_table_name}
      WHERE id IN (
      SELECT user_id
        FROM #{user_membership}
        JOIN #{users} ON (#{users}.id = #{user_membership}.user_id)
        JOIN #{Group.quoted_table_name} g ON g.id = #{user_membership}.group_id
        WHERE g.deliverable_id = ?
      )
    }
  end
end

ProgramProject
class ProgramProject

  def self.select_by_program_sql
    "SELECT * FROM #{quoted_table_name} WHERE program_id = ?"
  end

end

Work
class Work

  def self.select_by_program_sql
    "SELECT #{quoted_table_name}.* FROM #{quoted_table_name}, #{Plan.quoted_table_name} p WHERE #{quoted_table_name}.plan_id = p.id AND p.program_id = ?"
  end

end

PropertyDefinition
class PropertyDefinition
  def self.select_by_program_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{ProgramProject.quoted_table_name} ON #{ProgramProject.quoted_table_name}.status_property_id = #{quoted_table_name}.id
      WHERE #{ProgramProject.quoted_table_name}.program_id = ?
    }
  end
end

EnumerationValue
class EnumerationValue
  def self.select_by_program_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{PropertyDefinition.quoted_table_name} ON #{PropertyDefinition.quoted_table_name}.id = #{quoted_table_name}.property_definition_id
      JOIN #{ProgramProject.quoted_table_name} ON #{ProgramProject.quoted_table_name}.done_status_id = #{quoted_table_name}.id
      WHERE #{ProgramProject.quoted_table_name}.program_id = ?
    }
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), '../plan/objective'))
Objective
class Objective
  def self.select_by_program_sql
    %{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       WHERE #{quoted_table_name}.program_id = ?
    }
  end
end

ObjectiveFilter
class ObjectiveFilter

  def self.select_by_program_sql
    %{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}, #{Objective.quoted_table_name} obj
       WHERE obj.id = #{quoted_table_name}.objective_id
         AND obj.program_id = ?
    }
  end

end

require File.expand_path(File.join(File.dirname(__FILE__), '../plan/objective_type'))
ObjectiveType
class ObjectiveType
  def self.select_by_program_sql
    "SELECT * FROM #{quoted_table_name} WHERE program_id = ?"
  end
end

