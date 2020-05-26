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

module HtmlIdSupport
  def html_id
    return "#{self.class.name.downcase}_#{id}" unless id.blank?
    return "#{self.class.name.downcase}_#{name}" unless name.blank?
    raise "No id and name exist, don't know how to generate html id"
  end
end

module PluralizationSupport
  def pluralize(count, singular, plural = nil)
     "#{count} " + if count == 1 || count == '1'
      singular
    elsif plural
      plural
    elsif Object.const_defined?("Inflector")
      Inflector.pluralize(singular)
    else
      singular + "s"
    end
  end
end

module TimestampSupport
  def record_exists?
    !new_record?
  end
  
  def create_with_clock_timestamps
    t = Clock.now
    write_attribute('created_at', t) if respond_to?(:created_at) && created_at.nil?
    write_attribute('created_on', t) if respond_to?(:created_on) && created_on.nil?
    
    write_attribute('updated_at', t) if respond_to?(:updated_at)
    write_attribute('updated_on', t) if respond_to?(:updated_on)
    
    create_without_clock_timestamps
  end
  
  def update_with_clock_timestamps
    t = Clock.now
    
    if !respond_to?(:altered?) || (respond_to?(:altered?) && altered?)
      write_attribute('updated_at', t) if respond_to?(:updated_at)
      write_attribute('updated_on', t) if respond_to?(:updated_on)
    end
    
    update_without_clock_timestamps
  end
  
  def self.included(base)
    base.record_timestamps = false
    base.send :alias_method_chain, :create, :clock_timestamps
    base.send :alias_method_chain, :update, :clock_timestamps
  end
end

module SkipAssociationValidationSupport
  def skip_has_many_association_validations
    has_manys = self.reflect_on_all_associations.select{|assoc_reflection| assoc_reflection.macro.to_s == 'has_many'}
    has_manys.each do |reflection|
      skip_associated_after_update_callback_for(reflection.name)        
      skip_associated_validation_for(reflection.name)
    end
  end

  # todo (Rails 2.1): I bet this isn't working anymore -- we'll have to do something like we did for the following method, skip_associated_validation_for (i.e we
  # had to use the callback chain and not just read/write attributes)
  def skip_associated_after_update_callback_for(reflection)
    if callbacks = read_inheritable_attribute(:after_update)
      callbacks.reject! {|callback| callback.class == String && callback.include?("@#{reflection}")}
      write_inheritable_attribute(:after_update, callbacks)
    end  
  end

  def skip_associated_validation_for(reflection)
    if validate_methods = self.validate_callback_chain
      validate_methods.reject! { |method| method.method.to_s == "validate_associated_records_for_#{reflection}" }
      @validate_callbacks = ActiveSupport::Callbacks::CallbackChain.new.concat(validate_methods)
    end  
  end

  def skip_callback(callback, &block)
    method = instance_method(callback)
    remove_method(callback) if respond_to?(callback)
    define_method(callback) { true }
    yield
    remove_method(callback)
    define_method(callback, method)
  end
end

module DbDerivedValidations
  
  def self.included(base)
    class << base
      attr_accessor :use_database_limits_options
    end
    base.send :extend, ClassMethods
    base.send :include, InstanceMethods
  end
  
  module ClassMethods
    
    def use_database_limits_for_all_attributes(options = nil)
      self.use_database_limits_options = (options || {})
      self.validate :db_derieved_validations
    end

    def database_limits(except)
      except = except || []
      self.columns_hash.inject({}) do |result, attribute_name_column_pair|
        attribute_name = attribute_name_column_pair[0]
        unless except.include?(attribute_name.to_sym)
          column = attribute_name_column_pair[1]
          if (column.limit && column.name !~ /(type|id)$/ && column.type != :boolean) #not for fks, discriminators & bools
            limit = column.type == :string ? 255 : column.limit.to_i
            result[attribute_name] = limit
          end
        end
        result
      end
    end

  end

  module InstanceMethods
    def name_of_attribute(attr); attr; end
    def db_derieved_validations
      if options = self.class.use_database_limits_options
        self.class.database_limits(options[:except]).each do |attribute_name, limit|
          value = self.read_attribute(attribute_name)
          next if value.blank?
          if (value.kind_of?(String) ? value.split(//).size > limit : value.size > limit)
            message = "#{self.name_of_attribute(attribute_name)} is too long (maximum is #{limit} characters)".humanize
            self.errors.add_to_base(message)
          end
        end
      end
    end
  end

end

module DateColumnTypeFix
  def self.included(base)
    base.extend(ClassMethods)
  end
  module ClassMethods
    def date_attributes(*names)
      names.each do |name|
        self.class_eval <<-RUBY
          def #{name}
            obj = super
            if obj.blank? || obj.is_a?(Date)
              return obj
            end
            obj.to_date
          end
        RUBY
      end
    end
  end
end

module ARBaseSingltonExt
  def each_by(attribute, ids, &block)
    ids.each do |id|
      yield self.send("find_by_#{attribute}", id)
    end
  end
end

class ActiveRecord::Base
  include HtmlIdSupport, PluralizationSupport, TimestampSupport
  extend SkipAssociationValidationSupport
  include DbDerivedValidations
  include DateColumnTypeFix
  extend ARBaseSingltonExt
end
