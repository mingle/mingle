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

module FirebaseKeys
  module_function

  KEYS = {
    :unread_murmurs  => "unread_murmurs",
    :live_events     => "live_v2",
    :current_week    => "currentWeek",
    :murmur_email_replies => "murmur_email_replies"
  }

  def unread_murmurs_url(user, project)
    return unless MingleConfiguration.firebase_app_url
    [MingleConfiguration.firebase_app_url, unread_murmurs_key(user, project)].join("/")
  end

  def unread_murmurs_key(user, project)
    [KEYS[:unread_murmurs], MingleConfiguration.app_namespace, user.id, project.id].join("/")
  end

  def live_events_url(project, retention_label)
    return unless MingleConfiguration.firebase_app_url
    [MingleConfiguration.firebase_app_url, live_events_key(project, retention_label)].join("/")
  end

  def live_events_key(project, retention_label)
    project_label = "#{project.id}-#{project.identifier}" # ensures that "project delete and recreate with same identifier" does not receive old live data
    [KEYS[:live_events], retention_label, MingleConfiguration.app_namespace, project_label].join("/")
  end

  def murmur_email_replies(email)
    [KEYS[:murmur_email_replies], TMail::Address.parse(email).local].join("/")
  end

  def murmur_last_processed_event_details
    [KEYS[:murmur_email_replies], 'last_processed_event_details'].join('/')
  end

  def current_week_key
    KEYS[:current_week]
  end

  def current_week_url
    [MingleConfiguration.firebase_app_url, current_week_key].join("/")
  end
end
