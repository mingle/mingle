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

module Rabl
  module BuilderExt

    def self.included(base)
      base.class_eval do
        alias_method_chain :to_hash, :camelcase
      end
    end

    def to_hash_with_camelcase
      result = to_hash_without_camelcase
      Rabl.configuration.convert_to_camelcase ? convert_hash_keys_to_camelcase(result) : result
    end

    private
    def camelcase_key_without_question_mark(key)
      key.to_s.camelize(:lower).gsub(/\?.*/, '').to_sym
    end

    def convert_hash_keys_to_camelcase(hash)
      case hash
        when Array
          hash.map {|ele| convert_hash_keys_to_camelcase(ele)}
        when Hash
          Hash[hash.map {|k, v| [camelcase_key_without_question_mark(k), convert_hash_keys_to_camelcase(v)]}]
        else
          hash
      end
    end
  end

  module ConfigurationExt
    def self.included(base)
      base.class_eval do
        attr_accessor :convert_to_camelcase
      end
    end
  end
end

Rabl::Builder.class_eval {include(Rabl::BuilderExt)}
Rabl::Configuration.class_eval {include(Rabl::ConfigurationExt)}
