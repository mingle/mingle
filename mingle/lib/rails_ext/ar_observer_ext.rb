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

class ActiveRecord::Observer
  # this provid a compact way when code are same for multipule callbacks
  # usage:
  #   class Observer < ActiveRecord::Observer
  #     observe :xxx
  #     on_callback(:after_create, :after_destroy, :after_update) do |model|
  #        #something same with those three callbacks
  #     end
  #   end
  #
  def self.on_callback(*callbacks, &block)
    callbacks.each do |callback|
      self.send(:define_method, callback, &block)
    end    
  end
end
