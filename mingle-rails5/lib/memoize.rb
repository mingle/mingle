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

module Memoize
  def memoize(cached_method, options = {})
    module_eval <<-end_eval
      alias_method :__#{cached_method.object_id}__, :#{cached_method.to_s}
      private :__#{cached_method.object_id}__
      def #{cached_method.to_s}(*args, &block)
        @__#{cached_method.object_id}__ ||= {}
        if @__#{cached_method.object_id}__.has_key?(args)
          @__#{cached_method.object_id}__[args]
        else
          @__#{cached_method.object_id}__[args] = __#{cached_method.object_id}__(*args, &block)
        end
      end
    end_eval
    if options[:return_clone]
      module_eval <<-end_eval
        def #{cached_method.to_s}_with_returning_clone(*args, &block)
          if ret = #{cached_method.to_s}_without_returning_clone(*args, &block)
            ret.clone
          end
        end
        alias_method_chain :#{cached_method.to_s}, :returning_clone
      end_eval
    end
    module_eval <<-end_eval
      def clear_cached_results_for(cached_method)
        instance_variable_set('@__' << cached_method.object_id.to_s << '__', {})
      end
    end_eval
  end
  
  def memoize_all(*methods)
    methods.each { |method| memoize(method) }
  end

  def unmemoize_all
    instance_methods.each { |method| unmemoize(method.to_sym) }
  end

  def unmemoize(method)
    if private_method_defined?(:"__#{method.object_id}__")
      undef_method method
      alias_method method, :"__#{method.object_id}__"
      public method
      undef_method :"__#{method.object_id}__"
      undef_method :clear_cached_results_for
    end
    if method_defined?(:"#{method}_with_returning_clone")
      undef_method :"#{method}_with_returning_clone"
    end
  end
end

class Module
  include Memoize
end
