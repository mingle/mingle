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

module MingleUpgradeHelper
  def ruby_1_9?
    RUBY_VERSION.to_f >= 1.9
  end

  def fix_string_encoding_19(str)
      # if input sting contains old Syck-style encoded UTF-8 characters
      # then replace them with corresponding UTF-8 characters
      if !str.nil? && !str.ascii_only?
        str = str.gsub(/(\\x[0-9a-fA-F]{2})+/){|m| eval "\"#{m}\""}.force_encoding(Encoding::UTF_8)
      end
      str
  end

  def force_encoding_19(obj, encoding='utf-8')
    return obj unless ruby_1_9?
    case obj
      when Hash
        obj.update(obj) { |_, value| force_encoding_19(value, encoding) }
      when Array
        obj.collect { |item| force_encoding_19(item, encoding) }
      when String
        obj.force_encoding(encoding)
      else
        obj
    end
  rescue Exception => e
    Rails.logger.error("Failed to force encoding(#{encoding}) on obj: #{obj.inspect} with error: #{e.message}")
    obj
  end

  module_function :ruby_1_9?, :fix_string_encoding_19, :force_encoding_19
end
