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

module ActiveSupport
  module Cache
    class MemCacheStore < Store
      ESCAPE_KEY_CHARS = /[\x00-\x20%\x7F-\xFF]/n

      def write_with_encoding_fix(key, value, options = nil)
        write_without_encoding_fix(valid_key(key), value, options)
      end

      def read_with_encoding_fix(key, options = nil)
        value = read_without_encoding_fix(valid_key(key), options)
        value.is_a?(ActiveSupport::Cache::Entry) ? value.value : value
      end

      def delete_with_encoding_fix(key, options = nil)
        delete_without_encoding_fix(valid_key(key), options)
      end

      def exist_with_encoding_fix?(key, options = nil)
        exist_without_encoding_fix?(valid_key(key), options)
      end

      def increment_with_encoding_fix(key, amount)
        increment_without_encoding_fix(valid_key(key), amount)
      end

      def decrement_with_encoding_fix(key, amount)
        decrement_without_encoding_fix(valid_key(key), amount)
      end

      def read_multi_with_encoding_fix(*keys)
        keys.extract_options!
        keys.flatten!

        valid_keys = keys.map {|key| valid_key(key)}
        result_with_valid_keys = read_multi_without_encoding_fix(valid_keys)
        Hash[keys.map {|key| [key, result_with_valid_keys[valid_key(key)]]} ]
      end

      [:write, :read, :delete, :exist?, :increment, :decrement, :read_multi].each do |method|
        alias_method_chain method, :encoding_fix
      end

      private
      def valid_key(key)
        return key if key.nil?
        key = key.to_s.dup
        key = key.force_encoding("BINARY") if key.respond_to?(:encode)
        key = key.gsub(/\s/,'_')
        key.gsub(ESCAPE_KEY_CHARS){ |match| "%#{match.getbyte(0).to_s(16).upcase}" }
      end
    end
  end
end
