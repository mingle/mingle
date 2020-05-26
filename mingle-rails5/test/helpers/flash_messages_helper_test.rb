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

class FlashMessagesHelperTest < ActionView::TestCase

  def test_should_render_flash_messages_when_set
    flash[:error] = 'Error message'
    flash[:notice] = 'Notice message'
    flash[:downgrade_info] = 'Downgrade info'
    flash[:license_error] = 'License error'
    flash[:not_found] = 'Not found'
    flash[:info] = 'Info'
    flash[:warning] = 'Warning'

    notice = '<div class="success-box"><div id="notice" class="flash-content">Notice message</div></div>'
    error = '<div class="error-box"><div id="error" class="flash-content">Error message</div></div>'
    downgrade = '<div class="info-box"><div id="downgrade-info" class="flash-content">Downgrade info</div></div>'
    license_alert = '<div class="info-box"><div id="info" class="flash-content">License error</div></div>'
    not_found = '<div class="error-box"><div id="not_found" class="flash-content">Not found</div></div>'
    info = '<div class="info-box"><div id="info" class="flash-content">Info</div></div>'
    warning = '<div class="warning-box"><div id="warning" class="flash-content">Warning</div></div>'

    expected_message = "#{notice}#{error}#{downgrade}#{license_alert}#{not_found}#{info}#{warning}"
    assert_equal expected_message, render_flash_messages
  end

  def test_should_not_render_flash_message_when_not_set

    assert_equal '', render_flash_messages
  end
end
