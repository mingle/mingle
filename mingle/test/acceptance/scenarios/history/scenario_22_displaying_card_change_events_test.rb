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

# Tags: scenario, card-page-history
class Scenario22DisplayingCardChangeEventsTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  MEMBER_USER_EMAIL = 'member@email.com'
  ADMIN_USER_EMAIL = 'admin@email.com'
  FIRST_USER_LOGIN = 'first'
  FIRST_USER_EMAIL = 'first@email.com'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_22', :users => [users(:project_member), users(:admin), users(:first)])
    setup_property_definitions :Status => ['new', 'open']

    login_as_project_member
    @browser.open "/projects/#{@project.identifier}"
    @card_name = 'create new email'
    @card_number = create_new_card(@project, :name => @card_name, :status => 'new')
  end

  def test_changing_value_of_grouped_tag_shows_correct_change_event
    open_card @project, @card_number
    edit_card :status => 'open'
    navigate_to_history_for @project
    assert_history_for(:card, @card_number).version(2).shows(:changed => 'Status', :from => 'new', :to => 'open')
  end

  def test_card_change_events_shows_correct_user
    assert_card_creation_history
    logout
    login_as_admin_user
    open_card @project, @card_number
    edit_card :description => 'adding some text'
    assert_card_creation_history
    assert_card_edit_history
    logout
    login_as(FIRST_USER_LOGIN)
    assert_card_creation_history
    assert_card_edit_history
  end

  private
  def assert_card_creation_history
    navigate_to_history_for @project
    assert_history_for(:card, @card_number).version(1).shows(:created_by => MEMBER_USER_EMAIL, :set_properties => {'Status' => 'new'})
  end

  def assert_card_edit_history
    navigate_to_history_for @project
    assert_history_for(:card, @card_number).version(2).shows(:modified_by => ADMIN_USER_EMAIL)
  end
end
