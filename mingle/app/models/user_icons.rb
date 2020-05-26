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

class UserIcons
  FALLBACK_ICON = "avatars/default_avatar.png"

  def initialize(view_helper)
    @view_helper = view_helper
    @local_cache = {}
  end

  def url_for(user)
    return FALLBACK_ICON if user.nil?
    if user.errors.invalid?(:icon)
      # this work around file_column "feature" that stores temp failed file in the invalid user object
      user.new_record? ? FALLBACK_ICON : valid_user_icon_url(User.find(user.id))
    else
      valid_user_icon_url(user)
    end
  end

  def default_icon(user)
    return FALLBACK_ICON unless user.name =~ /^[a-z]/i
    "avatars/#{user.name.first.downcase}.png"
  end

  private

  def valid_user_icon_url(user)
    @local_cache[icon_cache_key(user)] ||= lookup_icon(user)
  end

  def gravatar_url(user)
    params = {
      :d => @view_helper.image_url(default_icon(user)),
      :s => 48
    }
    "https://www.gravatar.com/avatar/#{user.email.md5}?#{ params.to_query }"
  end

  def lookup_icon(user)
    if user.icon
      @view_helper.icon_url_for_model(user)
    elsif user.email.present? && MingleConfiguration.saas?
      gravatar_url(user)
    else
      default_icon(user)
    end
  end

  def icon_cache_key(user)
    ["user_icon", user.icon_options[:public] ? "public" : nil, user.icon_options[:bucket_name], user.name, user.email, user.icon_path].compact.join("/")
  end
end
