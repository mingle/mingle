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

class UserDisplayPreference < ApplicationRecord
  MAX_RECENT_USER_COUNT = 5

  belongs_to :user
  serialize :contextual_help
  serialize :preferences

  DEFAULT_VALUES = HashWithIndifferentAccess.new({
    :sidebar_visible => true,
    :favorites_visible => false,
    :personal_favorites_visible => false,
    :recent_pages_visible => false,
    :color_legend_visible => true,
    :grid_settings => false,
    :filters_visible => true,
    :history_have_been_visible => true,
    :history_changed_to_visible => true,
    :excel_import_export_visible => false,
    :include_description => false,
    :show_murmurs_in_sidebar => true,
    :contextual_help => {},
    :show_deactived_users => true,
    :timeline_granularity => nil,
    :preferences => {}
  })

  DEFAULTS_FOR_NEW_PREFERENCES = {
    "default_card_popup_sidebar" => "murmurs",
    "clicked_keyboard_help" => false
  }

  def after_find
    self.contextual_help
    self.preferences
  end

  def self.default_for(user)
    default = DEFAULT_VALUES.merge(:user => user)
    UserDisplayPreference.new(default)
  end

  def self.for_anonymous_user(session)
    AnonymousUserDisplayPreference.new(session)
  end

  def enqueue_recent_users(user_id, user_project_count)
    return if user.blank?
    recent_users = Array(read_preference(:recent_users))
    recent_users.delete(user_id)
    recent_users.unshift(user_id)
    update_preference(:recent_users,
                      recent_users.first(MAX_RECENT_USER_COUNT * user_project_count))
  end

  def sort_by_recent_users(users)
    user_ids = Array(read_preference(:recent_users))
    users.sort_by{|user| user_ids.index(user.id) || user_ids.size}.first(MAX_RECENT_USER_COUNT)
  end

  def update_preference(name, value)
    name = name.to_s
    if self.class.column_names.include?(name)
      self.write_attribute(name, value)
    else
      self.preferences ||= {}
      self.preferences[name] = value
    end
    save!

    if user.user_display_preference.nil?
      user.user_display_preference = self
    end
  end

  def update_project_preference(project, name, value)
    update_preference(project.id , {name => value})
  end

  def read_project_preference(project, preference)
    name = project.id.to_s
    pref = true #default value
    unless (project_preferences = read_preference(name)).nil?
      return pref if project_preferences[preference].nil?
      pref = project_preferences[preference]
    end
    pref
  end

  def update_preferences(preferences)
    preferences.each do |key, value|
      update_preference(key, value)
    end unless preferences.nil?
  end

  def read_preference(name)
    name = name.to_s
    if self.class.column_names.include?(name)
      return self.read_attribute(name)
    end
    self.preferences ||= {}

    ret = self.preferences[name].nil? ? DEFAULTS_FOR_NEW_PREFERENCES[name] : self.preferences[name]
    (ret.is_a?(String) && ret.is_boolean_value?) ? ret.as_bool : ret
  end

  def update_attributes(*args, &block)
    raise "This method is unsupported. Please use update_preference instead."
  end

  alias :update_attribute :update_attributes


  # this method dose not take care of anonymous usage, use only when you are updating the preference
  # and aware is a user logined. for getting the preference value, use User#display_preference instead
  def self.current_user_prefs
    User.current.user_display_preference.nil? ? UserDisplayPreference.default_for(User.current) : User.current.user_display_preference
  end

  class AnonymousUserDisplayPreference
    def initialize(session)
      @session = SessionWrapper.new(session)
    end

    def update_preference(name, value)
      @session.merge!(name.to_s => value)
    end

    def update_preferences(preferences)
      preferences.each do |key, value|
        @session.merge!(key.to_s => value)
      end unless preferences.nil?
    end

    def enqueue_recent_users(user); end

    def read_preference(name)
      DEFAULT_VALUES.merge(@session)[name.to_s]
    end
  end

end
