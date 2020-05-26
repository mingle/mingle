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
class ApiTransitionTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
      setup_property_definitions :status => ['open', 'fixed', 'closed']

      @transition = create_transition(@project, 'close', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    end

    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  def test_empty_transitions_xml
    User.find_by_login('admin').with_current do
      @project = with_new_project do |project|
        xml = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}/transitions.xml", {}).body
        assert_equal 1, get_number_of_elements(xml, "//transitions")
        assert_equal 'array', get_attribute_by_xpath(xml, "//transitions/@type")
        assert_equal 0, elements_children_count_at(xml, "//transitions")
      end
    end
  end

  def test_transitions_xml_api
    xml = get("#{@url_prefix}/transitions.xml", {}).body
    assert_equal 1, get_number_of_elements(xml, "//transitions")
    assert_equal @transition.id, get_element_text_by_xpath(xml, "//transitions/transition/id").to_i
    assert_equal 'close', get_element_text_by_xpath(xml, "//transitions/transition/name")
    assert_equal "false", get_element_text_by_xpath(xml, "//transitions/transition/require_comment")
  end

  def test_transition_xml_api
    xml = get("#{@url_prefix}/transitions/#{@transition.id}.xml", {}).body
    assert_equal 1, get_number_of_elements(xml, "//transition")
    assert_equal @transition.id, get_element_text_by_xpath(xml, "//transition/id").to_i
  end

  def test_should_include_compact_group_when_get_specific_transition
    group = create_group('group')
    transition_with_group = create_transition(@project, 'transition with group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])

    xml = get("#{@url_prefix}/transitions/#{transition_with_group.id}.xml", {}).body

    assert_equal 1, get_number_of_elements(xml, "//transition/only_available_for_groups/group")
    assert_equal 'group', get_element_text_by_xpath(xml, "//transition/only_available_for_groups/group/name")
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{group.id}.xml", get_attribute_by_xpath(xml, "//transition/only_available_for_groups/group/@url")

    assert_equal 0, get_number_of_elements(xml, "//transition/only_available_for_groups/group/id")
  end
end
