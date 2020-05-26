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
class AutoTransitionModelTest < ActionController::TestCase
  def test_should_ask_for_required_user_input_property_when_matched_transition_need
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition = create_transition(project, 'open tran', :set_properties => {:status => 'open', :iteration => Transition::USER_INPUT_REQUIRED})
      a_card = project.cards.first

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('open'), {})
      assert_equal [:require_user_input, transition], model.apply
    end
  end

  def test_should_ask_for_required_user_input_property_when_matched_transition_need_comment
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition = create_transition(project, 'open tran', :set_properties => {:status => 'open'}, :require_comment => true)
      a_card = project.cards.first

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('open'), {})
      assert_equal [:require_user_input, transition], model.apply
    end
  end

  def test_should_ask_for_required_user_input_property_when_matched_transition_has_property_is_optional
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition = create_transition(project, 'open tran', :set_properties => {:status => 'open', :iteration => Transition::USER_INPUT_OPTIONAL})
      a_card = project.cards.first

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('open'), {})
      assert_equal [:require_user_input, transition], model.apply
    end
  end

  def test_should_ask_for_choosing_transition_while_matching_multi_transitions
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition_with_it1 = create_transition(project, 'open tran with it 1', :set_properties => {:status => 'open', :iteration => 1})
      transition_with_it2 = create_transition(project, 'open tran with it 2', :set_properties => {:status => 'open', :iteration => 2})
      a_card = project.cards.first

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('open'), {})
      assert_equal [:multi_transitions_matched, [transition_with_it1, transition_with_it2]], model.apply
    end
  end

  def test_should_not_allow_admin_to_update_transition_only_property_directly
    login_as_admin
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition = create_transition(project, 'open tran', :set_properties => {:status => 'open', :iteration => Transition::USER_INPUT_OPTIONAL})
      a_card = project.cards.first

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('new'), {})
      assert_equal [:no_transition_matched], model.apply
    end
  end

  def test_should_handle_non_property_change_if_property_value_is_not_changed
    login_as_admin
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      a_card = create_card!(:name => 'new card', :type => 'Card', :status => 'new' )

      model = AutoTransition::Model.new(project, a_card, status.property_value_from_db('new'), {})
      assert_equal [:non_property_change], model.apply
    end
  end
end
