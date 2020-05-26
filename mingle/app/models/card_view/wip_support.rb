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

module CardView
  module WipSupport
    def make_aggregation_params(lane_name, limit_config)
      agg_type = limit_config[:type].downcase == 'count' ? nil : limit_config[:type]
      agg_prop = limit_config[:property] || 'number'
      {aggregate_type: {column: agg_type}, aggregate_property: {column: agg_prop}}
    end

    def sanitize_wip_limits(wip_limits)
      return nil unless wip_limits
      wip_limits.reject { |_, wip_limit|
        wip_limit[:limit].nil? || wip_limit[:limit].to_s.empty?
      }.each { |_, config|
        config.delete(:current_value)
      }
    end

    module_function :sanitize_wip_limits, :make_aggregation_params
  end
end
