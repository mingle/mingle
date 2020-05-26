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

class InvalidUserMessageFilter

  def initialize(auto_reply_notification=MurmurAutoReplyNotification.new)
    @auto_reply_notification = auto_reply_notification
  end

  def filter?(message, data)
    tenant_name = data['tenant']
    filter = invalid_tenant(tenant_name) do
      should_filter(message, data)
    end
    send_auto_reply(message) if filter
    return filter
  end

  private

  def invalid_tenant(tenant_name, &block)
    return true unless block_given?
    if MingleConfiguration.multitenancy_mode?
      tenant = Multitenancy.find_tenant(tenant_name)
      if tenant.nil?
        Rails.logger.info("No tenant found for #{tenant_name}")
        return true
      end
      tenant.activate(&block)
    else
      yield
    end
  end

  def should_filter(message, data)
    return true unless message
    user = User.find_by_id(data['user_id'])
    return true unless user && user.activated?
    Rails.logger.info("User: #{user.email}, From user: #{message.from.address}")
    user.email != message.from.address
  end

  def send_auto_reply(message)
    @auto_reply_notification.send_auto_reply_for_message(message, :invalid_operation) if @auto_reply_notification.present?
  end
end
