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

module MurmursHelper

  def show_more_link(murmur, page_source)
    return unless murmur.murmur.size > 1000
    # Need to use &nbsp; to avoid word-wrapping
    span_parts = ["[", link_to_remote('Show more', {:url => {:controller => 'murmurs', :action => 'show', :id => murmur, :page_source => page_source}, :method => :get, :before => show_spinner}), "]",
                  spinner(:id => dom_id(murmur, 'spinner_for'))]
    "&nbsp;<span class='show-more'>#{span_parts.join('&nbsp;')}</span>".html_safe
  end

  def expand(murmur)
    toggle_content(murmur, 'Show more')
  end

  def collapse(murmur)
    toggle_content(murmur, 'Show less')
  end

  def toggle_content(murmur, linc_name)
    toggle_js = <<-JS
      $("murmur_content_#{murmur.id}").down('.truncated-content').toggle();
      $("murmur_content_#{murmur.id}").down('.full-content').toggle();
    JS
    ("<span class='#{linc_name.downcase.gsub(/\s/, '-')}'>[&nbsp;" + link_to_function(linc_name, toggle_js, :id => "more_or_less_#{murmur.id}") + '&nbsp;]</span>').html_safe
  end

  def truncated_murmurs_content(murmur, length=1000)
    format_as_discussion_item truncate(murmur.murmur, :length => length)
  end

  def formatted_murmurs_content(murmur)
    format_as_discussion_item murmur.murmur
  end

  def highlight_class(murmur)
    'highlighted' if @highlighted_murmur == murmur
  end
end
