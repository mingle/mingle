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

class AccountMailer < ActionMailer::Base
  include UrlWriterWithFullPath, MailerHelper

  def buy(params)
    recipients MingleConfiguration.ask_for_upgrade_email_recipient
    setup_generic_email
    subject "Alert: Mingle SaaS BUY NOW: #{MingleConfiguration.site_url}"
    body(params)
  end

  private

  def setup_generic_email
    from default_sender
    content_type "text/html"
  end
end
