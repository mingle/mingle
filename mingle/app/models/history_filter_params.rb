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

class HistoryFilterParams
  PARAM_KEYS = ['involved_filter_tags', 'acquired_filter_tags', 'involved_filter_properties', 'acquired_filter_properties', 'filter_user', 'filter_types', 'card_number', 'page_identifier']

  def initialize(params={}, period=nil)
    @params = if params.blank?
      @params = {}
    else
      params.is_a?(String) ? parse_str_params(params) : parse_hash_params(params)
    end
    @params.merge!(:period => period) if period
  end

  def to_hash
    @params
  end

  def generate_history_filter(project)
    if global?
      history_filters = {
        :involved_filter_properties => involved_filter_properties,
        :acquired_filter_properties => acquired_filter_properties,
        :involved_filter_tags => involved_filter_tags,
        :acquired_filter_tags => acquired_filter_tags,
        :filter_types => filter_types,
        :filter_user => filter_user
      }
      HistoryFilters.new(project, history_filters.merge(:period => @params[:period]))
    else
      raise HistoryFilters::InvalidError, "The resource has been deleted." unless versioned_object(project)
      History.for_versioned(project, versioned_object(project))
    end
  end

  def serialize
    return nil if @params.empty?
    if str = @params.to_query
      URI.unescape(str)
    end
  end

  def filter_user
    @params["filter_user"]
  end

  def involved_filter_tags
    filter_tags 'involved_filter_tags'
  end

  def acquired_filter_tags
    filter_tags 'acquired_filter_tags'
  end

  def involved_filter_properties
    retrieve_filter_properties 'involved_filter_properties'
  end

  def acquired_filter_properties
    retrieve_filter_properties 'acquired_filter_properties'
  end

  def filter_types
    @params['filter_types']
  end

  def local?
    card? || page?
  end

  def global?
    !local?
  end

  def card?
    @params.member?('card_number')
  end

  def page?
    @params.member?('page_identifier')
  end

  def has_global_criteria?
    include_involved_filter? || include_acquired_filter? || include_filter_types?
  end

  def include_involved_filter?
    involved_filter_properties || involved_filter_tags
  end

  def include_acquired_filter?
    acquired_filter_properties || acquired_filter_tags
  end

  def include_filter_types?
    return false if filter_types.nil?
    filter_types.size < 3
  end

  def friendly_filter_types(project)
    return [] if filter_types.blank?
    filter_types.keys.map do |key|
      if key == 'revisions' && project.has_source_repository?
        project.repository_vocabulary[key.singularize].pluralize
      else
        key
      end
    end.map(&:capitalize).sort
  end

  def description(project)
    (@params['card_number'] || @params['page_identifier']) ? versioned_object(project).short_description : nil
  end

  def event_source(project)
    return versioned_object(project).class.name.singularize.downcase unless global?
  end

  def rename_property_name(original_name, new_name)
    rename_property_name_for_filter_property('involved_filter_properties', original_name, new_name)
    rename_property_name_for_filter_property('acquired_filter_properties', original_name, new_name)
  end

  def rename_property_value(property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('involved_filter_properties', property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('acquired_filter_properties', property_definition_name, original_value, new_value)
  end

  def rename_involved_filter_property_value(property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('involved_filter_properties', property_definition_name, original_value, new_value)
  end

  def rename_acquired_filter_property_value(property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('acquired_filter_properties', property_definition_name, original_value, new_value)
  end

  def rename_tag(original_name, new_name)
    rename_tag_for_filter_tag 'involved_filter_tags', original_name, new_name
    rename_tag_for_filter_tag 'acquired_filter_tags', original_name, new_name
  end

  def change_filter_user(new_user_id)
    @params['filter_user'] = new_user_id
  end

  def filter_card(project)
    versioned_object(project)
  end
  alias :filter_page :filter_card

  private

  def rename_property_name_for_filter_property(filter_property, original_name, new_name)
    return unless @params[filter_property]
    @params[filter_property][new_name] = @params[filter_property].delete(original_name) if @params[filter_property].has_key?(original_name)
  end

  def rename_property_value_for_filter_property(filter_property, property_definition_name, original_value, new_value)
    return unless @params[filter_property]
    if @params[filter_property][property_definition_name] == original_value
      @params[filter_property][property_definition_name] = new_value
    end
  end

  def rename_tag_for_filter_tag(tag_filter, original_name, new_name)
    return unless filter = @params[tag_filter]
    tags = tags_serialized?(filter) ? deserialize_tags(filter) : filter
    if index = tags.index(original_name)
      tags[index] = new_name
    end
    @params[tag_filter] = tags
  end

  def tags_serialized?(filter)
    filter.is_a?(String)
  end

  def deserialize_tags(filter)
    filter.split(',')
  end

  def retrieve_filter_properties(filter_property)
    return unless @params[filter_property]
    sanitized_values = @params[filter_property].collect do |key, value|
      [key, (value || '')]
    end
    Hash[*sanitized_values.flatten]
  end

  def versioned_object(project)
    if @params['card_number']
      project.with_active_project { project.cards.find_by_number(@params['card_number']) }
    elsif @params['page_identifier']
      project.pages.find_by_identifier(@params['page_identifier'])
    else
      nil
    end
  end
  memoize :versioned_object

  def filter_tags(key)
    tags = Tag.parse(@params[key])
    tags.reject! { |tag| tag.blank? }
    tags = nil if tags.empty?
    tags
  end

  def parse_str_params(params)
    parse_hash_params(ActionController::Request.parse_query_parameters(params))
  end

  def parse_hash_params(params)
    params.reject! { |key, value| value.blank? }
    PARAM_KEYS.inject({}) do |result, key|
      value = params[key] || params[key.to_sym]
      value.reject_all!(PropertyValue::IGNORED_IDENTIFIER) if value.respond_to?(:reject_all!)
      result[key] = value unless value.blank?
      result
    end
  end
end
