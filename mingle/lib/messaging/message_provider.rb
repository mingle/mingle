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
  module MessageProvider
    def message
      message_body = {:id => self.id}
      message_body.merge! :project_id => project_id if respond_to?(:project_id)
      if deliverable_type_project
        message_body.merge! :project_id => deliverable_id 
      end
      Messaging::SendingMessage.new(message_body)
    end
    
    def deliverable_type_project
      respond_to?(:deliverable_type) && deliverable_type == Deliverable::DELIVERABLE_TYPE_PROJECT && respond_to?(:deliverable_id)
    end

  end
  
  module Program
    module MessageProvider
      def message
        message_body = {:id => self.id}
        message_body.merge! :deliverable_id => deliverable_id, :deliverable_type => deliverable_type
        Messaging::SendingMessage.new(message_body)
      end
    end
  end
end

class Hash
  def message
    self
  end
end
