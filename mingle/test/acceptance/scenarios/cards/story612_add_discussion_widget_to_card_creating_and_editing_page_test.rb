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

# Tags: story, #612, comment, cards, wiki_2
class Story612AddDiscussionWidgetToCardCreatingAndEditingPageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member
    @project = create_project(:prefix => 'story612', :users => [users(:project_member)])
    @browser.open "/projects/#{@project.identifier}"
    @name = 'card with comments'
  end

  def test_discussion_widget_on_card_creating_and_editing_page
    card_number = create_new_card(@project, :name => @name)
    click_card_on_list(card_number)
    assert_can_add_comment_when_updating_card
    assert_empty_discussion_will_be_ignored
  end

  private
  def assert_can_add_comment_when_updating_card
    comment = '  add comment when updating  '
    edit_card :discussion => comment
    @browser.assert_text_present comment.strip
  end

  def assert_empty_discussion_will_be_ignored
    edit_card :discussion => '      '
    card_number = @project.cards.find_by_name(@name).number
    @browser.assert_element_not_present "card-#{card_number}-3"
  end
end
