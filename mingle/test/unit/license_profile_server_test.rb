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

class LicenseProfileServerTest < ActiveSupport::TestCase

  def setup
    clear_license
    FEATURES.deactivate("db_licensing")
    Clock.fake_now(:year => 2008, :month => 7, :day => 12)

    MingleConfiguration.app_namespace = "parsley"
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)
    login_as_member
  end

  def teardown
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
    Clock.reset_fake
    FEATURES.activate("db_licensing")
    CurrentLicense.clear_cache
  end

  def test_downgrade_status_when_unpaid_site_need_to_pay
    assert !CurrentLicense.downgrade?
    MingleConfiguration.with_new_buy_process_overridden_to('true') do
      setup_license_on_profile_server
      assert !CurrentLicense.downgrade?

      CurrentLicense.clear_cache

      setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')
      assert CurrentLicense.downgrade?
    end
  end

  def test_should_never_be_downgrade_status_when_site_is_paid
    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01', "paid?" => true)
    MingleConfiguration.with_new_buy_process_overridden_to('true') do
      assert !CurrentLicense.downgrade?
    end
  end

  def test_downgrade_unpaid_site_to_free_tier
    User.find(:all).each(&:destroy_without_callbacks)
    5.times do
      create_user!
    end
    login(User.first)
    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')
    @http_stub.requests.clear

    CurrentLicense.downgrade

    assert_equal 1, @http_stub.requests.size
    assert_equal :put, @http_stub.last_request.http_method
    assert_equal "https://profile_server/organizations/parsley.json", @http_stub.last_request.url
    put_attrs = JSON.parse(@http_stub.last_request.body)["organization"]
    assert_equal 'Mingle', put_attrs['product_edition']
    assert_equal 5, put_attrs['max_active_full_users']
    assert_equal (Clock.now + 10.years).strftime("%F"), put_attrs['subscription_expires_on']
  end

  def test_downgrade_site_should_deactive_users_if_there_are_more_than_5_active_users
    User.find(:all).each(&:destroy_without_callbacks)
    6.times do |i|
      user = create_user!(:login => "user-#{i+1}")
      user.login_access.update_attribute(:last_login_at, Clock.now - i.hour)
    end
    create_user!(:login => "user-7")
    login(User.first)

    assert_equal 7, User.activated_full_users

    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')
    @http_stub.requests.clear

    CurrentLicense.downgrade
    assert_equal 5, User.activated_full_users
    assert_not_include "user-7", User.all.select(&:activated?).map(&:login)

    assert_equal 2, @http_stub.requests.size

    assert_equal :put, @http_stub.requests.first.http_method
    assert_equal "https://profile_server/organizations/parsley.json", @http_stub.requests.first.url

    assert_equal :post, @http_stub.last_request.http_method
    assert_equal "https://profile_server/organizations/parsley/users/deactivate.json", @http_stub.last_request.url
    except = JSON.parse(@http_stub.last_request.body)["except"]
    assert_equal 5, except.size
  end

  def test_downgrade_site_should_keep_recent_active_users_and_at_least_one_admin
    User.find(:all).each(&:destroy_without_callbacks)
    # first user is admin anyway
    u = create_user!(:admin => true, :name => "u-admin0")
    u.login_access.update_attribute(:last_login_at, Clock.now - 10.day)
    5.times do |i|
      u = create_user!(:name => "u#{i}", :admin => false)
      u.login_access.update_attribute(:last_login_at, Clock.now - i.day)
    end
    login(User.find_by_name("u0"))

    u = create_user!(:admin => true, :name => "u-admin1")
    u.login_access.update_attribute(:last_login_at, Clock.now - 8.day)
    u = create_user!(:admin => true, :name => "u-admin2")
    u.login_access.update_attribute(:last_login_at, Clock.now - 15.day)

    assert_equal 8, User.activated_full_users

    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')

    CurrentLicense.downgrade
    activated_users = User.all.select(&:activated?)
    assert_equal ['u-admin1', 'u0', 'u1', 'u2', 'u3'], activated_users.map(&:name).sort

    put = @http_stub.requests.find{|r| r.http_method == :put}
    setup_license_on_profile_server(JSON.parse(put.body)["organization"])
    assert CurrentLicense.status.valid?
  end

  def test_downgrade_site_should_keep_current_user
    User.find(:all).each(&:destroy_without_callbacks)
    # first user is admin anyway
    u = create_user!(:admin => true, :name => "u-admin0")
    u.login_access.update_attribute(:last_login_at, Clock.now - 10.day)
    5.times do |i|
      u = create_user!(:name => "u#{i}", :admin => false)
      u.login_access.update_attribute(:last_login_at, Clock.now - i.day)
    end

    current = create_user!(:name => "u-current", :admin => false)
    login(current)

    assert_equal 7, User.activated_full_users

    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')

    # need fake the login time as login method will update it
    current.login_access.update_attribute(:last_login_at, Clock.now - 100.day)
    CurrentLicense.downgrade

    activated_users = User.all.select(&:activated?)
    assert_equal ['u-admin0', 'u-current', 'u0', 'u1', 'u2'], activated_users.map(&:name).sort

    put = @http_stub.requests.find{|r| r.http_method == :put}
    setup_license_on_profile_server(JSON.parse(put.body)["organization"])
    assert CurrentLicense.status.valid?
  end

  def setup_license_on_profile_server(data={})
    response = {
      "name" => "parsley",
      "subscription_expires_on" => "2021-06-10",
      "allow_anonymous" => true,
      "product_edition" => "Mingle Enterprise",
      "max_active_full_users" => 200,
      "max_active_light_users" => 10,
      "users_url" => "https://profile_server/organizations/parsley/users.json",
      "paid?" => false,
      "trial?" => true,
      "buying?" => false
    }.merge(data)
    @http_stub.register_get_response('https://profile_server/organizations/parsley.json', [200, response.to_json])
  end

end
