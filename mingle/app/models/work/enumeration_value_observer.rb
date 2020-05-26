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

class EnumerationValueObserver < ActiveRecord::Observer
  observe EnumerationValue
  
  on_callback(:after_destroy) do |enumerated_value|
    ProgramProject.find_all_by_done_status_id(enumerated_value.id).each do |program_project|
      program_project.update_attributes(:status_property => nil, :done_status => nil)
    end
  end
  
  EnumerationValueObserver.instance  
end
