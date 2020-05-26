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

require 'yaml'

class Macro
  # Macro Builder builds macro template for test
  #   Only works with Mingle macro: parameters + series
  # 
  # How to use it
  # 
  #   Create a template for you test
  #
  #     builder = Macro::Builder.parse <<-MACRO
  #        {{
  #          daily-history-chart
  #            aggregate: COUNT(*)
  #            chart-conditions: type = Card
  #            start-date: 2009 May 14
  #            end-date: 2009 May 16
  #            x-title: our date
  #            y-title: our count
  #            series: 
  #            - label: new card
  #              conditions: status = new
  #              color: Pink
  #            - label: in dev card
  #              conditions: status = "in dev"
  #              color: Green
  #            - label: testing card
  #              conditions: status = testing
  #              color: Yellow
  #        }}
  #     MACRO
  #
  #   Build macro from default template without any changes:
  #
  #     builder.build
  #
  #   Add changes to the default template and build new macro:
  #
  #     macro = builder.build(:aggregate => "SUM(Size)", :'start-date' => '2010 May 1')
  #
  #   For big changes, e.g. a new series, you could parse a string to parameters
  #
  #     new_parameters = Macro::Builder.parse_parameters <<-PARAMETERS
  #       series:
  #       - label: new story
  #         color: yellow
  #       - label: old story
  #         color: green
  #     PARAMETERS
  #     macro = builder.build(new_parameters)
  #
  class Builder
    class Parameters
      def self.load(hash)
        parameters = new
        hash.stringify_keys.each do |key, value|
          parameters.add key, value
        end
        parameters
      end

      attr_reader :order, :params

      def initialize
        @order = []
        @params = {}
      end

      def add(name, value)
        return if name.blank?

        name = name.strip if name && name.is_a?(String)
        value = value.strip if value && value.is_a?(String)
        name = name.gsub(/_/, '-')
        @order << name
        @params[name] = value
      end

      def merge(parameters)
        result = Parameters.new
        result.order.concat(@order)
        result.order.concat(parameters.order)
        result.order.uniq!
        if result.order.include?('series')
          result.order.delete('series')
          result.order << 'series'
        end
        result.params.merge!(@params.merge(parameters.params))
        result
      end

      def each(&block)
        @order.each do |name|
          yield(name, @params[name]) if @params[name]
        end
      end
    end

    def self.parse(macro)
      if /\{\{\s*([^}\s]*):?([^}]*)\}\}/ =~ macro
        new($1, parse_parameters($2))
      end
    end

    def self.parse_parameters(params)
      parameters = Parameters.new
      series = []
      series_prefix = nil
      params.split("\n").each do |param_line|
        param, value = param_line.split(":")
        next if param.nil? || param.strip.blank?
        if series_prefix
          if param =~ /^#{series_prefix}- (.*)/
            series << Parameters.new
          end
          if param =~ /^#{series_prefix}[- ] (.*)/
            series.last.add $1, value
            next
          end
        end
        if param.strip == 'series'
          series_prefix = param.split('series').first || ''
          next
        end
        series_prefix = nil
        parameters.add param, value
      end
      parameters.add 'series', series unless series.empty?
      parameters
    end

    attr_accessor :name, :parameters

    def initialize(name, parameters)
      @name = name
      @parameters = parameters
    end
    def build(parameters={})
      result = "{{\n"
      result << "  #{@name}\n"
      series = ""
      merge(parameters).each do |param, value|
        if param == 'series'
          series << build_series(value)
        else
          result << "    " << build_parameter(param, value)
        end
      end
      result << series
      result << "}}\n"
      result
    end

    def merge(parameters)
      parameters = parameters.is_a?(Hash) ? Parameters.load(parameters) : parameters
      Builder.new(@name, @parameters.merge(parameters))
    end

    def each(&block)
      @parameters.each(&block)
    end

    def build_parameter(param, value)
      "#{param}: #{value}\n"
    end

    def build_series(series)
      result = "    series:\n"
      series.each do |parameters|
        prefix = "    - "
        parameters.each do |param, value|
          result << prefix << build_parameter(param, value)
          prefix = "      "
        end
      end
      result
    end
  end
end
