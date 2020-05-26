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

class DualAppRoutingConfigTest < ActiveSupport::TestCase

  def setup
    @mocked_client = mock

    Java::NetSpyMemcached::MemcachedClient.stubs(:new).returns(@mocked_client)
  end

  def teardown
    DualAppRoutingConfig.clear
  end

  def test_get_routing_enabled_should_fetch_from_memcached_server
    @mocked_client.expects(:get).with(MULTI_APP_ROUTING_DISABLED).returns('false')

    assert DualAppRoutingConfig.routing_enabled?
  end

  def test_set_routing_status_to_false_on_from_memcached_server_when_routing_disabled
    @mocked_client.expects(:set).with(MULTI_APP_ROUTING_DISABLED, 0, 'true')

    DualAppRoutingConfig.disable_routing
  end

  def test_set_routing_status_to_true_on_from_memcached_server_when_routing_enabled
    @mocked_client.expects(:set).with(MULTI_APP_ROUTING_DISABLED, 0, 'false')

    DualAppRoutingConfig.enable_routing
  end

  def test_set_routing_enabled_when_no_value_in_memcached
    @mocked_client.expects(:get).with(MULTI_APP_ROUTING_DISABLED).returns(nil)

    assert DualAppRoutingConfig.routing_enabled?
  end
end
