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

module TracingHelper
  # help you debug the a method's input and output and time for executing
  def trace_method(method)
    old_method = "__#{method.to_s.gsub(/\?$/, '_')}__without_logging__"
    full_method_name = self.name + "#" + method.to_s
    self.class_eval <<-"end_eval"
      alias_method :#{old_method}, :#{method}
      
      def #{method}(*args, &block)
        puts "[DEBUG] calling '#{full_method_name}' with " + args.inspect
        start = Time.now
        ret = self.send(:#{old_method}, *args, &block)
        puts "[DEBUG] calling '#{full_method_name}' using " + (Time.now - start).to_s + ", the result is:\\n " + ret.inspect
        return ret
      end
    end_eval
  end
  
  def humanize_tracing
    self.instance_methods.each do |method|
      method_without_tracing = method + "_without_tracing"
      self.class_eval <<-"end_eval"
        alias_method :#{method_without_tracing}, :#{method}

        def #{method}(*args, &block)
          puts "#{method.gsub(/_/, ' ')} " + args.collect(&:inspect).join(", ")
          #{method_without_tracing}(*args, &block)
        end
      end_eval
    end
  end
end

class Module
  include TracingHelper
  extend TracingHelper
end

class Class
  include TracingHelper
  extend TracingHelper
end
