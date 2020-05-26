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

module ActiveRecord
  module ConnectionAdapters 
    
    class TableDefinition
      def column_with_char_limit(name, type, options = {})
        if ActiveRecord::Base.connection.database_vendor == :oracle
          options = OracleSupport::CharLimit.char_ify_limit(type, options)
        end
        column_without_char_limit(name, type, options)
      end
      
      alias_method_chain :column, :char_limit
    end

  end
end
