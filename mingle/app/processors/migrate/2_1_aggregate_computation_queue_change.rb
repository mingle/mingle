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

module AggregateComputation
  def run_once_with_migration(options={})
    Mingle21QueueChangeProcessor.run_once(options)
    run_once_without_migration(options)
  end

  alias_method_chain :run_once, :migration

  module_function :run_once, :run_once_without_migration

  class Mingle21QueueChangeProcessor < Messaging::Processor
    QUEUE = 'mingle.aggregate'
    def on_message(message)
      send_message(AggregateComputation::CardsProcessor::QUEUE, [Messaging::SendingMessage.new(message.body_hash)])
    end
  end
end
