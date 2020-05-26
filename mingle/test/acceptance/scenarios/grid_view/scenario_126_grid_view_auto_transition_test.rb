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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: gridview, transitions
class Scenario126GridViewAutoTransitionTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  does_not_work_on_ie

  STATUS = "status"
  PRIORITY = "priority"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_123', :admins => [users(:proj_admin)])
    @project.activate
    login_as_proj_admin_user
    create_property_definition_for(@project, STATUS)
    create_property_definition_for(@project, PRIORITY)
    make_property_transition_only_for(@project, STATUS)


    @card1 = create_card!(:name => 'card1', :status => 'new', :card_type => 'Card')
    @card2 = create_card!(:name => 'card2', :status => 'open', :card_type => 'Card')
    @card3 = create_card!(:name => 'card3', :status => 'new', :card_type => 'Card')
    @card4 = create_card!(:name => 'card4', :status => 'open', :card_type => 'Card')
    @card5 = create_card!(:name => 'card5', :status => 'new', :card_type => 'Card')
    @card6 = create_card!(:name => 'card6', :status => 'open', :card_type => 'Card')
  end

  def test_cannot_drag_cards_across_lanes_on_transition_only_property_when_no_transition_exists
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)

    assert_element_present("css=.cell[lane_value='open'] #card_2")

    drag_and_drop_card_to(@card2, @card3)
    assert_error_message_without_html_content("Sorry, you cannot drag this card to lane new. Please ensure there is a transition to allow this action and this card satisfies the requirements.")

    @browser.wait_for_element_present("css=.cell[lane_value='open'] #card_2")
  end

  def test_can_drag_cards_across_lanes_on_transition_only_property_when_transition_exists
    transition = create_transition(@project, 'move card to open', :required_properties => {"status" => "new"}, :set_properties => {"status" => "open"})
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)

    assert_element_present("css=.cell[lane_value='new'] #card_3")
    drag_and_drop_card_to(@card3, @card4)
    @browser.wait_for_element_present("css=.cell[lane_value='open'] #card_3")
  end

  def test_successively_dragging_cards_across_lanes_will_continue_to_trigger_transitions
    transition = create_transition(@project, 'change status', :required_properties => {"status" => "open"}, :set_properties => {"status" => "new", 'Priority' => Transition::USER_INPUT_OPTIONAL})
    transition_2 = create_transition(@project, 'still change status', :required_properties => {"status" => "open"}, :set_properties => {"status" => "new"})
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)

    assert_element_present("css=.cell[lane_value='open'] #card_4")

    drag_and_drop_card_to(@card4, @card5)
    click_cancel_on_transiton_light_box_window

    assert_element_present("css=.cell[lane_value='open'] #card_4")

    drag_and_drop_card_to(@card4, @card3)
    click_transition_link_on_transition_option_light_box(transition)
    click_on_complete_transition(:ajaxwait => true)
    @browser.wait_for_element_not_present("css=.card-icon.operating")

    @browser.wait_for_element_present("css=.cell[lane_value='new'] #card_4")

    drag_and_drop_card_to(@card2, @card5)
    click_transition_link_on_transition_option_light_box(transition_2)
    @browser.wait_for_element_not_present("css=.card-icon.operating")
    @browser.wait_for_element_present("css=.cell[lane_value='new'] #card_2")
  end

  # [mingle1/#6579]
  def test_card_should_revert_position_if_transition_fails
    any_number = setup_allow_any_number_property_definition 'iteration'
    transition = create_transition(@project, 'change status', :required_properties => {"status" => "open"}, :set_properties => {"status" => "new", 'iteration' => Transition::USER_INPUT_OPTIONAL})
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)

    assert_element_present("css=.cell[lane_value='open'] #card_4")

    drag_and_drop_card_to(@card4, @card1)
    add_value_to_free_text_property_lightbox_editor('','iteration','abc')

    click_on_complete_transition(:ajaxwait => true)
    @browser.wait_for_element_not_present("css=.card-icon.operating")
    @browser.wait_for_element_present("css=.cell[lane_value='open'] #card_4")
  end
end
