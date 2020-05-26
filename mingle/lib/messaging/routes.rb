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

require 'set'
module Messaging
  class Routes
    def initialize
      @destinations = {}
    end

    def add(options)
      raise 'Should not include spaces in the queue name.' if options.values.any?{|value| value.include?(' ')}
      @destinations[options[:from]] ||= Set.new
      @destinations[options[:from]] << options[:to]
    end

    def each
      @destinations.each do |from, targets|
        yield(from, targets) if targets.any?
      end
    end

    def detect
      @destinations.detect { |from, targets| yield(from, targets) if targets.any? }
    end

    def clear
      @destinations.clear
    end
  end

  Redirects = Routes.new
  Wiretaps = Routes.new
end
