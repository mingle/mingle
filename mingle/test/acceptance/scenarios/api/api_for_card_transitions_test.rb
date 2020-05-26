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
class ApiForCardTransitionsTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
      setup_property_definitions :status => ['open', 'fixed', 'closed']

      @card = create_card!(:name => 'card status is open', :status => 'open')
      @transition = create_transition(@project, 'close', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    end

    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  def test_should_return_transitions_for_card
    xml = get("#{@url_prefix}/cards/#{@card.number}/transitions.xml", {}).body
    assert_equal 1, get_number_of_elements(xml, "//transitions")
    assert_equal @transition.id, get_element_text_by_xpath(xml, "//transitions/transition/id").to_i
    assert_equal 'close', get_element_text_by_xpath(xml, "//transitions/transition/name")
    assert_equal "false", get_element_text_by_xpath(xml, "//transitions/transition/require_comment")
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/transition_executions/#{@transition.id}.xml", get_element_text_by_xpath(xml, "//transitions/transition/transition_execution_url")
    assert_equal 0, get_number_of_elements(xml, "//transitions/transition/user_input_optional/property_definition")
    assert_equal 1, get_number_of_elements(xml, "//transitions/transition/user_input_required/property_definition")

    assert_equal "status", get_element_text_by_xpath(xml, "//transitions/transition/user_input_required/property_definition/name")
    assert_equal 3, get_number_of_elements(xml, "//transitions/transition/user_input_required/property_definition/property_value_details/property_value")

    open = @project.find_property_definition('status').find_enumeration_value('open')
    assert_equal 1, get_number_of_elements(xml, "//transitions/transition/user_input_required/property_definition[name='status']/property_value_details/property_value[value='open']")
  end

end
