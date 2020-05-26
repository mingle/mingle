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

class TrialFeedbackController < ApplicationController
  allow :get_access_for => [:new]

  def new
    add_monitoring_event(:trial_feedback_shown)
    render_in_lightbox 'new'
  end

  def create
    User.current.mark_trial_feedback_shown

    add_monitoring_event(:trial_feedback_given)
    if params[:reason]
      event_details = {:reason => params[:reason]}
      event_details.merge!({:team_size => params[:team_size]}) if params[:team_size]
      event_details.merge!({:serious_buyer => true}) if params[:team_size] == "less_than_20" || params[:team_size] == "more_than_20"
      ProfileServer.update_organization(:trial_intention => event_details) if ProfileServer.configured?

      add_monitoring_event(:feedback_reason, event_details)
    end
    tenant_name = Multitenancy.active_tenant ? Multitenancy.active_tenant.name : 'Unknown tenant'

    subject = "Mingle SaaS trial feedback from #{User.current.name}(#{User.current.email})"
    message = []
    message << "I chose Mingle because: #{params[:reason]}"
    message << "My team size is #{params[:team_size]}" if params[:team_size]
    message << "#{params[:message]} "

    FeedbackMailer.send(:deliver_feedback, :message => message, :site_name => tenant_name, :subject => subject, :referer => request.env["HTTP_REFERER"] ) unless params[:message].blank?

    head :ok
  end

end
