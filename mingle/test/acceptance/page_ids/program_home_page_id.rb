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

module ProgramHomePageId
  
  PROGRAM_NAME_ID = "program_name"
  
  def program_name_link_id(program_name)
    "program_#{program_name.gsub(" ", "_")}1_link_text"
  end
  
  def program_backlog_link_id_for(program_name)
    "#{program_name.gsub(" ", "_")}1_backlog_link"
  end
  
  def create_new_program_link_id(program_name)
    "link=#{program_name}"
  end
end
