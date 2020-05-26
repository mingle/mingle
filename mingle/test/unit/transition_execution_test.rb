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

class TransitionExecutionTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
  end
  
  def test_to_xml_version_1
    expected = %Q{<?xml version="1.0" encoding="UTF-8"?><transition_execution> <id type="integer">-1</id> <status>new</status> </transition_execution>}
    assert_equal_ignoring_spaces expected,  TransitionExecution.new(@project, {}).to_xml(:version => "v1")
  end
  
  def test_to_xml_version_2
    expected = %Q{<?xml version="1.0" encoding="UTF-8"?><transition_execution> <status>new</status> </transition_execution>}
    assert_equal_ignoring_spaces expected,  TransitionExecution.new(@project, {}).to_xml(:version => "v2")
  end
  
  def test_process_should_return_errors_when_missing_required_param
    transition = TransitionExecution.new(@project, {})
    transition.process
    assert_equal "Must provide number of card to execute transition on.", transition.errors.full_messages.first
  end

  def test_process_should_return_errors_when_card_not_found
    transition = TransitionExecution.new(@project, :card => '999')
    transition.process
    assert_equal "Couldn't find card by number 999.", transition.errors.full_messages.first
  end
  
  def test_process_should_return_errors_when_params_are_nil
    transition = TransitionExecution.new(@project, nil)
    transition.process
    assert_equal ["Must provide number of card to execute transition on.", "Must specify transition to execute."], transition.errors.full_messages
  end

  def test_process_should_return_errors_when_transition_not_found
    transition = TransitionExecution.new(@project, :transition => '9999', :card => '1')
    transition.process
    assert_equal "Couldn't find transition by name 9999.", transition.errors.full_messages.first
  end
  
  def test_should_raise_error_when_both_transition_id_and_name_are_supplied
    assert_raise RuntimeError do
      TransitionExecution.new(@project, :id => '9999', :transition => '9999', :card => '1')
    end
  end
  
end
