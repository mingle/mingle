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

class Messaging::CleanEnvMiddlewareTest < ActiveSupport::TestCase
  include Messaging

  def setup
    @endpoint = InMemoryEndpoint.new
    @middleware = CleanEnvMiddleware.new(@endpoint)
  end

  def test_should_clear_thread_local_cache_when_process_a_message_with_tenant_activated
    @middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    @middleware.receive_message('queue') do |msg|
      ThreadLocalCache.set('key', 'value')
    end
    assert_equal nil, ThreadLocalCache.get('key')
  end

  def test_should_clear_active_connections
    @middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    @middleware.receive_message('queue') do |msg|
      Project.connection
    end
    assert !ActiveRecord::Base.connection_handler.active_connections?
  end

  def test_should_clear_active_project_activated_in_receive_message
    @middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    @middleware.receive_message('queue') do |msg|
      first_project.activate
    end
    assert_nil Project.current_or_nil
  end

  def test_should_keep_activated_project_that_is_activated_before_call_receive_message
    @middleware.send_message('queue', [Messaging::SendingMessage.new({:text => 'hello'})])
    first_project.activate
    @middleware.receive_message('queue') do |msg|
    end
    assert_equal first_project, Project.current
  end
end
