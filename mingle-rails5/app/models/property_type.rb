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

module PropertyType


  # for user type, db_identifier is user id, url_identifier is user login, display_value is user name
  class Base; end

  class UserType < Base
    # include ObjectComparator
    CURRENT_USER = '(current user)'
    # ALIAS_CURRENT_USER = 'current user'
    #
    # def initialize(project)
    #   @team_members = project.users
    # end
    #
    # def reserved_identifiers
    #   [CURRENT_USER]
    # end
    #
    # def db_to_url_identifier(db_identifier)
    #   return CURRENT_USER if is_current_user?(db_identifier)
    #   if user = find_user_by_id(db_identifier)
    #     user.login
    #   end
    # end
    # memoize :db_to_url_identifier
    #
    # def url_to_db_identifier(url_identifier)
    #   return User.current.id if is_current_user?(url_identifier)
    #
    #   user = find_user_by_login_or_id(url_identifier)
    #   user.id if user
    # end
    #
    # def valid_url?(url_identifier)
    #   return true if url_identifier.blank?
    #   url_to_db_identifier(url_identifier)
    # end
    #
    # def display_value_for_db_identifier(db_identifier)
    #   return CURRENT_USER if is_current_user?(db_identifier)
    #   if user = find_object(db_identifier)
    #     user.name
    #   end
    # end
    #
    # def format_value_for_card_query(value, cast_numeric_columns=false)
    #   if user = find_user_by_login_or_id(value)
    #     user.name_and_login
    #   end
    # end
    #
    # def sort_value(property_value)
    #   display_value_for_db_identifier(property_value.db_identifier)
    # end
    #
    # def is_current_user?(db_identifier)
    #   return false unless db_identifier.respond_to?(:downcase)
    #   [CURRENT_USER, ALIAS_CURRENT_USER].include?(db_identifier.downcase)
    # end
    #
    # def object_to_db_identifier(obj)
    #   return nil unless obj
    #   obj.id.to_s
    # end
    #
    # def parse_import_value(value)
    #   if mingle_user = User.find_by_login(value)
    #     mingle_user.id.to_s
    #   else
    #     raise CardImport.invalid_user_error
    #   end
    # end
    #
    # def find_object(db_identifier)
    #   return User.current if db_identifier && is_current_user?(db_identifier.to_s)
    #   find_user_by_id(db_identifier)
    # end
    #
    # def to_sym
    #   :user
    # end
    #
    # private
    # def find_user_by_id(db_identifier)
    #   return nil unless db_identifier
    #
    #   if user = cached_users[db_identifier.to_i]
    #     return user
    #   elsif user = User.find_by_id(db_identifier.to_i)
    #     cached_users[user.id] = user
    #     return user
    #   else
    #     raise PropertyDefinition::InvalidValueException.new(" #{db_identifier.to_s.bold} is not a valid user")
    #   end
    # end
    #
    # memoize :find_user_by_id
    #
    # def find_user_by_login_or_id(login_or_id)
    #   return nil unless login_or_id
    #
    #   if user = cached_users[login_or_id]
    #     return user
    #   end
    #
    #   if user = User.find_by_login(login_or_id)
    #     cached_users[user.id] = user
    #     cached_users[user.login] = user
    #     return user
    #   end
    #
    #   find_user_by_id(login_or_id)
    # end
    #
    # def cached_users
    #   @__cached_users ||= Hash[@team_members.to_a.map{|m| [[m.id, m], [m.login, m]]}.flatten(1)]
    # end
  end
end
