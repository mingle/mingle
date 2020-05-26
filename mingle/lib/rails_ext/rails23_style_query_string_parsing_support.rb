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

# this class comes straight from Rails 2.1; am including it in here because it is gone in Rails 2.3 and our parse_query_parameters method needs it.
class UrlEncodedPairParser < StringScanner #:nodoc:
  attr_reader :top, :parent, :result

  def initialize(pairs = [])
    super('')
    @result = {}
    pairs.each { |key, value| parse(key, value) }
  end

  KEY_REGEXP = %r{([^\[\]=&]+)}
  BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}

  # Parse the query string
  def parse(key, value)
    self.string = key
    @top, @parent = result, nil

    # First scan the bare key
    key = scan(KEY_REGEXP) or return
    key = post_key_check(key)

    # Then scan as many nestings as present
    until eos?
      r = scan(BRACKETED_KEY_REGEXP) or return
      key = self[1]
      key = post_key_check(key)
    end

    bind(key, value)
  end

  private
    # After we see a key, we must look ahead to determine our next action. Cases:
    #
    #   [] follows the key. Then the value must be an array.
    #   = follows the key. (A value comes next)
    #   & or the end of string follows the key. Then the key is a flag.
    #   otherwise, a hash follows the key.
    def post_key_check(key)
      if scan(/\[\]/) # a[b][] indicates that b is an array
        container(key, Array)
        nil
      elsif check(/\[[^\]]/) # a[b] indicates that a is a hash
        container(key, Hash)
        nil
      else # End of key? We do nothing.
        key
      end
    end

    # Add a container to the stack.
    def container(key, klass)
      type_conflict! klass, top[key] if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
      value = bind(key, klass.new)
      type_conflict! klass, value unless value.is_a?(klass)
      push(value)
    end

    # Push a value onto the 'stack', which is actually only the top 2 items.
    def push(value)
      @parent, @top = @top, value
    end

    # Bind a key (which may be nil for items in an array) to the provided value.
    def bind(key, value)
      if top.is_a? Array
        if key
          if top[-1].is_a?(Hash) && ! top[-1].key?(key)
            top[-1][key] = value
          else
            top << {key => value}.with_indifferent_access
            push top.last
            value = top[key]
          end
        else
          top << value
        end
      elsif top.is_a? Hash
        key = CGI.unescape(key)
        parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
        top[key] ||= value
        return top[key]
      else
        raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
      end

      return value
    end

    def type_conflict!(klass, value)
      raise TypeError, "Conflicting types for parameter containers. Expected an instance of #{klass} but found an instance of #{value.class}. This can be caused by colliding Array and Hash parameters like qs[]=value&qs[key]=value. (The parameters received were #{value.inspect}.)"
    end
end

# this parse_query_parameters method used to be a patched version of ActionController::CgiRequest.parse_query_parameters, but in Rails 2.3 the
# class and method are gone, so I am temporarily moving it to ActionController::Request.parse_query_parameters for now
module ActionController
  class Request < Rack::Request
    class << self
      def parse_query_parameters(query_string)
        return {} if query_string.blank?
        pairs = query_string.split('&').collect do |chunk|
          next if chunk.empty?
          key, value = chunk.split('=', 2)
          next if key.empty?
          value = value.nil? ? nil : CGI.unescape(value)
          # orignal code: [ CGI.unescape(key), value ]; remove unescape here for Hash key need unescape again, 
          # most of chars can be unescape twice except '+' which will be changed to empty space ' '.
          # for our property name can have '+', we'll have url part likes 'properties[name+foo]=xxx', we need to
          # escape 'name+foo' first, which is 'name%2Bfoo', if we want this url works when use this method(parse_query_parameters)
          # to parse params, we need to escape the 'properties[name%2Bfoo]' to 'properties%5Bname%252Bfoo%5D' which means
          # we need escape 'name+foo' twice and the url would be unreadable. So I removed it here and we would not support 
          # escaped url for query parameters
          [ key.to_s.include?('%') ? CGI.unescape(key) : key, value ]
        end.compact
        UrlEncodedPairParser.new(pairs).result
      end
    end
  end
end
