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


class PageDeletionEventTest < ActiveSupport::TestCase

  def setup
    @project = project_without_cards
    @project.activate
    login_as_admin
  end

  def test_should_generate_page_deletion_event_when_page_is_deleted
    page = @project.pages.create!(:name => 'foo', :content => 'whatevs')
    page.destroy
    assert_equal "Page foo", last_version(page).event.origin_description
    assert_equal "deleted", last_version(page).event.action_description
  end

  def test_generate_page_deletion_changes
    page = @project.pages.create!(:name => 'foo', :content => 'whatevs')
    page.destroy

    event = last_version(page).event
    event.send :generate_changes

    assert_equal ["page-deletion"], event.changes.reload.collect(&:feed_category)
    assert_not_include "old_value", event.changes.collect(&:to_xml).join
    assert event.history_generated?
  end

  def last_version(page)
    page.versions.find(:first, :order => 'version DESC')
  end
end
