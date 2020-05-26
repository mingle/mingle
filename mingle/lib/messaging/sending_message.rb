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

module Messaging
  class SendingMessage
    attr_reader :properties, :body

    def self.parse_body_xml_as_hash(str)
      data = Hash.from_xml(str).values.first
      if data.is_a?(Hash)
        data.symbolize_keys
      else
        # blank message, the data could be "\n"
        {}
      end
    end

    def initialize(body, properties={})
      @body = body
      @properties = properties
    end

    def [](body_value_key)
      @body[body_value_key]
    end

    def property(key)
      properties[key]
    end

    def body_xml
      @body.to_xml
    end
    alias :text :body_xml

    def full_text
      @body.merge(properties).to_xml
    end

    def body_hash
      @body.dup
    end

    def merge(body_attributes={})
      self.class.new(@body.merge(body_attributes), @properties)
    end
  end
end
