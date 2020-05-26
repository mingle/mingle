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

class NotifyMail < ActionMailer::Base

  helper :mail
  
  def signup(txt)
    body(:name => txt)
  end
  
  def multipart
    recipients 'some_address@email.com'
    subject    'multi part email'
    from       "another_user@email.com"
    content_type 'multipart/alternative'
    
    part :content_type => "text/html", :body => render_message("multipart_html", {})
    part "text/plain" do |p|
      p.body = render_message("multipart_plain", {})
    end
  end
  
  def implicit_multipart
    recipients 'some_address@email.com'
    subject    'multi part email'
    from       "another_user@email.com"
  end
end
