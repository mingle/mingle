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

class ActiveRecord::Base
  class << self
    def strip_on_write(options={})
      #TODO: remove .map(&:to_sym) once 1.9 migration complete
      return if instance_methods.map(&:to_sym).include?(:write_attribute_with_strip)
      self.send(:define_method, :should_strip?, lambda do |attribute_name|
        !(Array(options[:except])).include?(attribute_name.to_sym)
      end)

      self.send(:define_method, :write_attribute_with_strip, lambda do |attribute_name, value|
        if should_strip?(attribute_name) && value.respond_to?(:trim)
          value = value.trim
        end
        write_attribute_without_strip(attribute_name, value)
      end)

      alias_method_chain :write_attribute, :strip
    end
  end
end
