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

class RecoverPasswordMailer < ActionMailer::Base
  include UrlWriterWithFullPath
  
  cattr_accessor :sender, :subject_line
  
  def recover_password(user, lost_password_url_options={}, mingle_url_options={})
    raise "SMTP not configured" unless SmtpConfiguration.load
    
    from default_sender
    recipients user.email
    subject RecoverPasswordMailer.subject_line || "Lost password"
    content_type "text/html"

    body :recover_password_url => url_for(lost_password_url_options), :mingle_url => url_for(mingle_url_options)
  end
  
  def default_sender
    "#{ActionMailer::Base.default_sender[:name]}<#{ActionMailer::Base.default_sender[:address]}>"
  end  
  
end
