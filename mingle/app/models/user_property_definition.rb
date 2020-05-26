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

class UserPropertyDefinition < AssociationPropertyDefinition

  class << self
    def current
      [PropertyType::UserType::CURRENT_USER, PropertyType::UserType::CURRENT_USER]
    end
  end

  def reference_class
    User
  end

  def property_type
    ThreadLocalCache.get("user_property_type") { PropertyType::UserType.new(self.project) }
  end

  def name_values
    []
  end

  def lane_values
    values.collect{|user| [user.name, user.login]}
  end

  def label_values_for_charting
    values.collect { |value| label_value_for_charting(value.login) }.smart_sort
  end

  def describe_type
    "Automatically generated from the team list"
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def enumeration_values
    self.values
  end

  def all_db_identifiers
    values.collect(&:id)
  end
  memoize :all_db_identifiers

  def values
    Project.current.user_prop_values
  end

  def light_property_values
    values.collect do |value|
      OpenStruct.new(
        :display_value => value.name,
        :db_identifier => value.id,
        :url_identifier => value.login,
        :color => nil
      )
    end
  end

  def validate_card(card)
    card_value = db_identifier(card)
    return if card_value.blank?
    unless values.any?{|user| user.id.to_s == card_value.to_s}
      begin
        if user = property_type.find_object(card_value)
          card.errors.add_to_base " #{user.name.to_s.bold} is not a project member"
        else
          card.errors.add_to_base " #{card_value.to_s.bold} is not a valid user"
        end
      rescue PropertyDefinition::InvalidValueException => e
        card.errors.add_to_base e.message
      end
    end
  end

  def self.keys_for_indexing
    @keys_for_indexing ||= [:login, :email, :name, :version_control_user_name]
  end

  def indexable_value(card)
    user = value(card)
    UserPropertyDefinition.keys_for_indexing.map { |attribute| user[attribute] } if user
  end

  def card_filter_options
    []
  end

  def to_card_query(identifier, operator)
    if is_current_user?(identifier)
      is_user_condition = CardQuery::IsCurrentUser.create(CardQuery::Column.new(name))
      return operator.class == Operator::Equals ? is_user_condition : CardQuery::Not.new(is_user_condition)
    end
    super
  end

  def sort_position(db_identifier)
    identifiers_position = ThreadLocalCache.get("user_sort_position") { Hash[all_db_identifiers.each_with_index.to_a] }
    identifiers_position[db_identifier.to_i] || -1
  end

  def support_filter?
    true
  end

  def comparison_value(view_identifier)
    return User.current.login if is_current_user?(view_identifier)
    view_identifier ? view_identifier.downcase : view_identifier
  end

  def lane_identifier(user_login)
    return ' ' if user_login.blank?
    return User.current.login if user_login == PropertyType::UserType::CURRENT_USER
    user = values.detect {|u| u.login.to_s == user_login.to_s}
    user.try(:login)
  end

  def update_card_by_obj(card, obj)
    User.current.display_preference.enqueue_recent_users(obj)
    card.send(:write_attribute, column_name, obj.nil? ? nil : obj.id)
  end

  private

  def is_current_user?(user)
    property_type.is_current_user?(user)
  end
end
