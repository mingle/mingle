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
require 'test/unit'
gem "actionpack"
gem "actionmailer"
gem "activesupport"
require "active_support"
require "action_pack"
require "action_mailer"
require "init"

class Emailer < ActionMailer::Base
	def email(h)
		recipients   h[:recipients]
		subject      h[:subject]
		from         h[:from]
		body         h[:body]
		content_type "text/plain"
	end
end

class TlsTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def setup
    ActionMailer::Base.smtp_settings = {
      :address => "smtp.gmail.com",
      :port => 587,
      :user_name => ENV['EMAIL'],
      :password => ENV['PASSWORD'],
      :authentication => :plain,
      :tls => true
    }
  end
  
  def test_send_mail
    Emailer.deliver_email(
      :recipients => ENV["EMAIL"],
      :subject => "SMTP/TLS test",
      :from => ENV["EMAIL"],
      :body => "This email was sent at #{Time.now.inspect}"
    )
  end
end
