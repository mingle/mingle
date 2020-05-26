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

class InviteToTeamMailer < ActionMailer::Base
  include UrlWriterWithFullPath, MailerHelper

  def invitation_for_existing_user(params)
    setup_generic_invitation(params)
    subject "#{params[:inviter].name} has invited you to join the Mingle project: #{params[:project].name}"
    body(params.merge(:invitation_link => project_show_url(params[:project].identifier)))
  end

  def invitation_for_new_user(params)
    setup_generic_invitation(params)
    subject "#{params[:inviter].name} has invited you to join Mingle"
    ticket = params[:invitee].login_access.generate_lost_password_ticket!(:expires_in => 7.days)
    body(params.merge(:invitation_link => set_password_url(:ticket => ticket)))
  end

  def ask_for_upgrade(params)
    recipients MingleConfiguration.ask_for_upgrade_email_recipient
    setup_generic_email
    subject "Alert: Mingle SaaS - More users are wanted for #{MingleConfiguration.site_url}"
    body(params)
  end

  private

  def setup_generic_invitation(params)
    setup_generic_email
    recipients params[:invitee].email
  end

  def setup_generic_email
    from default_sender
    content_type "text/html"
  end

end
