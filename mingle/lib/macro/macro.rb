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

require File.join(Rails.root, 'lib', 'macro', 'parameter_definition')

class Macro

  class ProcessingError < StandardError
    attr_reader :context_project

    def initialize(message, context_project=nil)
      @context_project = context_project
      super(message)
    end
  end

  module ParameterSupport
    def self.included(includer)
      includer.extend(ClassMethods)
      includer.send :include, InstanceMethods
    end

    module ClassMethods
      def parameter(name, options={})
        write_inheritable_array(:parameter_definitions, [ParameterDefinition.new(name, options)])
        if (name.to_s == 'project')
          self.class_eval do
            attr_writer name
          end
        else
          self.class_eval do
            attr_accessor name

            define_method("#{name}?") do
              self.send(name)
            end
          end
        end
      end

      def parameter_definitions
        (self.read_inheritable_attribute(:parameter_definitions) || [])
      end

      def project_identifier_from_parameters(parameters, content_provider = nil)
        ParameterDefinition.new('project', :computable => true, :compatible_types => [:string]).resolve_value(parameters, content_provider)
      end
    end

    module InstanceMethods
      def initialize_parameters_from(chart, parameters, context)
        raise 'Illegal parameter' unless (Hash === parameters)
        missing_required_parameters = self.class.parameter_definitions.select { |parameter_definition| parameter_definition.missing_required?(parameters) }

        if missing_required_parameters.size == 1
          raise MissingParameterValueException, "Parameter #{missing_required_parameters.first.parameter_name.bold} is required" if missing_required_parameters.any?
        elsif missing_required_parameters.size > 1
          raise MissingParameterValueException, "Parameters #{missing_required_parameters.collect(&:parameter_name).smart_sort.join(', ').bold} are required" if missing_required_parameters.any?
        end
        self.class.parameter_definitions.each do |parameter_definition|
          value = parameter_definition.resolve_value(parameters, context[:content_provider], chart);
          self.send("#{parameter_definition.name}=", value)
       end
      end
    end
  end

  cattr_reader :macros
  @@macros = {}

  WEB_COLOR_REGEXP = /#([0-9a-f]{6})\s*$/im
  SYNTAX_ERROR_MESSAGE = "Please check the syntax of this macro. The macro markup has to be valid YAML syntax."

  class << self

    ## colors need to be quoted or they will be considered as comments
    def parse_parameters(parameters)
      with_error_handling do
        raise "Embedding Ruby objects is not allowed" if parameters =~ /\!ruby\//
        parameters = parameters.gsub(WEB_COLOR_REGEXP, '\'\0\'')
        if result = YAML::fix_encoding_and_load(escape_single_quote(parameters))
          result.tap { |return_value| raise("Could not understand macro parameters: #{parameters}") unless return_value.is_a? Hash }
        else
          {}
        end
      end
    end

    def register(id, macro_class)
      macros[id] = macro_class
    end

    def unregister(id)
      macros.delete(id)
    end

    def get(id)
      macros[id]
    end

    def registered?(id)
      !macros[id].nil?
    end

    def inherited(base_class)
      base_class.send :include, ParameterSupport
    end

    def create(name, context, parameters, raw_content)
      raise Macro::ProcessingError.new("No such macro: #{name.bold}") if !registered?(name)
      with_error_handling do
        Macro.get(name).new(context, name, parameters, raw_content)
      end
    end

    def with_error_handling(&block)
      yield
    rescue StandardError => e
      reraise_with_logging(e)
    end

    def reraise_with_logging(exception, prefix=nil)
      if defined?(logger)
        logger.debug { "error rendering macro:" + exception.message }
        logger.debug { exception.backtrace.join("\n") }
      end
      context_project = exception.respond_to?(:project) ? exception.project : nil
      new_exception = Macro::ProcessingError.new(refine_message_from(exception, prefix), context_project)
      new_exception.set_backtrace(exception.backtrace)
      raise new_exception
    end

    private

    def refine_message_from(e, prefix=nil)
      if parsing_error?(e)
        Macro::SYNTAX_ERROR_MESSAGE
      elsif MissingParameterValueException === e
        "#{e.message}. #{Macro::SYNTAX_ERROR_MESSAGE}"
      else
        e.message
      end
    end

    def parsing_error?(e)
      is_jruby_parsing_error = defined?(e.cause) && e.cause && defined?(Java::OrgJvyamlb::ParserException) && e.cause.is_a?(Java::OrgJvyamlb::ParserException)
      is_jruby_19_parsing_error = defined?(Psych::SyntaxError) && Psych::SyntaxError === e
      is_cruby_parsing_error = e.is_a?(ArgumentError)
      is_jruby_parsing_error || is_jruby_19_parsing_error || is_cruby_parsing_error
    end

    def escape_single_quote(str)
      ## if there's more than one single quote in the value
      # quote the entire line as it's probably a MQL expression with quotes
      # we don't want to force the user to understand strange YAML quoting rules
      str.gsub!(/(:\s+)('.*\w.*'.*\w.*)$/) do |match|
        indicator = $1
        value = $2.gsub(/'/, %{''})
        %{#{indicator}'#{value}'}
      end
      str.gsub!(/(:\s+)(".*\w.*".*\w.*)$/) do |match|
        indicator = $1
        value = $2.gsub(/"/, %{\\"})
        %{#{indicator}"#{value}"}
      end
      str
    end

  end

  attr_reader :name, :context, :parameters

  # subclass could have its own validations & parameter_conversions
  class << self
    def validations
      @validations ||= []
    end
    def add_validation_errors(new_errors)
      @validations = new_errors + validations
    end
    def parameter_conversions
      @parameter_conversions ||= []
    end
  end
  include Macro::Validations

  ## initializer is for internal use only, Macro.create instead
  def initialize(context, name, parameters, raw_content = nil)
    @context = context
    @name = name
    @parameters = parameters || {}

    @raw_content = raw_content
    raise 'Illegal parameter' unless (Hash === @parameters)
    initialize_parameters_from(self, @parameters, context)

    convert_parameters
    validate!
  end

  class MissingParameterValueException < StandardError; end

  def parameter_definitions
    self.class.parameter_definitions
  end

  def parameter_values
    parameter_definitions.inject({}) do |values, parameter_definition|
      values[parameter_definition.name.to_sym] = self.send(parameter_definition.name)
      values
    end
  end

  def view_helper
    context[:view_helper]
  end

  def project
    context[:project] || @project
  end

  def content_provider
    context[:content_provider]
  end

  def page
    context[:content_provider]
  end

  def execute
    return @alerts.uniq.join("\n") unless @alerts.blank?
    # raise error even there is alert, error should have higher priority
    macro_result = self.class.with_error_handling { self.execute_macro }
    @alerts.blank? ? macro_result : @alerts.uniq.join("\n")
  end

  def alert(message)
    (@alerts ||= []) << message
  end

  def execute_with_body(body)
    raise 'subclass responsibility'
  end

  def can_be_cached?
    return false if !defined?(@can_be_cached)
    @can_be_cached
  end

  def card_query_options
    { :content_provider => content_provider, :alert_receiver => self }
  end

end
