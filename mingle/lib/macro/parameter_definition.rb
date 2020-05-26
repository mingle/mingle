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


class Macro
  class InvalidDateParameterValueError < StandardError; end

  class ParameterDefinition

    attr_reader :name

    def initialize(name, options = {})
      @name, @options  = name, options
    end

    def parameter_name
      @name.to_s.tr('_', '-')
    end

    def example
      @options[:example]
    end

    def has_example?
      @options.has_key?(:example)
    end

    def required?
      !!evaluated_value(@options[:required])
    end

    def input_editor_type
      @options[:type] || SimpleParameterInput::DEFAULT
    end

    def input_type
      input_editor_type.input_type
    end

    def missing_required?(parameters)
      required? && parameters[parameter_name].blank?
    end

    def easy_charts?
      @options[:easy_charts] == true
    end

    def list_of
      @options[:list_of]
    end

    def param_def_type
      'single_input'
    end

    def help_text
      @options[:help_text]
    end

    def resolve_value(parameters, content_provider=nil, chart=nil)
      if @options[:list_of]
        parameters['series'].collect do |series_level_params|
          @options[:list_of].new(chart, series_level_params, chart.card_query_options)
        end
      elsif parameters[parameter_name].nil?
        default
      else
        stripped_value = strip_value(parameters[parameter_name])
        value = validate_value(stripped_value)
        translated_value = translate_plv_value_or_property_name(value, content_provider, chart)
        use_default_value_if_blank(translated_value)
      end
    end

    def default
      unless required?
        evaluated_value(@options[:default])
      end
    end

    def evaluated_value(value)
      Proc === value ? value.call : value
    end

    def to_hash
      result = { :name => parameter_name.to_s, :required => required?, :default => default, :initially_shown => initially_shown?, :initial_value => initial_value , :allowed_values => allowed_values, multiple_values_allowed: multi_valued?, input_type: input_type}
      result[:list_of] = @options[:list_of].parameter_definitions.map(&:to_hash) if @options[:list_of]
      result.stringify_keys!
    end

    def initially_shown?
      !!(required? || @options[:initially_shown])
    end

    def initial_value
      val = @options[:initial_value]
      eval_if_block(val)
    end

    def this_card_property_display_value_resolved
      @this_card_property_value_resolved.display_value if @this_card_property_value_resolved
    end

    def display_name
      @options[:display_name] || @name.to_s.humanize
    end

    def allowed_values
      val = @options[:values] || []
      eval_if_block(val)
    end

    private

    def validate_value(val)
      return val unless allowed_values && !allowed_values.empty?
      compared_value = val.is_a?(String) ? val.downcase : val
      allowed_values.find {|v| v == compared_value }
    end

    def eval_if_block(val)
      (val.is_a? Proc) ? val.call : val
    end

    def multi_valued?
      input_editor_type.partial.include? 'multi'
    end

    def use_default_value_if_blank(value)
      return default if value.nil?
      (String === value && value.blank?) ? default : value
    end

    def strip_value(value)
      value.respond_to?(:to_str) ? value.to_str.strip : value
    end

    def translate_plv_value_or_property_name(value, content_provider, chart)
      value =~ /PROPERTY (\(.*\))/ ? $1 : resolve_computable_value(value, content_provider, chart)
    end

    def resolve_computable_value(value, content_provider, chart)
      return value unless @options[:computable]

      @options[:compatible_types] ||= [:string, :numeric, :user, :date, :card]

      @this_card_property_value_resolved = get_property_value(value, content_provider, chart)
      value_holder = @this_card_property_value_resolved || get_plv(value)

      if value_holder
        validate_computable_types(value, value_holder)
        return if value_holder.not_set?
        return value_holder.association_type? ? value_holder.display_value : YAML::load(value_holder.display_value)
      end
      value
    end

    def get_property_value(value, content_provider, chart)
      if value =~ /^THIS CARD\.(.*)/i
        if availability = content_provider.try(:this_card_condition_availability)
          availability.validate value, chart
        end

        property_def = content_provider.project.find_property_definition($1.unquote.unescape_quote, :with_hidden => true)
        return PropertyValue.not_set_instance(property_def)  unless ThisCardConditionAvailability::Now === availability
        content_provider.property_value(property_def)
      end
    end

    def get_plv(value)
      if plv_name = ProjectVariable.extract_plv_name(value)
        ProjectVariable.find_plv_in_current_project(plv_name)
      end
    end

    def validate_computable_types(value, value_holder)
      unless PropertyType.compatible?(value_holder.property_type, @options[:compatible_types])
        raise "Data types for parameter #{parameter_name.bold} and #{value.bold} do not match. Please enter the valid data type for #{parameter_name.bold}."
      end
    end
  end

  class AggregateParameterDefinition
    def initialize(text, options={})
      @text = text
      @options = options
    end

    def help_text
      @text
    end

    def param_defs
      @options.values
    end

    def [](name)
      @options[name]
    end
  end

  class PairParameterDefinition < ParameterDefinition
    def initialize(options={})
      @options = options
      @name = options[:name] || ''
    end

    def param_defs
      @options[:param_defs] || []
    end

    def param_def_type
      'pair_parameters'
    end

    def connecting_text
      @options[:connecting_text] || ''
    end
  end

  class GroupedParameterDefinition < ParameterDefinition
    def initialize(options={})
      @options = options
      @name = options[:name] || ''
    end

    def param_defs
      @options[:param_defs] || []
    end

    def param_def_type
      'grouped_parameters'
    end
  end
end
