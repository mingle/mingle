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

class LicenseAlertMailerTest < ActiveSupport::TestCase

  def test_license_alert_is_sent_to_mingle_sales_team
    email = LicenseAlertMailer.create_alert_for_5_licenses_left( :alert_message => '5 licenses left')

    assert_equal [ActionMailer::Base.default_sender[:address]], email.from
    assert_equal MingleConfiguration.sales_team_email_address, email.to
  end

  def test_subject_for_5_license_alert
    email = LicenseAlertMailer.create_alert_for_5_licenses_left( :tenant_organization => 'Tenant Company' ,:alert_message => '5 licenses left',:tenant_name => 'Mingle')

    assert_equal 'License alert: Mingle for Tenant Company', email.subject
  end

  def test_subject_for_5_license_alert_when_organization_name_is_blank
    email = LicenseAlertMailer.create_alert_for_5_licenses_left(:alert_message => '5 licenses left',:tenant_name => 'Mingle')

    assert_equal 'License alert: Mingle', email.subject
  end

  def test_subject_for_no_licenses_alert
    email = LicenseAlertMailer.create_alert_for_no_licenses_left( :tenant_organization => 'Tenant Company' ,:alert_message => 'No licenses left',:tenant_name => 'Testing')

    assert_equal 'License alert: Testing for Tenant Company', email.subject
  end

  def test_body_for_5_license_alert
    email = LicenseAlertMailer.create_alert_for_5_licenses_left( :tenant_organization => 'Tenant Company' ,:tenant_url => 'http://blahblah.com', :alert_message => '5 licenses left')

    assert_equal "<pre style='font-family: sans-serif; font-size: 15px' >Tenant Company (<a href=http://blahblah.com>http://blahblah.com</a>) has 5 licenses left.
Do they need to purchase new licenses? Give them a nudge! :-)</pre>", email.body
  end

  def test_body_for_no_license_alert
    email = LicenseAlertMailer.create_alert_for_no_licenses_left( :tenant_organization => 'Tenant Company' ,:tenant_url => 'http://blahblah.com', :alert_message => 'No licenses left')

    assert_equal "<pre style='font-family: sans-serif; font-size: 15px' >Tenant Company (<a href=http://blahblah.com>http://blahblah.com</a>) has no licenses left.
Surely they need to add more licenses!</pre>", email.body
  end
end
