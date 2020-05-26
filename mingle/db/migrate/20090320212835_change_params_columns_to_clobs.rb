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

class M20090320212835HistorySubscription < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}history_subscriptions"
end

class M20090320212835HistoryFilterParams
  PARAM_KEYS = ['involved_filter_tags', 'acquired_filter_tags', 'involved_filter_properties', 'acquired_filter_properties', 'filter_user', 'filter_types', 'card_number', 'page_identifier'] unless defined?(PARAM_KEYS)

  def initialize(params={}, period=nil)
    @params = if params.blank?
      @params = {}
    else
      params.is_a?(String) ? parse_str_params(params) : parse_hash_params(params)
    end
    @params.merge!(:period => period) if period
  end

  def serialize
    if str = ActionController::Routing::Route.new.build_query_string(@params)[1..-1]
      URI.unescape(str)
    end
  end

  private

  def parse_str_params(params)
    parse_hash_params(ActionController::Request.parse_query_parameters(params))
  end

  def parse_hash_params(params)
    params.reject! { |key, value| value.blank? }
    PARAM_KEYS.inject({}) do |result, key|
      value = params[key] || params[key.to_sym]
      value.reject_all!(':ignore') if value.respond_to?(:reject_all!)
      result[key] = value unless value.blank?
      result
    end
  end
end

class ChangeParamsColumnsToClobs < ActiveRecord::Migration
  def self.up
    change_column :card_list_views, :params, :text
    add_column :history_subscriptions, :hashed_filter_params, :string
    HistorySubscription.reset_column_information
    M20090320212835HistorySubscription.find(:all).each do |history_subscription|
      history_subscription.hashed_filter_params = M20090320212835HistoryFilterParams.new(history_subscription.filter_params).serialize.to_yaml.md5
      history_subscription.save
    end
  end

  def self.down
  end
end
