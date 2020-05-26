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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class SmtpTestMailerTest < ActionMailer::TestCase

  def setup
    SmtpConfiguration.load
    @old_options = ActionMailer::Base.default_url_options
  end

  def teardown
    ActionMailer::Base.default_url_options = @old_options
  end

  def test_mailer_requester_information
    ActionMailer::Base.default_url_options = {:protocol => 'https', :host => 'localhost'}
    email = SmtpTestMailer.test('admin@mingle.com', 'mingle', 'do-not-reply@example.com')
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal ['do-not-reply@example.com'], email.from
    assert_equal 'Mingle test mail', email.subject
    assert_includes email.body.to_s, %{please check your site url property settings. For more information visit the <a target="_blank" href="#{ONLINE_HELP_DOC_DOMAIN}/advanced_mingle_configuration.html#site_url">site url help</a>}
    assert_equal 'mingle <do-not-reply@example.com>', email['from'].to_s
  end
end
