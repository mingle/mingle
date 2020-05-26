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

module Multitenancy
  class MessagingMiddleware
    def initialize(endpoint)
      @endpoint = endpoint
    end

    def send_message(queue, messages, options={})
      @endpoint.send_message(queue, attach_tenant_info(messages), options)
    end

    def receive_message(queue, options={}, &block)
      @endpoint.receive_message(queue, options) do |message|
        if message[:tenant] && tenant = Multitenancy.find_tenant(message[:tenant])
          tenant.activate do
            block.call(message)
          end
        else
          block.call(message)
        end
      end
    end

    private
    def attach_tenant_info(messages)
      if tenant = Multitenancy.active_tenant
        messages.map{|m| m.merge(:tenant => tenant.name)}
      else
        messages
      end
    end

  end
end
