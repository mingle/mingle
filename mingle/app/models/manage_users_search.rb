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

class ManageUsersSearch
  def self.all_activated_users
    new({}, false)
  end

  attr_reader :query, :show_deactivated, :order_by, :direction
  
  delegate :blank?, :to => :query
  
  def initialize(params, show_deactived_users)
    params ||= {}
    @query, @order_by, @direction = params[:query], params[:order_by], params[:direction]
    @show_deactivated = show_deactived_users
  end
  
  def exclude_deactivated_users?
    !@show_deactivated
  end
  
  def result_message(users, list_name='users')
    if users.empty?
      "Your search for #{query.bold} did not match any #{list_name}."
    else
      "Search #{'result'.plural(users.size)} for #{query.bold}."
    end
  end
end
