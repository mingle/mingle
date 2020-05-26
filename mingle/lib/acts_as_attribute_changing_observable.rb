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
    module AttributeChangingObservable
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_attribute_changing_observable 
          include ActiveRecord::Acts::AttributeChangingObservable::InstanceMethods
          after_save :notify_attribute_changing_observers
        end
      end
      
      module InstanceMethods
        def after_attribute_change(attribute, &block)
          changing_observers_for(attribute) << Proc.new(&block)
        end

        protected
        
        def notify_attribute_changing_observers
          changes.each do |attribute, change|
            changing_observers_for(attribute).each do |observer| 
              observer.call(*change)
            end
          end
        end
        
        private
        
        def changing_observers_for(attribute)
          @changing_observers ||= {}
          @changing_observers[attribute.to_s] ||= []
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::AttributeChangingObservable)
