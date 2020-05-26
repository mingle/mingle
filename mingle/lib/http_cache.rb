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

module HttpCache
  def build(options)
    options.each do |key, value|
      options[key] = signature(value)
    end
    {:etag => signature(options)}
  end

  def signature(value)
    case value
    when Hash
      # sort for jruby Hash will give random result of map
      value.keys.sort_by(&:to_s).map{|k| "#{k}=#{signature(value[k])}"}.join("&")
    when Array
      value.map{|a| signature(a)}
    when ActiveRecord::Base
      signature(value.attributes)
    else
      value.to_s
    end
  end
  extend self
end
