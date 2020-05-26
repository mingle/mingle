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

class PlannerApplicationController < ApplicationController
  layout "planner/in_program"

  skip_before_filter :authorize_user_access
  before_filter :load_program
  before_filter :authorize_user_access_for_program

  protected

  alias :authorize_user_access_for_program :authorize_user_access

  def load_program
    if !params[:program_id].blank?
      @program = Program.find_by_identifier(params[:program_id])
    elsif !params[:id].blank?
      @program = Program.find_by_identifier(params[:id])
    end

    raise InvalidResourceError, FORBIDDEN_MESSAGE unless @program
    @plan = @program.plan
  end

end
