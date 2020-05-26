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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class DataExportProcessorTest < ActiveSupport::TestCase

  def test_all_subclasses_are_added_to_queues_deleting_message_on_receive
    subclasses = ObjectSpace.each_object(Class).select { |klass| klass < DataExportProcessor }
    subclasses.each do |klass|
      assert_include klass.const_get(:QUEUE),
                     Messaging::Adapters::SQS::SqsEndpoint.instance.queues_deleting_message_on_receive,
                     "Add #{klass.name} to queues_deleting_message_on_receive in initializers/sqs.rb"
    end
  end

end
