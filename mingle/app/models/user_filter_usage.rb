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

class UserFilterUsage < ActiveRecord::Base

  belongs_to :user
  belongs_to :filterable, :polymorphic => true

  def self.user_ids
    ThreadLocalCache.get("UserFilterUsage.user_ids") do
      connection.select_values("SELECT DISTINCT user_id FROM #{quoted_table_name}").compact.map(&:to_i)
    end
  end

  def self.card_list_views(project, user_id)
    project.card_list_views.find(:all, :joins => :user_filter_usages,
                                 :conditions => ["#{quoted_table_name}.user_id = ?", user_id])
  end
end
