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

module Messaging
  module Multicasting
    def send_message(queue_name, messages, &block)
      if (wiretap = Messaging::Wiretaps.detect {|from, to| from == queue_name})
        from, targets = wiretap
        targets.each { |target| send_message(target, messages, &block)}
      end

      if (route = Messaging::Redirects.detect {|from, targets| from == queue_name})
        from, targets = route
        targets.each {|target| send_message(target, messages, &block)}
      else
        super
      end
    end

  end
end
