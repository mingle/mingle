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

module Renderable
  module RenderedDescriptionAnchor
    @@recognized_renderable_types = []

    def self.included(base)
      @@recognized_renderable_types << class_to_renderable_type(base)
    end

    def self.find_renderable(renderable_type, renderable_id)
      if renderable_class = renderable_type_to_class(renderable_type)
        renderable_class.find_by_id(renderable_id.to_i)
      end
    end

    def self.renderable_type_to_class(renderable_type)
      return unless @@recognized_renderable_types.include?(renderable_type)
      renderable_type.split('::').collect(&:camelize).join('::').constantize
    end

    def self.class_to_renderable_type(clazz)
      clazz.name.downcase
    end

    def rendered_description
       renderable_type = RenderedDescriptionAnchor.class_to_renderable_type(self.class)
       return LinkAnchor.new(renderable_type, self.id)
    end


    class LinkAnchor
      include API::XMLSerializer
      attr_accessor :renderable_type, :renderable_id
      self.routing_name = 'content_rendering'
      compact_at_level 0
      self.resource_link_route_options = proc {|description| { :content_provider => {:type => description.renderable_type, :id => description.renderable_id } } }

      def initialize(renderable_type, renderable_id)
        self.renderable_type = renderable_type
        self.renderable_id = renderable_id
      end

      def html_href(view_helper)
        self.resource_link.html_href(view_helper)
      end
    end

  end
end
