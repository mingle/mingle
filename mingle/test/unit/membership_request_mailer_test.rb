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

class MembershipRequestMailerTest < ActiveSupport::TestCase
  CHARSET = "utf-8"

  def setup
    SmtpConfiguration.load
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @member = User.find_by_login('member')
    @project = create_project(:admins => [User.find_by_login('proj_admin'), User.find_by_login('longbob')])
    login_as_admin
    @project.update_attributes(:email_sender_name => 'mailman', :email_address => 'post@office.com')
  end

  def test_mailer_requester_information
    deliver_request(@member, @project) do |mail|
      assert_equal ['longbob@email.com', 'proj_admin@email.com'], mail.to_addrs.collect(&:spec).sort
      assert_equal ['post@office.com'], mail.from_addrs.collect(&:spec)
      assert_equal 'mailman', mail.from_addrs.first.name
      assert_equal "#{@member.name} wants to join your project #{@project.name}", mail.subject
      assert_include 'If you want to add this user to your project, please click the link below.', mail.body
      assert_include "https://somehost/projects/#{@project.identifier}/team/list_users_for_add_member?user_id=#{@member.id}", mail.body
    end
  end

  def test_should_skip_project_admin_without_email_address
    User.find_by_login("longbob").update_attributes(:email => nil)
    deliver_request(@member, @project) do |mail|
      assert_equal ['proj_admin@email.com'], mail.to_addrs.collect(&:spec)
    end
  end

  private

  def deliver_request(user, project, &block)
    old_options = MingleConfiguration.site_u_r_l
    begin
      MingleConfiguration.site_u_r_l = "https://somehost"

      yield(MembershipRequestMailer.deliver_request(user, project))
    ensure
      MingleConfiguration.site_u_r_l = old_options
    end
  end
end
