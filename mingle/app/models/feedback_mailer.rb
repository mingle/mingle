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

class FeedbackMailer < ActionMailer::Base

  def feedback(params)
    content_type "text/html"
    recipients MingleConfiguration.mingle_feedback_email
    from default_sender[:address]
    if MingleConfiguration.mingle_feedback_email_overridden && MingleConfiguration.installer?
      cc []
    else
      cc params[:cc]
    end
    reply_to MingleConfiguration.mingle_feedback_email
    subject params[:subject] || "Mingle SaaS feedback from #{User.current.name}(#{User.current.email})"
    body(params.merge(:user => User.current))
  end
end
