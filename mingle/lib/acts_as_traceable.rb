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
  module Acts
    module Traceable
      CALLBACKS = [:trace]

      DEFAULT_USER = lambda { Thread.current_user } 

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_traceable &block

          the_user = block_given? ? block : ActiveRecord::Acts::Traceable::DEFAULT_USER
          
          cattr_accessor :trace_columns
          
          class_eval do
            belongs_to :created_by, :class_name => '::User', :foreign_key => 'created_by_user_id' 
            belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id' 
            
            self.trace_columns = [:created_by_user_id, :modified_by_user_id]
            
            define_method(:trace) do
              if new_record?
                send(:created_by=, the_user.call)
              end
              send(:modified_by=, the_user.call)
            end  

            before_save :trace
          end
        end
      end  
    end
  end      
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Traceable
