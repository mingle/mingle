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

class EndpointTest < ActiveSupport::TestCase

  include Messaging

  def setup
    Messaging.enable
  end

  def teardown
    Messaging.disable
  end

  def test_endpoint_should_namespace_queue_names
    MingleConfiguration.overridden_to(:multitenant_messaging => false) do
      MingleConfiguration.with_app_namespace_overridden_to('ns') do
        Gateway.instance.send_message("test_queue", [SendingMessage.new({:project_id => 5})])
      end
      received_messages = []
      Gateway.instance.receive_message("ns.test_queue") do |msg|
        received_messages << msg
      end
      assert received_messages.any?
    end
  end

  def test_does_not_namespace_queue_names_when_app_namespace_is_not_set
    MingleConfiguration.overridden_to(:multitenant_messaging => false) do
      assert_equal "queue_name", Endpoint.namespaced_queue("queue_name")
    end
  end

  def test_namespaces_queue_names_with_app_namespace
    MingleConfiguration.overridden_to(:multitenant_messaging => false) do
      MingleConfiguration.with_app_namespace_overridden_to('app') do
        assert_equal "app.queue_name", Endpoint.namespaced_queue("queue_name")
      end
    end
  end

  def test_namespace_queue_with_global_queue_name_prefix
    MingleConfiguration.overridden_to(:multitenant_messaging => false) do
      MingleConfiguration.overridden_to(:app_namespace => 'app', :queue_name_prefix => "prefix") do
        assert_equal "prefix.app.queue_name", Endpoint.namespaced_queue("queue_name")
      end
    end
  end

  def test_should_not_attach_app_namespace_when_multitenant_messaging_is_on
    MingleConfiguration.overridden_to(:multitenant_messaging => true) do
      MingleConfiguration.overridden_to(:app_namespace => 'app', :queue_name_prefix => "prefix") do
        assert_equal "multi.prefix.queue_name", Endpoint.namespaced_queue("queue_name")
      end
    end
  end

end
