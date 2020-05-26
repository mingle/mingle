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
class Story616ShowDiscussionAndHistoryInTheSidebarTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story616', :users => [users(:project_member)])
    setup_property_definitions :old_type => ['story'], :status => ['open']
    login_as_project_member
  end

  def test_show_card_copy_events_in_sidebar
    original_card = @project.cards.create! :name => "original card", :card_type_name => @project.card_types.first.name

    other_project = create_project(:prefix => "copy_target", :users => [users(:project_member)], :skip_activation => true) do |project|
      setup_property_definitions :old_type => ["story"], :status => ["open"]
    end

    new_card = nil
    @project.with_active_project do |project|
      copier = original_card.copier(other_project)
      new_card = copier.copy_to_target_project
    end

    navigate_to_card(@project.identifier, original_card)
    load_card_history

    @browser.wait_for_element_visible("current-history")
    @browser.assert_element_present("css=.card-copy-event")
    @browser.assert_text("css=.card-copy-event .event-title", "Copy created to #{other_project.name} as card number #{new_card.number}")

    navigate_to_card(other_project.identifier, new_card)
    load_card_history

    @browser.wait_for_element_visible("current-history")
    @browser.assert_element_present("css=.card-copy-event")
    @browser.assert_text("css=.card-copy-event .event-title", "Created from original card number #{original_card.number} in #{@project.name}")
  end

  def test_show_events_and_discussion_in_the_sidebar
    @browser.open("/projects/#{@project.identifier}")
    create_new_card(@project, :name => 'Sidebar card')
    navigate_to_card(@project.identifier, 'Sidebar card')

    @browser.assert_visible('history-link')
    @browser.assert_not_visible('current-history')
    @browser.assert_visible('current-discussion')
    @browser.assert_not_visible('discussion-link')

    @browser.type('card_comment', 'here is a comment for you')
    @browser.with_ajax_wait do
      @browser.click('add_comment')
    end

    @browser.assert_visible('current-discussion')
    @browser.assert_text('add_comment', '')
    @browser.assert_text_present('here is a comment for you')

    load_card_history
    @browser.wait_for_element_visible('current-history')
    @browser.assert_element_present('link-to-card-1-1')
    @browser.assert_text_present('Version 2')

    set_properties_on_card_show 'old_type' => 'story', 'status' => 'open'

    @browser.assert_visible('current-history')
    @browser.assert_visible('link-to-card-1-3')
    @browser.assert_text_present('Version 4')
  end

end
