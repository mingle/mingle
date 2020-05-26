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

class Class
  def subclass_responsibility(*method_names)
    method_names.each do |method_name|
      define_method(method_name, lambda { raise "Subclass #{self.class.name} must implement #{method_name}" })
    end  
  end
  
  def safe_alias_method_chain(target, feature)
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?
    without_method = "#{aliased_target}_without_#{feature}#{punctuation}"
    alias_method_chain(target, feature) unless self.method_defined? without_method
  end
  
  def acts_like(target, options={})
    options[:keep_methods] = [options[:keep_methods]].compact.flatten
    
    self.class_eval do
      alias_method :proxy_respond_to?, :respond_to?
    end
    
    instance_methods.each do |m|
      undef_method(m) if Object.instance_methods.include?(m) && !(m =~ /(^__|^nil\?$|^class$|^send$|^proxy_)/) && !options[:keep_methods].include?(m.to_sym)
    end
    
    self.class_eval <<-"end_eval"
      def respond_to?(method)
        proxy_respond_to?(method) || send(#{target.to_sym.inspect}).respond_to?(method)
      end
    
      def method_missing(method_name, *args, &block)
        self.class.send(:define_method, method_name) do |*args|
          send(#{target.to_sym.inspect}).send(method_name, *args, &block)
        end
        send(#{target.to_sym.inspect}).send(method_name, *args, &block)
      end
    end_eval
  end
end
