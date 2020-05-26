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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class TimeoutHandlingMiddlewareTest < ActiveSupport::TestCase

  def setup
    @app  = lambda {}
  end

  def teardown
    Middlewares::TimeoutHandlingMiddleware.timeout = nil
  end

  def test_timeout_should_return_default_timeout
    assert_equal 50, Middlewares::TimeoutHandlingMiddleware.timeout
  end

  def test_timeout_should_return_configured_timeout
    Middlewares::TimeoutHandlingMiddleware.timeout = 10
    assert_equal 10, Middlewares::TimeoutHandlingMiddleware.timeout
  end

  def test_should_invoke_call_on_app_with_env
    @app.expects(:call).with('env').once
    Middlewares::TimeoutHandlingMiddleware.new(@app).call('env')
  end

  def test_should_abort_request_with_status_code_503
    app = lambda {|_| sleep(2) }
    expected = ['503', {}, '503 Service Unavailable']

    Middlewares::TimeoutHandlingMiddleware.timeout = 1
    response = Middlewares::TimeoutHandlingMiddleware.new(app).call('env')

    assert_equal(expected, response)
  end
end
