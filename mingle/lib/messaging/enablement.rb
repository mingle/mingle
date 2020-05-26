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
  def enabled?
    $enabled
  end

  def enable
    $enabled = true
  end

  def disable
    $enabled = false
  end

  module_function :enabled?, :enable, :disable

  module Enablement
    def self.included(base)
      base.class_eval do
        alias_method_chain :send_message, :messaging_enablement_check
        if method_defined?(:receive_message)
          alias_method_chain :receive_message, :messaging_enablement_check
        end
      end
    end

    def send_message_with_messaging_enablement_check(*args)
      return unless Messaging.enabled?
      send_message_without_messaging_enablement_check(*args)
    end

    def receive_message_with_messaging_enablement_check(*args, &block)
      return unless Messaging.enabled?
      receive_message_without_messaging_enablement_check(*args, &block)
    end
  end

end
