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

class RecoverPasswordMailerTest < ActiveSupport::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup
    @old_mingle_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'
    
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.mime_version = '1.0'
  end
  
  def teardown
    MingleConfiguration.site_url = @old_mingle_site_url
  end
  
  def test_recover_password_uses_default_subject_line
    RecoverPasswordMailer.subject_line = nil
    assert_recover_password("Lost password")
  end
  
  def test_recover_password_uses_set_subject_line
    RecoverPasswordMailer.subject_line = "test subject line"
    assert_recover_password("test subject line")
  end
  
  def test_should_use_default_mingle_sender
    response = RecoverPasswordMailer.deliver_recover_password(OpenStruct.new(:email => 'dd@email.com'), {:action => 'change_password', :controller => 'profile', :ticket => 12345}, {:controller => 'projects'})
    assert_equal 'hello@example.com', response.from_addrs.first.spec #from smtp_config
    assert_equal 'mingle', response.from_addrs.first.name #from smtp_config
  end  
  
  def assert_recover_password(expected_subject_line)
    response = RecoverPasswordMailer.deliver_recover_password(OpenStruct.new(:email => 'dd@email.com'), {:action => 'change_password', :controller => 'profile', :ticket => 12345}, {:controller => 'projects'})

    assert_equal expected_subject_line, response.subject
    assert_match('http://test.host/profile/change_password?ticket=12345', response.body)
    assert_match('http://test.host', response.body)    
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/recover_password_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
