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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class MessagingProcessorTest < ActiveSupport::TestCase
  include Messaging

  def test_find_all_processors_that_is_processing_queue_message
    assert !Processor.queue_processors.values.include?(UserAwareProcessor)
    assert Processor.queue_processors.values.include?(FeedsCachePopulatingProcessor)
    assert Processor.queue_processors.values.include?(CardImportProcessor)
  end

  def test_build_message_queue_and_processor_map
    assert_equal FullTextSearch::IndexingUsersProcessor, Processor.queue_processors[FullTextSearch::IndexingUsersProcessor::QUEUE]
    assert_equal ProjectExportProcessor, Processor.queue_processors[ProjectExportProcessor::QUEUE]
  end
end
