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

# this should be loaded after activesupport backtrace_cleaner loaded
# see railties/lib/initializer backtrace_cleaner method
require 'rails/backtrace_cleaner'

require 'monitor'

require 'tzinfo'
require 'tzinfo/timezone_definition'
module TZInfo
  class Timezone
    @mutex = Monitor.new
    class << self
      alias :unsynchronized_get :get
      def get(identifier)
        @mutex.synchronize do
          unsynchronized_get(identifier)
        end
      end
    end
  end
end
