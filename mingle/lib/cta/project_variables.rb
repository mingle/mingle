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

module CTA
  class ProjectVariables < Ast::Transform

    class << self
      include Ast

      def plv_value(name)
        plv = project.project_variables.detect do |plv|
          plv.name.ignore_case_equal?(name)
        end
        if value = plv.value
          case plv.data_type
          when ProjectVariable::CARD_DATA_TYPE
            project.cards.find_by_id(value)
          when ProjectVariable::DATE_DATA_TYPE
            Date.parse_with_hint(value, project.date_format)
          when ProjectVariable::USER_DATA_TYPE
            project.users.find_by_id(value)
          else
            # numeric, string
            value
          end
        end
      end

      def apply(ast)
        self.new.apply(ast)
      end
    end

    match(:project_variable) { |node| plv_value(node) }
  end
end
