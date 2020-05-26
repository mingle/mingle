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

class UserFilterUsageObserver < ActiveRecord::Observer
  
  observe CardListView, HistorySubscription
  
  on_callback(:after_save) do |filterable|
    previous_users = filterable.user_filter_usages.collect(&:user)
    current_users = users_used_in_filter_properties(filterable)
    new_users = current_users - previous_users
    removed_users = previous_users - current_users
    new_users.each { |user| filterable.user_filter_usages.create!(:user => user) }
    removed_users.each do |user|
      if u = filterable.user_filter_usages.find_by_user_id(user.id)
        u.destroy
      end
    end
  end
    
  def users_used_in_filter_properties(filterable)
    users = []
    filterable.filters.each do |filter|
      next unless filter.property_definition.instance_of?(UserPropertyDefinition) && filter.value.present?
      user = filter.value.numeric? ? User.find_by_id(filter.value) : User.find_by_login(filter.value)
      users << user
    end
    users << filterable.filter_user if filterable.respond_to?(:filter_user)
    users.compact.uniq
  end  
  
  UserFilterUsageObserver.instance
end
