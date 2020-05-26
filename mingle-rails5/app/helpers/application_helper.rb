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

module ApplicationHelper
  include HelpDocHelper
  include JavascriptBuffer
  include Rails2CompatibleAssetsTagHelper
  include FlashMessagesHelper
  def clear_float
    "<div class='clear-both'><!-- Clear floats --></div>".html_safe
  end

  def info_box(html_options={}, &block)
    styled_box(html_options.concatenative_merge(:class => 'info-box'), &block)
  end

  def styled_box(html_options={}, &block)
    inner_html = capture(&block)
    #todo need clean
    inner_html_contents = inner_html.to_s.gsub(/<a[^>]*>help<\/a>/i, '').gsub(/<a[^>]*>show help<\/a>/i, '').gsub(/<div class='clear-both'><\!-- Clear floats --><\/div>/, '').gsub(/<\/?span[^>]*>/, '').gsub(/<img[^>]*class="spinner"[^>]*>/, '')
    return if inner_html_contents.strip.blank?

    concat(content_tag_string(:div, inner_html, html_options))
  end

  def header_pill_class(tab_name, current_tab_name)
    if tab_name == current_tab_name
      "header-menu-pill selected #{tab_name}"
    else
      "header-menu-pill #{tab_name}"
    end
  end

  def error_box(html_options={}, &block)
    styled_box(html_options.concatenative_merge(:class => 'error-box'), &block)
  end

  def action_bar(html_options={}, &block)
    html_options = {:class => 'action-bar'}.merge(html_options)
    styled_box(html_options, &block)
  end

  def landing_page
    enterprise_license = CurrentLicense.status.enterprise? rescue false
    return projects_path if User.current.anonymous?
    enterprise_license ? programs_path : projects_path
  end

  def page_title
    return @title + " - " + ice_resource_type if @title
    @title = if ["index", "list", 'grid', 'tree'].include?(controller.action_name)
               "#{controller.controller_name.pluralize.humanize}"
             else
               "#{controller.action_name.humanize.split(' ').collect{|word| word.capitalize}.join(' ')} #{controller.controller_name.singularize.capitalize}"
             end

    @title = (@project && !@project.new_record?) ? "#{@project.name} #{@title}" : @title
    "#{@title} - Mingle"
  end

  def show_buy_button?
    MingleConfiguration.new_buy_process? &&
        !CurrentLicense.status.paid? &&
        !CurrentLicense.status.buying?
  end

  def user_notification_key
    [
        MingleConfiguration.user_notification_heading,
        MingleConfiguration.user_notification_avatar,
        MingleConfiguration.user_notification_body,
        MingleConfiguration.user_notification_url
    ]
  end

  def user_notification?
    # url is optional
    notification_configured = [MingleConfiguration.user_notification_heading, MingleConfiguration.user_notification_body].all? {|el| el.present?}
    notification_configured && !User.current.has_read_notification?(user_notification_key.join(":"))
  end

  def users_data(users)
    users.map do |user|
      {
          :id => user.id.to_s,
          :login => user.login,
          :name => user.name,
          :icon => "", #chagne it to user_icon_url(user) once UserIcon class is moved to rails 5
          :color => 'BLACK' #User Color.for(user.name) when Color class is moved to rails 5
      }
    end
  end

  def copyright_text
    "Copyright 2007-#{Time.now.year} ThoughtWorks, Inc."
  end

  def image_url(path)
    full_path = image_path(path)
    prepend_protocol_with_host_and_port(full_path)
  end

  def prepend_protocol_with_host_and_port(url)
    return url if url =~ /^https?:\/\//
    File.join(MingleConfiguration.secure_prefered_site_url, url)
  end

  def supports_password_recovery?
    Authenticator.supports_password_recovery?
  end
end
