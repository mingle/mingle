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

# Tags: card-page-history
class Scenario21CreatingCardChangeEventsTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  BLANK = ''
  STATUS = 'status'

  NEW_UNGROUPED_TAG = 'feed'
  NEW_GROUPED_TAG = 'feature-rss'

  MEMBER_USER_EMAIL = 'member@email.com'
  ADMIN_USER_EMAIL = 'admin@email.com'

  NEW = 'new'
  OPEN = 'open'
  TYPE = 'Type'
  TYPE_CARD = 'Card'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_21', :users => [@project_member, users(:admin)])
    setup_property_definitions :feature => ['rss'], :iteration => [1, 2], STATUS => ['new', 'open']
    login_as_project_member
    @browser.open "/projects/#{@project.identifier}"

    @card_name = 'create new email'
    @card_number = create_new_card(@project, :name => @card_name)
  end

  def test_card_creation_creates_new_event
    open_card(@project, @card_number)
    assert_history_for(:card, @card_number).version(1).shows(:created_by => MEMBER_USER_EMAIL)

    navigate_to_history_for @project
    assert_history_for(:card, @card_number).version(1).shows(:created_by => MEMBER_USER_EMAIL)
  end

  def test_creating_property_with_same_name_as_deleted_property_does_not_recreate_old_events
    logout
    login_as_admin_user
    card = create_card!(:name => 'for testing', STATUS => 'new')
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    create_property_definition_for(@project, STATUS)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_property_not_set_on_card_show(STATUS)
    assert_history_for(:card, card.number).version(1).does_not_show(:set_properties => {STATUS => 'new'})
    assert_value_not_present_for(STATUS, 'new')
    navigate_to_history_for(@project)
    assert_history_for(:card, card.number).version(1).does_not_show(:set_properties => {STATUS => 'new'})
  end

  def test_updating_name_during_card_edit_creates_card_event
    open_card_for_edit @project, @card_number
    @browser.type 'card_name', 'changing the name'
    save_card
    assert_history_event({ :changed => 'Name' }.merge({:from => @card_name, :to => 'changing the name'}))
  end

  def test_updating_description_during_card_edit_creates_card_event
    open_card_for_edit @project, @card_number
    enter_text_in_editor  "changing the description"
    save_card
    assert_history_event({ :changed => 'Description' })
  end

  def test_adding_comment_through_editing_creates_card_event
    open_card_for_edit @project, @card_number
    @browser.type 'edit-card-comment',  "adding comment"
    save_card
    assert_history_event({:comments_added => nil})
  end

 # bug 1570
  def test_clicking_add_comment_without_entering_text_does_not_create_new_card_version
    card_number = add_new_card('card without comments')
    open_card(@project, card_number)
    @browser.click('add_comment')
    assert_history_for(:card, card_number).version(2).not_present

    add_comment(BLANK)
    assert_history_for(:card, card_number).version(2).not_present

    open_card_for_edit(@project, card_number)
    @browser.type('card_comment', BLANK)
    @browser.type('pseudo-card-comment', BLANK)
    save_card
    assert_history_for(:card, card_number).version(2).not_present
  end

  # bug 595
  def test_card_transition_creates_card_event
    @project.add_member(users(:proj_admin), :project_admin)
    @project.reload
    login_as_proj_admin_user

    transition_name = 'Open defect'
    open_defect_transition = create_transition_for(@project, transition_name, :required_properties => {STATUS => 'new'}, :set_properties => {STATUS => 'open'})
    card_number = create_new_card(@project, :name => 'new defect', STATUS => 'new')
    open_card(@project, card_number)
    click_transition_link_on_card(open_defect_transition)
    navigate_to_history_for @project
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => 'new'})
    assert_history_for(:card, card_number).version(2).shows(:changed => STATUS, :from => 'new', :to => 'open')
  end

  # bug 3262
   def test_quotes_in_team_member_name_do_not_appear_as_html_entities_in_history_changes
     quote_entity = "&quot;"
     new_name_with_quotes = 'WPC "The Natural"'
     user_property = 'user property'
     setup_user_definition(user_property)
     card = create_card!(:name => 'for testing')
     open_edit_profile_for(@project_member)
     type_full_name_in_user_profile(new_name_with_quotes)
     click_save_profile_button
     open_card(@project, card)
     set_properties_on_card_show(user_property => new_name_with_quotes)
     navigate_to_history_for(@project)
     assert_history_for(:card, card.number).version(2).shows(:set_properties => {user_property => new_name_with_quotes})
     @browser.assert_text_not_present(quote_entity)
   end

  private

  def assert_history_event(event)
    navigate_to_history_for @project
    assert_history_for(:card, @card_number).version(2).shows(event)
  end

end
