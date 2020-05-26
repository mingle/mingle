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

module ThreadSafeSupport
  module ActiveRecordExt

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def remove_reflection_table_name_cache(reflation)
        reflect = reflect_on_association(reflation)
        def reflect.table_name
          klass.table_name
        end
        def reflect.quoted_table_name
          klass.quoted_table_name
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ThreadSafeSupport::ActiveRecordExt)
