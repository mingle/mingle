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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')
class GroupApiTest < ActiveSupport::TestCase

#Tag: api_version_2
  fixtures :users, :login_access

  FIRST_GROUP="group_api_1"

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'atom api', :admins => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
      end
    end

    @group_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups.xml"

  end

  def teardown
    disable_basic_auth
  end

  def test_get_all_groups
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@team_member, @project_admin, @read_only_user])
    output = %x[curl -X GET #{@group_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal("#{first_group.id}", get_element_text_by_xpath(output, "//groups/group/id"))
    assert_equal("#{first_group.name}", get_element_text_by_xpath(output, "//groups/group/name"))

    assert_equal("array", get_attribute_by_xpath(output, "//groups/group/projects_members/@type"))
    assert_equal [@project.name], get_elements_text_by_xpath(output, "//groups/group/projects_members/projects_member/project/name").uniq
    assert_equal ["http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}.xml"], get_attributes_by_xpath(output, "//groups/group/projects_members/projects_member/project/@url").uniq

    [@team_member, @project_admin, @read_only_user].each do |user|
      assert get_attributes_by_xpath(output, "//groups/group/projects_members/projects_member/user/@url").include?("http://localhost:#{MINGLE_PORT}/api/v2/users/#{user.id}.xml")
      assert get_elements_text_by_xpath(output, "//groups/group/projects_members/projects_member/user/name").include?(user.name)
      assert get_elements_text_by_xpath(output, "//groups/group/projects_members/projects_member/user/login").include?(user.login)
    end
  end


  def test_get_specific_group_by_group_id
    group = create_group_and_add_its_members(FIRST_GROUP, [@team_member, @project_admin, @read_only_user])

    group_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{group.id}.xml"
    output = %x[curl -X GET #{group_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal("#{group.id}", get_element_text_by_xpath(output, "//group/id"))
    assert_equal("#{group.name}", get_element_text_by_xpath(output, "//group/name"))

    assert_equal [@project.name], get_elements_text_by_xpath(output, "//group/projects_members/projects_member/project/name").uniq
    assert_equal ["http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}.xml"], get_attributes_by_xpath(output, "//group/projects_members/projects_member/project/@url").uniq

    group.users.each do |member|
      assert get_attributes_by_xpath(output, "//group/projects_members/projects_member/user/@url").include?("http://localhost:#{MINGLE_PORT}/api/v2/users/#{member.id}.xml")
      assert_equal("http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}.xml", get_attribute_by_xpath(output, "//group/projects_members/projects_member[1]/project/@url"))
    end
  end


  def test_team_member_can_get_groups_by_api
    group = create_group_and_add_its_members(FIRST_GROUP, [@team_member])
    url_for_team_member = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups.xml"
    output = %x[curl -X GET #{url_for_team_member} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal("#{group.id}", get_element_text_by_xpath(output, "//group/id"))
    assert_equal("#{group.name}", get_element_text_by_xpath(output, "//group/name"))
  end

  def test_read_only_user_can_get_groups_by_api
    group = create_group_and_add_its_members(FIRST_GROUP, [@team_member])
    url_for_read_only_user = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups.xml"
    output = %x[curl -X GET #{url_for_read_only_user} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal("#{group.id}", get_element_text_by_xpath(output, "//group/id"))
    assert_equal("#{group.name}", get_element_text_by_xpath(output, "//group/name"))
  end

  def test_none_team_member_cannot_get_groups_by_api
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@team_member, @project_admin, @read_only_user])
    url_for_none_team_member = "http://bob:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups.xml"
    output = %x[curl -X GET #{url_for_none_team_member} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
  end

  def test_anoymous_user_can_get_groups_by_api_if_the_project_is_anoymous_accessible
    User.find_by_login('admin').with_current do
      @project.update_attribute :anonymous_accessible, true
      @project.save
    end
    change_license_to_allow_anonymous_access
    group = create_group_and_add_its_members(FIRST_GROUP, [@team_member, @project_admin, @read_only_user])
    url_for_anonymous_user = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups.xml"
    output = %x[curl -X GET #{url_for_anonymous_user} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal("#{group.id}", get_element_text_by_xpath(output, "//group/id"))
    assert_equal("#{group.name}", get_element_text_by_xpath(output, "//group/name"))
  end


end
