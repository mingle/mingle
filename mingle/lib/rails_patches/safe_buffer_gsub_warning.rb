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
  # class SafeBuffer < String
  #   alias :str_gsub :gsub
  #   def gsub(*args, &block)
  #     if block_given?
  #       ActiveRecord::Base.logger.info %Q[ WARNING:
  #         gsub on ActiveSupport::SafeBuffer is dangerous, and can lead to hard-to-debug errors!
  #         Please convert this to a vanilla String using to_str()
  #         ]
  #
  #         str_gsub(*args, &block)
  #       else
  #         str_gsub(*args)
  #       end
  #   end
  # end
  
  module GsubSafety
    def self.unsafe_substitution_retaining_html_safety(content)
      was_html_safe = content.html_safe?
      result = yield was_html_safe ? content.to_str : content
      was_html_safe ? result.html_safe : result
    end
  end
end
