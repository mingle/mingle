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
  # There are 2 parts handled by Validations module for a Macro initialization
  #   1. parse a parameter to be a specific type of object, e.g. date object
  #   2. validate the parameters for business logic, e.g. start_date < end_date
  # We considered part 1 as a parsing data and part 2 are logic validation.
  # So when part 1 failed, we should not do part 2 anymore.
  # The only class include this should be Macro

  class ConvertParameterError < StandardError;end
  class ValidationError < StandardError;end

  module Validations
    def self.included(base)
      base.extend ClassMethods
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
      def validate(method_name, options={})
        validations << [method_name, options]
      end

      def convert_parameter(name, options={})
        parameter_conversions << [name, options]
      end
    end

    module InstanceMethods
      def errors
        @errors ||= []
      end

      def validate!
        raise ValidationError, self.errors.join(", ") unless valid?
      end

      def valid?
        errors.clear
        validate
        self.errors.empty?
      end

      def validate
        self.class.validations.each do |validator_method_name, options|
          begin
            if (options[:if].blank? || self.send(options[:if]))
              unless self.send(validator_method_name)
                error_message = options[:message].blank? ? validator_method_name.to_s.humanize : options[:message]
                self.errors << error_message
                return if options[:block]
              end
            end
          rescue => e
            log_error(e, 'macro validation failure', :severity => Logger::WARN)
            error_message = if options[:message]
              "#{options[:message]}: #{e.message}"
            else
              e.message
            end
            self.errors << error_message
            return if options[:block]
          end
        end
      end

      def convert_parameters
        self.class.parameter_conversions.each do |name, options|
          value = self.send(options[:from])
          return unless value and not value.empty?

          data_type = case options[:as]
          when :date
            parse_date(value, options[:from])
          end
          self.instance_variable_set("@#{name}", data_type)
        end
      rescue => e
        if defined?(logger)
          logger.info { e.message }
          logger.debug { e.backtrace.join("\n") }
        end
        raise ConvertParameterError.new(e.message)
      end
    end

  end
end
