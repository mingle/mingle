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

require 'benchmark'

class MemcacheClientBenchmarking
  def initialize(client)
    @client = client
    @key_size = 1000
  end

  # get, add/set ratio: 9/1
  # string value, obj value ratio: 5/1
  # string value length, from 5 to 2mb
  # gather the results and return them
  # 30 seconds => 30_000 actions => 3_000 set, 27_000 get
  def benchmark(time)
    actions = (time * 1000).to_i.times.to_a.map{ rand(10) == 9 ? do_set(gen_value) : do_get }
    results = []

    end_time = Time.now + time

    while(Time.now < end_time) do
      action = actions[rand(actions.length)]
      t = Time.now
      action.call
      results << (Time.now - t) * 1000
    end

    results
  end

  def gen_value
    rand(5) == 4 ? gen_string_value : gen_obj_value
  end

  def gen_string_value
    UUID.generate * rand(10_000)
  end

  def gen_obj_value
    {:hello => gen_string_value}
  end

  def do_get
    lambda do
      @client.get(key)
    end
  end

  def do_set(value)
    lambda do
      @client.set(key, value)
    end
  end

  def key
    "key-#{rand(@key_size)}"
  end
end
