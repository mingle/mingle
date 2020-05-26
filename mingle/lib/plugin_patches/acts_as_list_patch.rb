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
  module Acts #:nodoc:
    module List #:nodoc:
      module ClassMethods
        def acts_as_list(options = {})
          configuration = { :column => "position", :scope => "1 = 1" }
          configuration.update(options) if options.is_a?(Hash)

          configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].is_a?(Symbol) && configuration[:scope].to_s !~ /_id$/

          if configuration[:scope].is_a?(Symbol)
            scope_condition_method = %(
              def scope_condition
                if #{configuration[:scope].to_s}.nil?
                  "#{configuration[:scope].to_s} IS NULL"
                else
                  "#{configuration[:scope].to_s} = \#{#{configuration[:scope].to_s}}"
                end
              end
            )
          else
            scope_condition_method = "def scope_condition() \"#{configuration[:scope]}\" end"
          end

          class_eval <<-EOV
            include ActiveRecord::Acts::List::InstanceMethods

            def acts_as_list_class
              ::#{self.name}
            end

            def position_column
              '#{configuration[:column]}'
            end

            #{scope_condition_method}

            before_destroy :eliminate_current_position unless options[:ignore_destroy_callback] # patched here, before is remove_from_list which trigger unexpected callbacks
            before_create  :add_to_list_bottom
          EOV
        end
      end
      
      module InstanceMethods          
        def eliminate_current_position          
          decrement_positions_on_lower_items if in_list?
        end
        
        private :eliminate_current_position
      end
    end
  end
end
