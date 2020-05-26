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
class Story40ShowCardChangesInHistoryTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'story40', :users => [@project_member, users(:first)])
    setup_property_definitions :Status => ['new'], :Feature => ['email']
    login_as_project_member
  end

  def teardown
    @project.deactivate
  end

  def test_show_create_card_in_history
    fake_now(2004, 10, 15)

    navigate_to_card_list_for @project
    @project.activate
    setup_property_definitions :Status => ['new'], :Feature => ['email']

    card_number = create_new_card(@project, :name => "Add contact to address book", :status => 'new', :feature => 'email')
    set_modified_time(@project.cards.find_by_number(card_number), 1, 2004, 10, 4, 12, 0, 0)

    login_as('first')
    navigate_to_card_list_for @project
    card_number = create_new_card(@project, :name => "Edit contact in address book")
    set_modified_time(@project.cards.find_by_number(card_number), 1, 2004, 10, 12, 12, 0, 0)

    navigate_to_history_for @project, :last_30_days

    @browser.assert_element_matches 'main', /12 Oct 2004.*#2 Edit contact.*4 Oct 2004.*#1 Add contact/m

    # assert content for card #1
    @browser.assert_element_matches 'card-1-1', /#1 Add contact to address book/m
    @browser.assert_element_matches 'card-1-1', /Created .* member@email.com/m
    @browser.assert_element_matches 'card-1-1', /Feature set to email/m
    @browser.assert_element_matches 'card-1-1', /Status set to new/m
    @browser.assert_element_matches 'card-1-1', /on 04 Oct/m

    # assert content for card #2
    @browser.assert_element_does_not_match 'card-2-1', /Tagged with/   # tag brackets don't show w/o tags
    @browser.assert_element_matches 'card-2-1', /Created .* first@email.com/m
    @browser.assert_element_matches 'card-2-1', /on 12 Oct 2004/

    # 3 years later, lets assert them again, the only different should be 'xxx years ago'
    fake_now(2007, 10, 15)
    login_as_project_member
    navigate_to_history_for @project, :all_history
    # IRB.start_session(binding)
    @browser.assert_element_matches 'main', /12 Oct 2004.*#2 Edit contact.*4 Oct 2004.*#1 Add contact/m
    # assert content for card #1
    @browser.assert_element_matches 'card-1-1', /#1 Add contact to address book/m
    @browser.assert_element_matches 'card-1-1', /Created .* member@email.com/m
    @browser.assert_element_matches 'card-1-1', /Feature set to email/m
    @browser.assert_element_matches 'card-1-1', /Status set to new/m
    @browser.assert_element_matches 'card-1-1', /on 04 Oct 2004/m
  ensure
    @browser.reset_fake
  end

end
