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

class MembershipRequestMailer < ActionMailer::Base
  include MailerHelper, NotificationHelper
  helper NotificationHelper
  
  def request(requester, project)
    recipients project.admins.collect(&:email).compact
    from sender(project)
    subject "#{requester.name} wants to join your project #{project.name}"
    content_type "text/html"
    body :requester => requester, :project => project
  end
  
end
