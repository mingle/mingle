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

# this patch fixes ORA-01795: maximum number of expressions in a list is 1000
module ActiveRecord
  # See ActiveRecord::AssociationPreload::ClassMethods for documentation.
  module AssociationPreload #:nodoc:
    module ClassMethods
      def find_associated_records(ids, reflection, preload_options)
        options = reflection.options
        table_name = reflection.klass.quoted_table_name

        if interface = reflection.options[:as]
          parent_type = if reflection.active_record.abstract_class?
            self.base_class.sti_name
          else
            reflection.active_record.sti_name
          end

          conditions = "#{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_id"} #{in_or_equals_for_ids(ids)} and #{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_type"} = '#{parent_type}'"
        else
          foreign_key = reflection.primary_key_name
          conditions = "#{reflection.klass.quoted_table_name}.#{foreign_key} #{in_or_equals_for_ids(ids)}"
        end

        conditions << append_conditions(reflection, preload_options)

        reflection.klass.with_exclusive_scope do
          result = [] #patched line
          Array(ids).each_slice(1000) do |slice| #patched line
            result.concat(reflection.klass.find(:all, #patched line
                                  :select => (preload_options[:select] || options[:select] || "#{table_name}.*"),
                                  :include => preload_options[:include] || options[:include],
                                  :conditions => [conditions, slice], # patched line
                                  :joins => options[:joins],
                                  :group => preload_options[:group] || options[:group],
                                  :order => preload_options[:order] || options[:order]))
          end #patched line
          result #patched line
        end
      end
    end
  end
end
