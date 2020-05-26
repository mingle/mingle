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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: api_version_2
class ApiLicenseTest < ActiveSupport::TestCase

  def setup
    enable_basic_auth
    @url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/info.xml"


    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')]) { |project| create_cards(project, 3) }
    end
    @project.add_member(User.find_by_login('bob'))
    API::Card.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    API::Card.prefix = "/api/v2/projects/#{@project.identifier}/"
    @url_prefix = url_prefix(@project)
    @no_api_version_url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
    @read_only_url_prefix = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"


  end


  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  def test_can_get_version_number_and_revision_number
    license_key = SetupHelper.license_key_for_test({:licensee => SetupHelper.licensed_to_for_test, :expiration_date => '2008-07-31', :max_active_users => 100})
    CurrentLicense.register!(license_key, SetupHelper.licensed_to_for_test)
    fake_clock(2008, 7, 5)
    response = get(@url, {})
    assert_equal "200", response.code
  end

  def test_api_should_respond_during_warning_period
    license_key = SetupHelper.license_key_for_test({:licensee => SetupHelper.licensed_to_for_test, :expiration_date => '2008-07-31', :max_active_users => 100})
    CurrentLicense.register!(license_key, SetupHelper.licensed_to_for_test)

    fake_clock(2008, 7, 5)

    response = get("#{@url_prefix}/cards/execute_mql.xml?mql=number=1", {})
    assert_equal "200", response.code

    response = get("#{@url_prefix}/cards/execute_mql.json?mql=number=1", {})
    assert_equal "200", response.code
  end

end
