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

module MailerHelper
  def sender(project)
    return project.email_sender if FEATURES.active?("smtp_configuration") && !project.email_sender_name.blank? && !project.email_address.blank?
    default_sender
  end

  def murmur_sender(name)
    MingleConfiguration.saas? ? sender_email(MingleConfiguration.murmur_notification_email_address, name) : default_sender(name)
  end

  def default_sender(name=nil)
    sender_email(ActionMailer::Base.default_sender[:address], name)
  end

  def sender_email(email, name=nil)
    name = name || ActionMailer::Base.default_sender[:name]
    "#{name.inspect}<#{email}>"
  end
end
