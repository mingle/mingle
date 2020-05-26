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

# Tags: scenario, transitions, properties, project
class Scenario108AutomateTransitionTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STORY = 'Story'
  STATUS = 'Status'
  PRIORITY = 'Priority'
  NEW = 'New'
  OPEN = 'Open'
  HIGH = 'High'
  LOW = 'Low'
  NOTSET = '(not set)'
  OWNER = 'owner'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @team_member = users(:longbob)
    @project = create_project(:prefix => 'scenario_108', :users => [@team_member], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_property_definitions(PRIORITY => [HIGH, LOW])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, PRIORITY])
    login_as_proj_admin_user
    @card = create_card!(:name => 'first card', :type => STORY)
    make_property_transition_only_for(@project, STATUS)
  end


  def test_mingle_admin_not_in_team_can_not_apply_transition_which_will_set_property_to_current_user
     logout
     login_as("#{@mingle_admin.login}")
     user_property = create_property_definition_for(@project, OWNER, :type => 'user')

     transition = create_transition_for(@project, "Open Story", :type => STORY, :set_properties => {STATUS => OPEN, OWNER => '(current user)'})
     transition1 = create_transition_for(@project, "Add Story", :type  => STORY, :set_properties => {STATUS => NEW, OWNER => '(current user)'}, :require_comment => true)

     new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
     open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)

     navigate_to_grid_view_for(@project, :group_by => STATUS)
     drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
     assert_error_message_without_html_content("#{transition.name} could not be applied to card ##{new_card.number} because: #{@mingle_admin.name} is not a project member")
     assert_card_in_lane(STATUS, NEW, new_card.number)

     drag_and_drop_card_from_lane(@card.html_id, STATUS, NEW)
     add_comment_for_transition_to_complete_text_area('go, not set card.')
     click_on_complete_transition
     assert_error_message_without_html_content("#{@mingle_admin.name} is not a project member")
     assert_card_in_lane(STATUS, '', @card.number)
  end

  def test_auto_transiton_only_applied_to_correct_lane_when_moving_card_in_grid_view_group_by_tran_only
    transition = create_transition_for(@project, "Transition Only", :type => STORY, :set_properties => {STATUS => OPEN, PRIORITY => HIGH} )
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)

    navigate_to_grid_view_for(@project, :group_by => STATUS)

    assert_card_in_lane(STATUS, '', @card.number)
    drag_and_drop_card_from_lane(@card.html_id, STATUS, NEW, :ajax => false)
    assert_error_message_without_html_content("Sorry, you cannot drag this card to lane #{NEW}. Please ensure there is a transition to allow this action and this card satisfies the requirements.")
    assert_card_in_lane(STATUS, '', @card.number)

    assert_card_in_lane(STATUS, NEW, new_card.number)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_notice_message("#{transition.name} successfully applied to card ##{new_card.number}")
    assert_card_in_lane(STATUS, OPEN, new_card.number)
    open_card(@project, new_card)
    assert_property_set_on_card_show(PRIORITY, HIGH)
  end

  def test_on_multiple_auto_transitions_when_moving_cards_in_grid_view_group_by_trans_only
    transition_1 = create_transition_for(@project, "Open Story", :type => STORY, :set_properties => {STATUS => OPEN} )
    transition_2 = create_transition_for(@project, "Open High Story", :type => STORY, :set_properties => {STATUS => OPEN, PRIORITY => HIGH} )
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    assert_card_in_lane(STATUS, NEW, new_card.number)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_transition_selection_light_box_present
    assert_transition_options_present_in_transition_light_box([transition_1, transition_2])
    click_transition_link_on_transition_option_light_box(transition_2)
    assert_notice_message("#{transition_2.name} successfully applied to card ##{new_card.number}")
    assert_card_in_lane(STATUS, OPEN, new_card.number)
    open_card(@project, new_card)
    assert_property_set_on_card_show(PRIORITY, HIGH)
  end

  def test_can_cancel_on_multiple_auto_transitions_popup
    transition_1 = create_transition_for(@project, "Open Story", :type => STORY, :set_properties => {STATUS => OPEN} )
    transition_2 = create_transition_for(@project, "Open High Story", :type => STORY, :set_properties => {STATUS => OPEN, PRIORITY => HIGH} )
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    assert_card_in_lane(STATUS, NEW, new_card.number)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_transition_selection_light_box_present
    click_cancel_on_transiton_light_box_window
    assert_card_in_lane(STATUS, NEW, new_card.number)
    open_card(@project, new_card)
    assert_property_set_on_card_show(PRIORITY, NOTSET)
  end

  def test_auto_transition_with_user_input_option
    transition = create_transition_for(@project, "Open Story", :type => STORY, :require_comment => true, :set_properties => {STATUS => OPEN} )
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_transition_selection_light_box_present
    assert_transition_complete_button_disabled
    add_comment_for_transition_to_complete_text_area('comment from here')
    assert_transition_complete_button_enabled
    click_on_complete_transition
    assert_notice_message("#{transition.name} successfully applied to card ##{new_card.number}")
  end

  def test_added_card_was_not_shown_message_appears_after_auto_transition
    transition = create_transition_for(@project, "Open Story", :type => STORY, :set_properties => {STATUS => OPEN, PRIORITY => HIGH})
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => "#{PRIORITY}", :value => "#{NOTSET}")

    assert_card_in_lane(STATUS, NEW, new_card.number)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_card_not_in_lane(STATUS, NEW, new_card.number)
    assert_card_not_in_lane(STATUS, OPEN, new_card.number)
    assert_notice_message("#{transition.name} successfully applied to card ##{new_card.number}")
    assert_info_message("card ##{new_card.number} property was updated, but is not shown because it does not match the current filter.")
    open_card(@project, new_card)
    assert_property_set_on_card_show(PRIORITY, HIGH)
    assert_property_set_on_card_show(STATUS, OPEN)
  end

  def test_auto_transition_can_set_hidden_property
    hide_property(@project, PRIORITY)
    transition_set_hidden_property = create_transition_for(@project, "Open Story", :type => STORY, :set_properties => {STATUS => OPEN, PRIORITY => HIGH})
    new_card = create_card!(:name => 'new card', :type => STORY, STATUS => NEW)
    open_card = create_card!(:name => 'open card', :type => STORY, STATUS => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    assert_card_in_lane(STATUS, NEW, new_card.number)
    drag_and_drop_card_from_lane(new_card.html_id, STATUS, OPEN)
    assert_notice_message("#{transition_set_hidden_property.name} successfully applied to card ##{new_card.number}")
    open_card(@project, new_card)
    ensure_hidden_properties_visible
    assert_property_set_on_card_show(PRIORITY, HIGH)
  end

  def test_user_name_is_used_to_identify_team_member_property_when_auto_transition_throw_error
    user_property = create_property_definition_for(@project, OWNER, :type => 'user')
    make_property_transition_only_for(@project, OWNER)
    transition = create_transition(@project, "set to project admin", :set_properties => {user_property.name => @project_admin_user.id})
    navigate_to_grid_view_for(@project, :group_by => "owner")
    add_lanes(@project, "owner", [@project_admin_user.email, @team_member.email])
    drag_and_drop_card_from_lane(@card.html_id, OWNER,  @team_member.id)
    assert_error_message_without_html_content("Sorry, you cannot drag this card to lane #{@team_member.name}. Please ensure there is a transition to allow this action and this card satisfies the requirements.")
  end
end
