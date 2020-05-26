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

require 'tlb'

module Tlb
  module Balancer
    def self.send path, data
      # puts "#{Time.now} [Tlb::Balancer] send #{path}"
      Net::HTTP.start(host, port) do |h|
        # h.set_debug_output($stdout)
        h.read_timeout = (ENV['TLB_HTTP_READ_TIMEOUT'] || 60).to_i
        res = h.post(path, data)
        res.value
        res.body
      end
    end

    def self.get path
      Net::HTTP.get_response(host, path, port).body
    end
  end

  def self.server_command
    "java -Xmx256m -jar #{tlb_jar}"
  end
end
