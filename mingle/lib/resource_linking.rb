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
  module ResourceLinking

    class Link
      attr_reader :title

      def initialize(model_class, title, routing_options, route_options_for_xml, route_options_for_html)
        @model_class = model_class
        @title = title
        @routing_options = routing_options
        @route_options_for_xml = route_options_for_xml
        @route_options_for_html = route_options_for_html
      end

      def xml_href(view_helper, api_version, url_options={})
        href(view_helper, url_options.merge({ :api_version => api_version, :format => 'xml' }))
      end

      def html_href(view_helper)
        href(view_helper)
      end

      private

      def href(view_helper, options={})
        format = options[:format].to_s
        url_options = routing_options(format).merge(options)
        named_route_url = "#{@model_class.named_route_for_resource_link(format)}_url"

        view_helper.send(named_route_url, url_options) if view_helper.respond_to?(named_route_url)
      end

      def routing_options(format)
        @routing_options.merge(format == 'xml' ? @route_options_for_xml : @route_options_for_html)
      end
    end

    module SingletonMethods
      def resource_link(title, route_options, route_options_for_xml={}, route_options_for_html={})
        Link.new(self, title, route_options, route_options_for_xml, route_options_for_html)
      end

      def named_route_for_resource_link(format)
        routing_name = self.routing_name || self.model_name.singular
        format == 'xml' ?  "rest_#{routing_name}_show" : "#{routing_name}_show"
      end
    end

    def self.included(base)
      base.extend(SingletonMethods)
      base.class_inheritable_accessor :resource_link_route_options
      base.class_inheritable_accessor :resource_link_route_options_for_xml
      base.class_inheritable_accessor :resource_link_route_options_for_html
      base.class_inheritable_accessor :routing_name
    end

    def resource_link
      self.class.resource_link(resource_link_title, *build_resource_link_route_options)
    end

    def resource_link_title
      if self.respond_to? :name
        self.name
      else
        "#{self.class.name.humanize} #{self.to_param}"
      end
    end

    def build_resource_link_route_options
      general_route_option = case resource_link_route_options
      when NilClass
        {:id => to_param }
      when Proc
        resource_link_route_options.call(self)
      when Hash
        resource_link_route_options
      else
        raise 'can only use hash or proc to config build_resource_link_route_options'
      end

      [
        general_route_option,
        resource_link_route_options_for_xml ? resource_link_route_options_for_xml.call(self) : {},
        resource_link_route_options_for_html ? resource_link_route_options_for_html.call(self) : {}
      ]
    end
  end
end
