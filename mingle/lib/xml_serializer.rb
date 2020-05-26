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

module API
  module XMLSerializer
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, ResourceLinking)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods

      def uses_custom_serialization
        @uses_custom_serialization = true
      end

      def uses_custom_serialization?
        !!@uses_custom_serialization
      end

      def serializes_as(*args)
        store_serialization_attributes_for_version(:default, *args)
      end

      def conditionally_serialize(*args)
        options = args.extract_options!
        conditional_serialization_attributes[options[:if]] = args
      end

      def additionally_serialize(form, attributes, version = :default)
        serialization_attributes_for_version(version)[form] ||= []
        serialization_attributes_for_version(version)[form] += attributes
      end

      def compact_at_level(level)
        write_inheritable_attribute(:compact_at_level, level)
      end

      def attributes_to_serialize(instance, options)
        return compact_attributes(instance, options[:version])  if options[:compact]
        compact_at_level = read_inheritable_attribute(:compact_at_level)
        options[:compact_at_level] ||= (compact_at_level.nil? ? 1 : compact_at_level).to_i
        level_to_compact_at = (compact_at_level.nil? ? options[:compact_at_level] : compact_at_level).to_i
        if (options[:level].to_i > level_to_compact_at) then
          compact_attributes(instance, options[:version])
        else
          options[:slack] ? slack_attributes(instance, options[:version]) : complete_attributes(instance, options[:version])
        end
      end

      def method_missing(name, *args, &block)
        super unless name.to_s =~ /(.*)_serializes_as$/
        store_serialization_attributes_for_version($1, *args)
      end

      def serialization_attributes
        unless read_inheritable_attribute(:serialization_attributes)
          attrs = HashWithIndifferentAccess.new(:default => {:complete => [], :compact => [], :slack => []})
          write_inheritable_attribute(:serialization_attributes, attrs)
        end
        read_inheritable_attribute(:serialization_attributes)
      end

      def conditional_serialization_attributes
        @conditional_serialization_attributes ||= {}
      end

      def complete_attributes(instance, version)
        result = serialization_attributes_for_version(version)[:complete]

        conditional_serialization_attributes.each do |proc, attributes|
          result += attributes if proc.call(instance)
        end

        result
      end

      def slack_attributes(instance, version)
        result = serialization_attributes_for_version(version)[:slack]

        conditional_serialization_attributes.each do |proc, attributes|
          result += attributes if proc.call(instance)
        end

        result
      end

      def compact_attributes(instance, version)
        serialization_attributes_for_version(version)[:compact]
      end

      def serialization_attributes_for_version(version)
        serialization_attributes[version] || serialization_attributes[latest_version]
      end

      def store_serialization_attributes_for_version(version, *args)
        complete_attributes, compact_attributes, slack_attributes, element_name = if args.first.respond_to?(:keys)
          [args.first[:complete], args.first[:compact], args.first[:slack], args.first[:element_name]]
        else
          [args, args, args, nil]
        end
        compact_attributes ||= complete_attributes
        slack_attributes ||= []
        serialization_attributes[version] = { :complete => complete_attributes, :compact => compact_attributes, :slack => slack_attributes, :element_name => element_name }
      end

      def latest_version
        serialization_attributes.keys.sort.last
      end

      def element_name(options)
        options[:element_name] || serialization_attributes_for_version(options[:version])[:element_name] || name.underscore
      end
    end

    module InstanceMethods
      def xml_serializable?
        true
      end

      def current_serialize_level(options)
        options[:level].to_i
      end

      def next_serialize_level(options)
        current_serialize_level(options) + 1
      end

      def to_xml(options = {})
        "".tap do |result|
          options[:builder] ||= begin
            builder = Builder::XmlMarkup.new(:target => result, :indent => 2)
            builder.instruct! unless options[:skip_instruct]
            builder
          end

          if options[:no_root]
            serialized_node_contents(options)
          else
            attribute_options = {}
            attribute_options = { :type_description => options.delete(:type_description) } if options.key?(:type_description)
            attribute_options = attribute_options.merge(options.delete(:attribute_options)) if options.key?(:attribute_options)
            options[:builder].tag!(self.class.element_name(options), link_to_resource(options), attribute_options || {}) do
              serialized_node_contents(options)
            end
          end
        end
      end

      def link_to_resource(options)
        return {} if current_serialize_level(options) == 0 && !options[:compact]
        return {} unless options[:view_helper]
        return {} unless respond_to?(:resource_link)

        if xml_href = self.resource_link.xml_href(options[:view_helper], options[:version], :escape => false)
          { :url => xml_href }
        else
          {}
        end
      end

      def serialized_node_contents(options)
        b = options[:builder]
        self.class.attributes_to_serialize(self, options).each do |attribute|
          value = extract_value_of_attribute_named(attribute, options)
          attr_tag = attr_to_tag(attribute)
          if (custom_serializable?(value))
            value.to_xml(options.merge(:level => next_serialize_level(options)))
          elsif (serializable?(value) || many_serializables?(value))
            node_options = options.merge(:level => next_serialize_level(options))
            link_options = value.respond_to?(:link_to_resource) ? value.link_to_resource(node_options) : {}
            b.tag!(attr_tag, attribute_options_for(value), link_options) do
              serialize_child(value, node_options)
            end
          elsif value.kind_of?(Hash)
            value.each { |key, val| serialize_scalar(b, key, val) }
          else
            serialize_scalar(b, attr_tag, value)
          end
        end
      end

      def extract_value_of_attribute_named(attribute, options)
        name = attribute.is_a?(Array) ? attribute[0] : attribute
        m = begin
              self.method(name)
            rescue NameError
            end
        if m && m.arity > 0
          self.send(name, options)
        else
          self.send(name)
        end
      end

      def attr_to_tag(attribute)
        tag = if attribute.is_a?(Array)
          attribute[1][:element_name] || attribute
        else
          attribute
        end
        tag.to_s.gsub(/\?$/, '')
      end

      def attribute_options_for(value)
        case value
          when Fixnum then  { :type => "integer" }
          when TrueClass, FalseClass then { :type => "boolean" }
          when Date then { :type => "date" }
          when Time then { :type => "datetime" }
          when DateTime then { :type => "datetime" }
          when NilClass then { :nil => "true" }
          when String then {}
          else value.is_a?(Enumerable) ? { :type => "array" } : {}
        end
      end
    end

    def serialize_scalar(builder, key, value)
      element_text = value.respond_to?(:tz_format) ? value.tz_format : value
      builder.tag!(key.to_s.strip.downcase.underscored, element_text, attribute_options_for(value))
    end

    def serialize_child(value, options)
      if serializable?(value)
        value.to_xml(options.merge(:no_root => true))
      elsif many_serializables?(value)
        value.each { |v| v.to_xml(options) }
      end
    end

    def serializable?(value)
      value.respond_to?(:xml_serializable?) && value.xml_serializable?
    end

    def many_serializables?(value)
      value.respond_to?(:each) && value.all? { |value_element| value_element.respond_to?(:xml_serializable?) }
    end

    def custom_serializable?(value)
      value.class.respond_to?(:uses_custom_serialization?) && value.class.uses_custom_serialization?
    end
  end

  class SerializableError
    include XMLSerializer

    attr_reader :error
    serializes_as :complete => [:error], :element_name => 'errors'

    def initialize(error)
      @error = error
    end
  end


  class SerializableString
    include XMLSerializer

    def initialize(string, tag_name)
      @string = string
      @tag_name = tag_name
    end

    def to_xml(options={})
       options[:builder] ||= Builder::XmlMarkup.new(:target => result, :indent => 2)
       options[:builder].tag!(@tag_name, @string)
    end
  end
end

class StandardError
  def xml_message
    API::SerializableError.new(self.message).to_xml
  end
end

ActiveRecord::Base.send :include, API::XMLSerializer
