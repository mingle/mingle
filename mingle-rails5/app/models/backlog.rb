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

class Backlog < ActiveRecord::Base
  belongs_to :program
  has_many :backlog_objectives,-> {order :position} , :dependent => :destroy

  def reorder_objectives(new_order)
    position = 1
    new_order.each do |number|
      backlog_objectives.find_by_number(number).update_attribute :position, position
      position += 1
    end
  end
end
