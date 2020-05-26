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
  module Timeout

    MAX_FORMATTING_TIME = 30

    def self.included(base)
      base.alias_method_chain :formatted_content, :timeout
      base.alias_method_chain :formatted_content_custom, :timeout
    end

    def formatted_content_with_timeout(*args)
      with_format_timeout { formatted_content_without_timeout(*args) }
    end

    def formatted_content_custom_with_timeout(*args)
      with_format_timeout { formatted_content_custom_without_timeout(*args) }
    end

    private

    def with_format_timeout(additional_rescue_proc=nil, &block)
      begin
        ::Timeout.timeout(get_max_formatting_timeout, TimeoutError) do
          yield
        end
      rescue TimeoutError
        timeout_msg.tap do |msg|
          Project.logger.warn(msg)
        end
      rescue Exception => e #timeout interrupt may result in any standard error such as ActiveRecordError
        if "execution expired" == e.to_s
          timeout_msg.tap do |msg|
            Project.logger.warn(msg)
            return msg
          end
        else
          raise
        end
      end
    end

    def get_max_formatting_timeout
       MingleConfiguration.formatting_timeout ? MingleConfiguration.formatting_timeout.to_i : MAX_FORMATTING_TIME
    end

    def timeout_msg
      ext = self.respond_to?(:name) ? ": #{self.name}" : ''
      "Timeout rendering#{ext}"
    end
  end
end
