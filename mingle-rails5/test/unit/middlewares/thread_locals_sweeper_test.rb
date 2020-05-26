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

class ThreadLocalsSweeperTest < ActiveSupport::TestCase

  def setup
    @app = lambda {}
  end

  def test_should_invoke_call_on_app_with_env_and_ensure_to_sweep_all_local_threads
    @app.expects(:call).with('env').once

    thread_locals_sweeper = Middlewares::ThreadLocalsSweeper.new(@app)
    thread_locals_sweeper.call('env')
    Thread.current.keys.each do |key|
      if key.is_a?(Symbol); assert_nil(Thread.current[key]) end
    end
  end

end
