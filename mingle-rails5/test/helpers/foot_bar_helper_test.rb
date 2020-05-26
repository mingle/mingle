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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class FootBarHelperTest < ActionView::TestCase

  def setup
    @project = create(:project)
    @member = create(:user, login: :member)
    login(@member)
    MingleConfiguration.footer_notification_url = 'https://mingle-test.com/footer-notification'
    MingleConfiguration.footer_notification_text = 'Notification message'
  end

  def test_in_project_context_should_be_false_when_at_project_is_unsaved
    @project = Project.new
    assert_false in_project_context?
  end

  def test_should_return_true_when_user_has_read_footer_notification
    @member.display_preference.update_preference(:footer_notification_digest, footer_notification_digest)

    assert has_read_footer_notification?
  end

  def test_should_return_false_when_user_has_not_read_footer_notification

    assert_false has_read_footer_notification?
  end

  def test_should_return_ajax_call_for_given_url
    actual_link = ajax_link('https://mingle-test.com/ajax-link-test', {class: 'ajax-link', id: 'ajax_link'}) { 'Click Here'}
    expected_link = '<a onclick="jQuery.ajax({ url: &quot;https://mingle-test.com/ajax-link-test&quot;, dataType: &quot;script&quot; }); return false;" href="" class="ajax-link" id="ajax_link">Click Here</a>'
    assert_equal expected_link, actual_link
  end
end
