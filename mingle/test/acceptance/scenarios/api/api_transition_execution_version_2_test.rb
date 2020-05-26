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

# Tags: api_version_2, cards, transition
class ApiTransitionExecutionVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end

    API::TransitionExecution.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::TransitionExecution.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def version
    "v2"
  end

  def test_transition_execution_result_should_only_include_status
    setup_property_definitions :status => ['new', 'open']
    transition = create_transition(@project, 'open card', :set_properties => {:status => 'open'})
    params = {'transition_execution[card]' => '1'}
    response = post("#{API::TransitionExecution.site}/transition_executions/#{transition.id}.xml", params)
    document = REXML::Document.new(response.read_body)
    assert_equal ['status'], document.elements_at("/transition_execution/*").map(&:name)
  end

  def test_execute_transition_using_id
    setup_property_definitions :status => ['new', 'open']
    transition = create_transition(@project, 'open card', :set_properties => {:status => 'open'})
    response = post("#{API::TransitionExecution.site}/transition_executions/#{transition.id}.xml", 'transition_execution[card]' => '1')
    assert_equal 'completed', get_element_text_by_xpath(response.body, "//transition_execution/status")
    @project.with_active_project do |project|
      assert_equal 'open', @project.reload.cards.find_by_number(1).cp_status
    end
  end

  def test_execute_transition_should_give_error_when_parameters_missing
    setup_property_definitions :status => ['new', 'open']
    transition = create_transition(@project, 'open card', :set_properties => {:status => 'open'})
    response = post("#{API::TransitionExecution.site}/transition_executions/#{transition.id}.xml", {})
    assert_equal 'Must provide number of card to execute transition on.', get_element_text_by_xpath(response.body, "//errors/error[1]")
    assert_equal 'Must specify transition to execute.', get_element_text_by_xpath(response.body, "//errors/error[2]")
  end

  def test_giving_nonexistent_transition_id_should_result_in_a_pleasant_error_message
    setup_property_definitions :status => ['new', 'open']
    response = post("#{API::TransitionExecution.site}/transition_executions/9999.xml", "transition_execution[card]" => 1)
    assert_equal "Couldn't find transition with id 9999.", get_element_text_by_xpath(response.body, "//errors/error[1]")
  end

end
