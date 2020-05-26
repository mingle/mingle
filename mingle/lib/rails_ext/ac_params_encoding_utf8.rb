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

raise "This is not needed on Rails 3.0 and above. Params are converted to utf-8 encoding by default" unless Rails.version == '2.3.18'

if MingleUpgradeHelper.ruby_1_9?
  class ActionController::Base
    def force_utf8_params
      traverse = lambda do |object, block|
        if object.kind_of?(Hash)
          original_keys = object.keys
          original_keys.each do |key|
            new_key = key.frozen? ? key.dup : key
            block.call(new_key)
            object[new_key] = traverse.call(object.delete(key), block)
          end
        elsif object.kind_of?(Array)
          object.each { |o| traverse.call(o, block) }
        else
          block.call(object)
        end
        object
      end
      force_encoding = lambda do |o|
        break unless o.is_a?(String)
        o = o.dup if o.frozen?
        o.force_encoding(Encoding::UTF_8) if o.respond_to?(:force_encoding) && o.encoding.to_s.match('ASCII-8BIT')
      end
      traverse.call(params, force_encoding)
    end
    before_filter :force_utf8_params
  end
end
