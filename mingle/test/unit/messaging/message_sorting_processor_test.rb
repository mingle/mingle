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

class Messaging::MessageSortingProcessorTest < ActiveSupport::TestCase

  def setup
    Messaging::Gateway.instance_variable_set(:"@instance", InMemoryEndpoint.new)
    @processor = SimpleProcessor.new
  end

  def teardown
    Multitenancy.clear_tenants
    Messaging::Gateway.instance_variable_set(:"@instance", nil)
  end

  def test_should_sort_messages_per_tenant
    Multitenancy.add_tenant("first", current_db_tenant_config)
    Multitenancy.add_tenant("second", current_db_tenant_config)

    Messaging::Gateway.instance.prepopulate(SimpleProcessor::QUEUE, [
      {:tenant => "first", :id => 10},
      {:tenant => "first", :id => 5},
      {:tenant => "second", :id => 11},
      {:tenant => "second", :id => 3},
      {:tenant => "first", :id => 1},
      {:tenant => "first", :id => 40},
      {:tenant => "second", :id => 45},
      {:tenant => "second", :id => 5},
    ])

    SimpleProcessor.bulk_receive(SimpleProcessor::QUEUE, {}, @processor)

    assert_equal 0, @processor.message_keys(SimpleProcessor::NO_TENANT).size
    assert_equal [1, 5, 10, 40], @processor.message_keys("first")
    assert_equal [3, 5, 11, 45], @processor.message_keys("second")
  end

  def test_should_sort_messages_without_tenant
    Messaging::Gateway.instance.prepopulate(SimpleProcessor::QUEUE, [
      {:id => 10},
      {:id => 5},
      {:id => 11},
      {:id => 3},
      {:id => 1},
      {:id => 20},
    ])

    SimpleProcessor.bulk_receive(SimpleProcessor::QUEUE, {}, @processor)

    assert_equal [1, 3, 5, 10, 11, 20], @processor.message_keys(SimpleProcessor::NO_TENANT)
  end

  def test_can_sort_messages_by_key
    Messaging::Gateway.instance.prepopulate(SimpleProcessor::QUEUE, [
      {:position => 3},
      {:position => 13},
      {:position => 2},
      {:position => 8},
      {:position => 5},
      {:position => 1},
    ])

    SimpleProcessor.bulk_receive(SimpleProcessor::QUEUE, {:sort_by => :position}, @processor)

    assert_equal [1, 2, 3, 5, 8, 13], @processor.message_keys(SimpleProcessor::NO_TENANT, :position)
  end

  class SimpleProcessor < Messaging::MessageSortingProcessor
    attr_reader :processed_messages

    QUEUE = "my-queue"

    def initialize
      @processed_messages = Hash.new {|h, k| h[k] = []}
    end

    def on_message(message)
      key = message[:tenant] || NO_TENANT
      @processed_messages[key] << message.body_hash
    end

    def message_keys(tenant, key=:id)
      processed_messages[tenant].map {|m| m[key]}
    end
  end

end
