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

class ProgramsController < PlannerApplicationController
  layout 'planner/application'

  skip_filter :load_program, :only => [:index, :create]

  allow :get_access_for => [:index, :confirm_delete], :post_access_for => [:create], :delete_access_for => [:destroy], :put_access_for => [:update]

  privileges UserAccess::PrivilegeLevel::REGISTERED_USER => ["index"],
             UserAccess::PrivilegeLevel::MINGLE_ADMIN => ["create", "confirm_delete"],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index]

  def index
    @programs = Program.accessible_for(User.current).sort_by{ |program| program.created_at }.reverse
    no_cache
    render :layout => "planner/application"
  end

  def create
    name = Program.unique(:name, 'New Program')
    identifier = Program.unique(:identifier, 'new_program')
    program = Program.create!(:identifier => identifier, :name => name)
    render :json => { :content => render_to_string(:partial => 'program', :locals => {:program => program, :initialize_menu => true }), :program_id => program.id }.to_json
  end

  def confirm_delete
    render :layout => "planner/application"
  end

  def destroy
    @program.destroy
    flash[:notice] = "Program #{@program.name.bold} was successfully deleted."
    redirect_to programs_path
  end

  def update
    flash.delete :error
    @program.rename_along_with_identifier(params[:program][:name])
    render(:update) do |page|
      if @program.save
        page.replace_html "program_details_#{@program.id}", :partial => 'program', :locals => { :program => @program, :initialize_menu => true }
      else
        flash.now[:error] = @program.errors.full_messages
        page << "$j('#rename_program_#{params[:id]}_form').addClass('fieldWithErrors');"
      end
      page.refresh_flash
    end
  end

  private

  def no_cache
    #HTTP 1.1
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    #HTTP 1.0
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end
end
