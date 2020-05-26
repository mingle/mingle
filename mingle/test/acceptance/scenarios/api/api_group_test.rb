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
class ApiGroupTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @admin = User.find_by_login('admin')
    @admin.with_current do
      @project = with_new_project do |project|
        project.user_defined_groups.create!(:name => 'group one')
        project.add_member(@admin)
        project.user_defined_groups.first.add_member(@admin)
      end
    end

    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    @groups = @project.user_defined_groups
  end

  def teardown
    disable_basic_auth
  end

  def test_groups_xml_api
    xml = get("#{@url_prefix}/groups.xml", {}).body

    assert_equal 1, get_number_of_elements(xml, "//groups")
    assert_equal @groups.first.id, get_element_text_by_xpath(xml, "//groups/group/id").to_i
    assert_equal 'group one', get_element_text_by_xpath(xml, "//groups/group/name")
    assert_equal 1, get_number_of_elements(xml, "//groups/group/projects_members")
  end

  def test_group_xml_api
    xml = get("#{@url_prefix}/groups/#{@groups.first.id}.xml", {}).body

    assert_equal 1, get_number_of_elements(xml, "//group")
    assert_equal @groups.first.id, get_element_text_by_xpath(xml, "//group/id").to_i
    assert_equal 'false', get_element_text_by_xpath(xml, "//group/projects_members/projects_member/admin")
    assert_equal 'false', get_element_text_by_xpath(xml, "//group/projects_members/projects_member/readonly_member")
    assert_equal 1, get_number_of_elements(xml, "//group/projects_members/projects_member/user").to_i
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/users/#{@admin.id}.xml", get_attribute_by_xpath(xml, "//group/projects_members/projects_member/user/@url")
    assert_equal @admin.name, get_element_text_by_xpath(xml, "//group/projects_members/projects_member/user/name")
    assert_equal @admin.login, get_element_text_by_xpath(xml, "//group/projects_members/projects_member/user/login")
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}.xml", get_attribute_by_xpath(xml, "//group/projects_members/projects_member/project/@url")
    assert_equal @project.identifier, get_element_text_by_xpath(xml, "//group/projects_members/projects_member/project/identifier")
  end
end
