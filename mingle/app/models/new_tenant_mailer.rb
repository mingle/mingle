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

class NewTenantMailer < ActionMailer::Base

  def welcome_email(opts)
    recipients opts[:recipient_email]
    from opts[:from]
    cc opts[:copy_to]
    bcc opts[:bcc]
    subject 'Your new Mingle site is ready'

    body :site_link => opts[:site_link],
         :reset_password_link => opts[:reset_password_link],
         :sign_in_name => opts[:sign_in_name],
         :recipient_name => opts[:recipient_name]
  end
end
