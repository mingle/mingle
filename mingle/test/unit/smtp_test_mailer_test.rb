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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../documentation_test_helper')

class SmtpTestMailerTest < ActiveSupport::TestCase
  include DocumentationTestHelper

  CHARSET = "utf-8"

  def setup
    SmtpConfiguration.load
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.mime_version = '1.0'
    # @member = User.find_by_login('member')
    # @project = create_project(:admins => [User.find_by_login('proj_admin')])
    # login_as_admin
    # @project.update_attributes(:email_sender_name => 'mailman', :email_address => 'post@office.com')
  end

  def test_mailer_requester_information
    old_options = ActionMailer::Base.default_url_options
    begin
      ActionMailer::Base.default_url_options = {:protocol => 'https', :host => 'localhost'}
      response = SmtpTestMailer.deliver_test("admin@mingle.com", 'mingle', 'do-not-reply@example.com')
      assert_equal 'do-not-reply@example.com', response.from_addrs.first.spec
      assert_equal 'mingle', response.from_addrs.first.name
      assert_equal "Mingle test mail", response.subject
      assert_include %{please check your site url property settings. For more information visit the <a target="_blank" href="#{build_help_link('advanced_mingle_configuration.html#site_url')}">site url help</a>}, response.body
    ensure
      ActionMailer::Base.default_url_options = old_options
    end
  end
end
