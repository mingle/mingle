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

module UserIconsHelper
  FALLBACK_ICON = 'avatars/default_avatar.png'

  def url_for_user_icon(user)
    return FALLBACK_ICON if user.nil?
    if user.invalid?(:icon)
      # this work around file_column "feature" that stores temp failed file in the invalid user object
      user.new_record? ? FALLBACK_ICON : valid_user_icon_url(User.find(user.id))
    else
      valid_user_icon_url(user)
    end
  end

  def image_tag_for_user_icon(user, options = {})
    alt_text = if user.nil?
                 ''
               elsif user.icon.blank?
                 user.login
               else
                 File.basename(user.icon)
               end
    icon_url = user_icon_url(user)

    unless user.nil?
      options[:style] = merge_style(options[:style] || "", user.icon_image_options(icon_url)[:style] || "")
    end
    image_tag(icon_url, {:alt => alt_text}.merge(options))
  end


  private
  def user_icon_url(user = nil)
    image_url(url_for_user_icon(user))
  end

  def icon_url_for_model(model)
    url = URI.parse(url_for_file_column(model, "icon").to_s)

    if MingleConfiguration.public_icons?
      unless MingleConfiguration.asset_host.blank?
        asset_host = URI.parse(MingleConfiguration.asset_host)
        url.host = asset_host.host
        url.port = asset_host.port
        url.scheme = asset_host.scheme
      end
    end
    url.to_s
  end

  def default_icon(user)
    return FALLBACK_ICON unless user.name =~ /^[a-z]/i
    "avatars/#{user.name.first.downcase}.png"
  end


  def valid_user_icon_url(user)
    if user.icon
      icon_url_for_model(user)
    elsif user.email.present? && MingleConfiguration.saas?
      gravatar_url(user)
    else
      default_icon(user)
    end
  end

  def gravatar_url(user)
    params = {
      :d => image_url(default_icon(user)),
      :s => 48
    }
    "https://www.gravatar.com/avatar/#{user.email.md5}?#{ params.to_query }"
  end


  def merge_style(*style_attrs)
    style_attrs.join('; ')
  end
end
