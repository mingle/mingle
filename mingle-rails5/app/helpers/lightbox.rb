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

class Lightbox < SimpleDelegator
  class << self
    def with_close_link(the_view, link_name, link_function, link_options={})
      with_close_link_and_close_button(the_view, link_name, link_function, link_options).no_close_button!
    end

    def with_close_link_and_close_button(the_view, link_name, link_function, link_options={})
      link_function = 'InputingContexts.pop()' if link_function.blank?
      if link_options[:onclick]
        link_options[:onclick] = "#{link_function};#{link_options[:onclick]}"
      else
        link_options[:onclick] = link_function
      end
      self.new(the_view, link_options.merge(:link_name => link_name))
    end
  end

  def initialize(the_view, close_link_options)
    @close_link_name = close_link_options.delete(:link_name)
    @close_link_options = close_link_options
    __setobj__(the_view)
  end

  def no_close_button!
    @no_close_button = true
    self
  end

  # header text should not be considered html safe. Having be so created an XSS
  # vulnerability. See [san_francisco_team_board/#688] for details
  def header(header_text, spinner=nil)
    raw_concat <<-HTML
      <div class='lightbox_header'>
        <h2>#{CGI.escapeHTML(header_text)}#{spinner}</h2>
        #{close_link}
      </div>
    HTML
  end


  def body(body_id=nil, html_class=nil, attrs={}, &block)
    content_class = html_class.blank? ? "lightbox_content" : ["lightbox_content", html_class.strip].join(" ")

    html = content_tag(:div, :id => body_id, :class => "lightbox_content_wrapper") do
      content_tag(:div, attrs.merge(:class => content_class)) do
        capture(&block)
      end
    end

    raw_concat html
  end

  def complete_action(action_bar_id=nil, &block)
    return if @no_close_button
    complete_action_contents = block_given? ? capture(&block) : ''
    raw_concat <<-HTML
      <div class="lightbox_actions">
        <div class="action-bar" id='#{action_bar_id.blank? ? "lightbox_actions" : action_bar_id}'>
          #{complete_action_contents}
          #{close_link_as_button(&block)}
        </div>
      </div>
    HTML
  end

  private
  def link_to_close_lightbox(link_name="Close", html_options={})
    html_options = html_options.dup
    link_to link_name, "#{html_options.delete(:onclick)}", {:class => 'popup-close'}.merge(html_options)
  end

  def close_link
    return @close_link_options if @close_link_options.is_a?(String)
    link_to_close_lightbox(@close_link_name, @close_link_options)
  end

  def close_link_as_button(&block)
    return @close_link_options if @close_link_options.is_a?(String)
    button_html_options = @close_link_options.merge(:class => "close-popup link_as_button #{block_given? ? '' : 'primary'}")
    link_to_close_lightbox(@close_link_name, button_html_options.merge(:id => 'dismiss_lightbox_button'))
  end

  def raw_concat(contents)
    concat(contents.html_safe)
  end
end
