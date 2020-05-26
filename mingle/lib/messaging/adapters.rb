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
  module Adapters
    module_function

    def adapters_endpoints
      {
        'jms' => JMS::JmsEndpoint,
        'sqs' => SQS::SqsEndpoint
      }
    end

    def endpoint
      instance(adapters_endpoints)
    end

    def adapter_name
      @adapter_name || default_adapter
    end

    def adapter_name=(name)
      @adapter_name = name
    end

    def default_adapter
      "jms"
    end

    def instance(map)
      map[adapter_name].try(:instance) || raise("Adapter #{adapter_name} does not support the operation")
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'adapters', '**', '*.rb')).each { |f| require f }
