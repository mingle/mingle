module JdbcSpec
  module ActiveRecordExtensions
    def self.add_method_to_remove_from_ar_base(meth)
      @methods ||= []
      @methods << meth
    end

    def self.extended(klass)
      (@methods || []).each {|m| (class << klass; self; end).instance_eval { remove_method(m) rescue nil } }
    end
  end
end

require 'jdbc_adapter/jdbc_oracle'
require 'jdbc_adapter/jdbc_postgre'
