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
  def logger
    ActiveRecord::Base.logger
  end

  module_function :logger
end

require 'messaging/routes'

require 'messaging/middleware'
require 'messaging/retry_on_error'
require 'messaging/migration_guard'
require 'messaging/error_handling'

require 'messaging/adapters'
require 'messaging/endpoint'

require 'messaging/enablement'
require 'messaging/group'
require 'messaging/multicasting'

require 'messaging/mailbox'
require 'messaging/message_provider'
require 'messaging/sending_message'

require 'messaging/base'
require 'messaging/processor'
require 'messaging/gateway'

Messaging::Mailbox.sender = Messaging::Gateway.instance # initialize instance, avoid thread issue
