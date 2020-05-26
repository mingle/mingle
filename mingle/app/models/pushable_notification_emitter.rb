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

module PushableNotificationEmitter
  def emit_payload
    data = {
      :id => id,
      :action => [source_type, action_description].join("::"),
      :author => serialize_user(author),
      :changes => {},
      :origin => snapshot.to_json,
      :schema_version => 5,
      :created_at => created_at
    }

    changes.sort_by(&:feed_category).each do |c|
      data[:changes][c.feed_category] ||= []
      data[:changes][c.feed_category] << [c.field, c.old_value, c.new_value]
    end

    data
  end

  module_function

  # output JSON string to flatten the value to push to FireBase
  def serialize_user(user)
    user_icons = UserIcons.new(TeamController.helpers)
    icon_url = TeamController.helpers.image_path(user_icons.url_for(user))
    [user.id, icon_url, Color.for(user.name), user.login, user.name].to_json
  end
end
