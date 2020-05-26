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

# Rack middleware that sweep all thread locals after each requests.
# This is important for jruby because thread local is released only
# when finalize method call on org.jruby.runtime.ThreadContext. When
# there are too many finalizers in the memory this could be delayed
# long time, even forever if there is one finalizer hangs
module Middlewares
  class ThreadLocalsSweeper
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      Thread.current.keys.each do |key|
        Thread.current[key] = nil if key.is_a?(Symbol)
      end
    end
  end
end
