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

class UserEventPublisher < ActiveRecord::Observer
  QUEUE = 'mingle.user_events'
  observe User

  include Messaging::Base

  def after_update(user)
    changed_columns = user.attributes.inject({}) do |acc, (key, value)|
      if ![@original_attributes[key], value].all?(&:nil?) && @original_attributes[key] != value
        acc[key] = {'old' => @original_attributes[key], 'new' => value}
      end
      acc
    end
    
    changed_columns.delete("icon")
    changed_columns.delete("updated_at")
    changed_columns.delete("created_at")

    if changed_columns.size > 0
      send_message(QUEUE, [user.message.merge(:changed_columns => changed_columns)])
    end
  end

  def after_find(user)
    @original_attributes = user.attributes
  end
  
end

UserEventPublisher.instance
