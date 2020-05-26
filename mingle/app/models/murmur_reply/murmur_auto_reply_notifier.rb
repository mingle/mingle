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

class MurmurAutoReplyNotifier < ActionMailer::Base

  def notify(recipient, from, subject, error_message)
    content_type 'text/html'
    recipients [recipient]
    from TMail::Address.parse("Mingle Auto-Reply <#{from.is_a?(TMail::Address)? from.address : from}>")
    subject subject
    reply_to from
    body :error_message => error_message
  end

end
