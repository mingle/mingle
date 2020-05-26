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

class TransitionExecutionsController < ProjectApplicationController

  allow :get_access_for => :none

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["create"]  
  
  def create
    params[:transition_execution].merge!(:id => params[:id]) if params[:transition_execution]
    execution = TransitionExecution.new(@project, params[:transition_execution])
    execution.process
    
    if execution.errors.empty?
      headers["Location"] = url_for(:action => :show, :status => execution.status)
      render_model_xml execution
    else
      render :xml => execution.errors.to_xml, :status => 422
    end
  end
  
  def show
    render_model_xml TransitionExecution.new(params[:status])
  end
end
