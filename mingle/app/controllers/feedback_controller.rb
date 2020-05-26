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

class FeedbackController < ApplicationController

  def new
    add_monitoring_event(:speak_with_us_opened)
    render_in_lightbox 'shared/speak_with_us'
  end

  def create
    return head(:unprocessable_entity) if params[:"user-email"].blank? || params[:message].blank?
    user_email = params[:"user-email"].strip
    message = params[:message].strip

    return head(:unprocessable_entity) unless EMAIL_FORMAT_REGEX =~ user_email

    add_monitoring_event(:speak_with_us_sent)
    tenant_name = Multitenancy.active_tenant ? Multitenancy.active_tenant.name : 'Unknown tenant'
    subject = "Speak with us feedback from #{User.current.name} (#{user_email})."
    FeedbackMailer.send(:deliver_feedback, :message => message, :site_name => tenant_name, :referer => request.env["HTTP_REFERER"], :subject => subject, :cc => "support@thoughtworks.com")
    head :ok
  end

end
