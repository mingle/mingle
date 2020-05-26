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

class FeedbackMailerTest < ActiveSupport::TestCase

  def test_feedback_is_sent_to_mingle_feedback_email
    email = FeedbackMailer.create_feedback(:message => "Love Mingle!!")
    assert_equal [ActionMailer::Base.default_sender[:address]], email.from
    assert_equal ["mingle.feedback@thoughtworks.com"], email.to
  end

  def test_feedback_is_cc_to_support
    email = FeedbackMailer.create_feedback(:message => "Love Mingle!!", :cc => "support@thoughtworks.com")
    assert_equal ["support@thoughtworks.com"], email.cc
  end

  def test_feedback_is_cc_to_support_only_in_saas_when_feedback_mail_set
    MingleConfiguration.overridden_to(support_email_address: 'bob@example.com', mutitanancy_mode: true, saas_env: :test) do
      email = FeedbackMailer.create_feedback(:message => 'Love Mingle!!!', :cc => 'support@thoughtworks.com')
      assert_equal ['support@thoughtworks.com'], email.cc
      assert_equal ['bob@example.com'], email.to
    end
  end

  def test_feedback_is_sent_to_custom_support_email_address
    MingleConfiguration.with_support_email_address_overridden_to("bob@example.com") do
      email = FeedbackMailer.create_feedback(:message => "Love Mingle!!")
      assert_equal [ActionMailer::Base.default_sender[:address]], email.from
      assert_equal ["bob@example.com"], email.to
    end
  end

  def test_feedback_cc_is_not_sent_with_custom_support_email_address
    MingleConfiguration.with_support_email_address_overridden_to("bob@example.com") do
      email = FeedbackMailer.create_feedback(:message => "Love Mingle!!")
      assert_nil email.cc
    end
  end


  def test_feedback_includes_the_text_by_user
    email = FeedbackMailer.create_feedback(:message => "Trello Shmello!")
    assert_include "Trello Shmello!", email.body
  end

  def test_feedback_includes_the_user_info
    login_as_longbob
    email = FeedbackMailer.create_feedback(:message => "where did the orange go?")
    assert_include "longbob@email.com", email.body
  end

  def test_feedback_includes_a_subject_line
    login_as_longbob
    email = FeedbackMailer.create_feedback(:message => "orange is the new black")
    assert_include "Mingle SaaS feedback", email.subject
  end

  def test_feedback_includes_the_site_name
    login_as_longbob
    email = FeedbackMailer.create_feedback(:message => "orange is the new black", :site_name => 'fandango')
    assert_include "fandango", email.body
  end

  def test_feedback_includes_referer
    login_as_longbob
    email = FeedbackMailer.create_feedback(:message => "orange is the new black", :referer => 'http://localhost')
    assert_include "http://localhost", email.body
  end

end
