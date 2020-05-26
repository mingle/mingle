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

class HistorySubscription < ActiveRecord::Base
  NIL_PARAM_HASH = 'b4f669ea56a0f25009c1acbc209b3398'

  belongs_to :project
  belongs_to :user

  serialize :filter_params
  before_save :hash_filter_params

  has_many :user_filter_usages, :as => :filterable, :dependent => :destroy

  class << self
    def update_last_max_revision_id_to(revision_id, project_id)
      connection.execute %{
        UPDATE #{table_name}
        SET last_max_revision_id = #{revision_id}
        WHERE project_id = #{project_id}
      }
    end

    def param_hash(params)
      serialized_params = HistoryFilterParams.new(params).serialize
      serialized_params.nil? ? NIL_PARAM_HASH : serialized_params.to_yaml.md5
    end

    def user_ids
      ThreadLocalCache.get("HistorySubscription.user_ids") do
        connection.select_values("SELECT DISTINCT user_id FROM #{quoted_table_name}").compact.map(&:to_i)
      end
    end
  end

  delegate :global?, :card?, :page?, :involved_filter_tags, :acquired_filter_tags, :to => :to_history_filter_params

  def cached_project
    ThreadLocalCache.get_assn(self, :project)
  end

  def fresh_events(options = {})
    history_filters = to_history_filter_params.generate_history_filter(self.cached_project)
    fresh_events = history_filters.fresh_events(last_max_ids)
    if (options[:skip_revision_notification])
      fresh_events = fresh_events.reject{|fe| fe.event_type == :revision}
    end
    fresh_events
  end

  def is_page_subscription?(page)
    self.hashed_filter_params == HistorySubscription.param_hash(:page_identifier => page.identifier) && self.project == page.project
  end

  def to_history_filter_params
    @history_filter_params ||= HistoryFilterParams.new(self.filter_params)
  end

  def filter_property_names
    names = []
    names << to_history_filter_params.involved_filter_properties.keys if to_history_filter_params.involved_filter_properties
    names << to_history_filter_params.acquired_filter_properties.keys if to_history_filter_params.acquired_filter_properties
    names.flatten.uniq
  end

  def subject
    "You have subscribed to #{description}"
  end

  def description
    if to_history_filter_params.global?
      "#{self.cached_project.name} history"
    else
      to_history_filter_params.description(self.cached_project)
    end
  end

  def rename_property(original_name, new_name)
    with_filter_params_update do |params|
      params.rename_property_name(original_name, new_name)
    end
  end

  def rename_property_value(property_definition_name, original_value, new_value)
    with_filter_params_update do |params|
      params.rename_property_value property_definition_name, original_value, new_value
    end
  end

  def rename_involved_filter_property_value(property_definition_name, original_value, new_value)
    with_filter_params_update do |params|
      params.rename_involved_filter_property_value property_definition_name, original_value, new_value
    end
  end

  def rename_acquired_filter_property_value(property_definition_name, original_value, new_value)
    with_filter_params_update do |params|
      params.rename_acquired_filter_property_value property_definition_name, original_value, new_value
    end
  end

  def rename_tag(original_name, new_name)
    with_filter_params_update { |params| params.rename_tag(original_name, new_name) }
  end

  def update_last_notification(event)
    connection.execute("UPDATE history_subscriptions SET last_max_#{event.event_type.to_s.downcase}_id = #{event.id} WHERE id = #{id}")
  end

  def has_filter_user
    !to_history_filter_params.filter_user.blank?
  end

  def filter_user_id
    to_history_filter_params.filter_user
  end

  def change_filter_user(new_user_id)
    with_filter_params_update do |params|
      params.change_filter_user(new_user_id)
    end
  end

  def filter_types
    return [] if to_history_filter_params.filter_types.blank?
    to_history_filter_params.filter_types.keys.sort
  end

  def filter_types_display_names
    to_history_filter_params.friendly_filter_types(self.cached_project)
  end

  def filter_user
    user_id = HistoryFilterParams.new(self.filter_params).filter_user
    User.find_by_id user_id
  end

  def involved_filter_properties
    param_filter_to_array to_history_filter_params.involved_filter_properties
  end

  def acquired_filter_properties
    param_filter_to_array to_history_filter_params.acquired_filter_properties
  end

  def filter_card
    to_history_filter_params.filter_card(self.cached_project)
  end

  def filter_page
    to_history_filter_params.filter_page(self.cached_project)
  end

  def processing_error?
    !error_message.blank?
  end

  def uses_card_type?(card_type)
    involved_filter_properties.uses_card_type?(card_type) || acquired_filter_properties.uses_card_type?(card_type)
  end

  def uses_user?(user)
    filter_user_id.to_s == user.id.to_s || involved_filter_properties.uses_user?(self.cached_project, user) || acquired_filter_properties.uses_user?(self.cached_project, user)
  end

  def filters
    HistorySubscriptionFilters.new(self.cached_project, filter_params)
  end

  class HistorySubscriptionFilters

    def initialize(project, filter_params)
      @project = project
      history_filter_params = HistoryFilterParams.new(filter_params)
      involved_filters = history_filter_params.involved_filter_properties || {}
      acquired_filters = history_filter_params.acquired_filter_properties || {}
      @consolidated_filter_params = involved_filters.merge(acquired_filters) do |key, involved_value, acquired_value|
        [involved_value, acquired_value]
      end
    end

    def each(&block)
      @consolidated_filter_params.each do |property_definition_name, filter_values|
        property_definition = @project.find_property_definition_or_nil(property_definition_name)
        filter_values = [filter_values].flatten
        filter_values.each do |filter_value|
          filter = OpenStruct.new
          filter.property_definition = property_definition
          filter.value = filter_value
          yield filter
        end
      end
    end

  end

  private

  def param_filter_to_array(filter)
    (filter.to_a.smart_sort_by { |key, value| key }).tap do |result|
      result.class_eval do
        include HistoryFilterParamsDetector
      end
    end
  end

  module HistoryFilterParamsDetector
    def uses_card_type?(card_type)
      self.uses_property_and_value? card_type.property_definition, card_type.name
    end

    def uses_property?(target_property)
      any? { |property, value| target_property.name?(property) }
    end

    def uses_card_type_and_property?(card_type, target_property)
      uses_card_type?(card_type) && uses_property?(target_property)
    end

    def uses_property_and_value?(target_property, target_value)
      any? { |property, value| target_property.name?(property) && target_value.ignore_case_equal?(value) }
    end

    def uses_user?(project, user)
      user_property_definition_names = project.user_property_definitions_with_hidden.map(&:name)
      any? { |property, value| user_property_definition_names.include?(property) && value.to_s == user.id.to_s }
    end
  end

  def last_max_ids
    { :card_version => self.last_max_card_version_id,
      :page_version => self.last_max_page_version_id,
      :revision => self.last_max_revision_id }
  end

  def with_filter_params_update
    params = to_history_filter_params
    yield(params)
    self.filter_params = params.serialize
  end

  def hash_filter_params
    self.hashed_filter_params = HistorySubscription.param_hash(self.filter_params)
  end

end
