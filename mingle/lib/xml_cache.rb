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

# Xmlcache
# from http://webrepsects.blogspot.com/2007/10/xml-fragment-caching-in-rails.html

module ActionView
  module Helpers
    module CacheHelper
      def cache_xml(name ={}, &block)
        @controller.cache_xml_fragment(block, name)
      end
    end
  end
end

module ActionController
  module Caching
    module Fragments
      def cache_xml_fragment(block, name = {}, options = nil)
        unless perform_caching then block.call; return end
        buffer = eval("xml.target!",block.binding)
        if cache = read_fragment(name, options)
          buffer.concat(cache)
        else
          pos = buffer.length
          block.call
          write_fragment(name,buffer[pos..-1], options)
        end
      end
      #used in extension
      def cache_xml_timeout(name={}, expire = 10.minutes.from_now, &block)
        unless perform_caching then block.call; return end
        @@cache_timeout_values = {} if @@cache_timeout_values.nil?
        key = fragment_cache_key(name)
        if is_cache_expired?(key)
          expire_fragment(key)
          @@cache_timeout_values[key] = expire
        end
        cache_xml_fragment(block,name)
      end
    end
  end
end
