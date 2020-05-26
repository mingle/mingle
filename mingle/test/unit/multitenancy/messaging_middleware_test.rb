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

class Multitenancy::MessagingTest < ActiveSupport::TestCase
  include Messaging

  def setup
    @endpoint = InMemoryEndpoint.new

    Multitenancy.add_tenant('first', "database_username" => 'first_schema')
    Multitenancy.add_tenant('second', "database_username" => 'second_schema')
  end

  def teardown
    Multitenancy.clear_tenants
  end

  def test_should_attach_tenant_info_to_message_while_sending_messages_inside_an_activated_tenant
    middleware = Multitenancy::MessagingMiddleware
    middleware = middleware.new(@endpoint)
    middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    assert_equal 1, @endpoint.queues['queue'].size
    assert_equal({:text => 'hello'}, @endpoint.queues['queue'].first.body_hash)

    Multitenancy.activate_tenant('first') do
      middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    end

    assert_equal 2, @endpoint.queues['queue'].size
    assert_equal({:text => 'hello', :tenant => 'first'}, @endpoint.queues['queue'].last.body_hash)
  end

  def test_should_activate_tenant_when_receive_a_message_has_tenant_info
    middleware = Multitenancy::MessagingMiddleware
    middleware = middleware.new(@endpoint)

    middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    assert_equal 1, @endpoint.queues['queue'].size
    assert_equal({:text => 'hello'}, @endpoint.queues['queue'].first.body_hash)

    Multitenancy.activate_tenant('first') do
      middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    end

    activated_tenant = []
    middleware.receive_message('queue') do |msg|
      activated_tenant << Multitenancy.active_tenant.try(:name)
    end
    assert_equal [nil, 'first'], activated_tenant
  end

end
