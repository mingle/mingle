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

module FootbarHelper

  def has_read_footer_notification?
    User.current.anonymous? || footer_notification_digest == User.current.display_preference(session).read_preference(:footer_notification_digest)
  end

  def footer_notification_digest
    message = [MingleConfiguration.footer_notification_url, MingleConfiguration.footer_notification_text].join("%%")
    Digest::SHA1.hexdigest(message)
  end

  def in_project_context?
    @project && !@project.new_record?
  end

  def ajax_link(url_or_url_options, html_options={}, &block)
    url = url_or_url_options.is_a?(Hash) ? url_for(url_or_url_options) : url_or_url_options
    onclick = %Q{
      jQuery.ajax({
        url: #{url.inspect},
        dataType: "script"
      }); return false;
    }.normalize_whitespace.html_safe

    concat(content_tag(:a, capture(&block), {:onclick => onclick, :href => ""}.merge(html_options)))
  end
end
