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

class ConstantResetter

  def self.set_constant(params)
    @old_values ||= {}
    constant = params['name'] || params[:name]
    value = params['value'] || params[:value]
    @old_values[constant] = constant.constantize
    silence_warnings { set_value_of(constant, value) }
    "SUCCESS: #{constant} = #{constant.constantize.inspect}"
  end

  def self.reset_constant(params)
    constant = params['name'] || params[:name]
    old_value = @old_values[constant]
    silence_warnings { set_value_of(constant, old_value) }
    @old_values.delete(constant)
    "SUCCESS: #{constant} = #{constant.constantize.inspect}"
  end

  def self.set_value_of(name, value)
    parts = name.split("::").compact.reverse
    Object.const_set(name, value) if parts.size == 1
    constant = parts.shift
    parts.reverse.join("::").constantize.const_set(constant, value)
  end

end
