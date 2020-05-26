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

module FlashMessagesHelper
  def render_flash_messages
    result = []

    result << render_flash_message(content_tag('div', flash[:notice], {:id => 'notice', :class => 'flash-content'}, false), 'success-box') if flash[:notice]

    if flash[:error]
      message = if flash[:error].is_a?(Array)
                  flash[:error].join('<br/>')
                else
                  flash[:error]
                end.html_safe
      result << render_flash_message(content_tag('div', message, {:id => 'error', :class => 'flash-content'}, false), 'error-box')
    end

    result << render_flash_message(content_tag('div', flash[:downgrade_info], {:id => 'downgrade-info', :class => 'flash-content'}, false), 'info-box') if flash[:downgrade_info]
    result << render_flash_message(content_tag('div', flash[:license_error], {:id => 'info', :class => 'flash-content'}, false), 'info-box') if flash[:license_error]
    result << render_flash_message(content_tag('div', flash[:not_found], {:id => 'not_found', :class => 'flash-content'}, false), 'error-box') if flash[:not_found]
    result << render_flash_message(content_tag('div', flash[:info], {:id => 'info', :class => 'flash-content'}, false), 'info-box') if flash[:info]
    result << render_flash_message(content_tag('div', flash[:warning], {:id => 'warning', :class => 'flash-content'}, false), 'warning-box') if flash[:warning]

    result.uniq.join('').html_safe
  end

  def render_flash_message(content, css_class, extra_properties = {})
    content_tag_string(:div, content, {:class => css_class}.merge(extra_properties), false)
  end

end
