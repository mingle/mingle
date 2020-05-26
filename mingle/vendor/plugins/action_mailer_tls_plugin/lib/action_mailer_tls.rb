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

require "rubygems"
require "action_mailer"

ActionMailer::Base.class_eval do
  private
  def perform_delivery_smtp(mail)
    destinations = mail.destinations
    mail.ready_to_send

    Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain], 
        smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication],
        smtp_settings[:tls], smtp_settings[:ssl]) do |smtp|
      smtp.sendmail(mail.encoded, [mail.from].flatten.first, destinations)
    end
  end
end
