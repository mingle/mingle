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

class SmtpController < ApplicationController
  
  allow :get_access_for => [:index, :edit, :test], :redirect_to => { :action => :index }
  
  
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN=>["edit", "update", "test"]

  def index
    redirect_to :action => 'edit'
  end

  def edit
    @title = 'Email configuration'
    configuration = SmtpConfiguration.new(config_file_name)
    @smtp_settings, @sender = configuration.smtp_settings, configuration.sender
  end
  
  def update
    SmtpConfiguration.create(params, config_file_name, true)
    flash[:notice] = "Successfully saved mail settings."
    redirect_to :action => 'edit'
  end

  def test
    errors = SmtpConfiguration.test(params)
    if errors.empty?
      html_flash.now[:notice] = "<ul><li>Successfully delivered mail.</li><li>Check your email to confirm that the mail was received. (This may take a minute or two to arrive).</li><li><b>Note</b>: You must save these settings to make them permanent.</li></ul>"
    else
      show_errors(errors)
    end
    render(:update) do |page|
      page.refresh_flash
    end
  end  
  
  private
  def config_file_name
    SMTP_CONFIG_YML
  end    

end
