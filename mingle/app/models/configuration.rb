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

module Configuration
  class Default
    attr_accessor :name, :settings
    class << self
      def new_section(name, *keys)
        keys.empty? ? SingleValuedDefault.new(name) : Default.new(name, *keys)
      end  
    end
  
    def initialize(name, *keys)
      self.settings = Hash[*keys.collect { |key| empty_commented_setting(key) }.flatten]
      self.name = name
    end  

    def [](key)
      return '' if settings.keys.include?(commented(key))
      settings[key]
    end  

    def []=(key, value)
      @settings.tap do |hash|
        key_to_delete = settings.keys.detect {|commented_key| commented_key == commented(key)}
        settings.delete(key_to_delete)
        settings[key] = (value =~ /^\d+$/ ? value.to_i : value)
      end
    end

    def merge_params(params_hash, store_blank_fields=false)
      return unless params_hash
      merge!(params_hash.stringify_keys[name.to_s], store_blank_fields)
      self
    end
  
    def merge!(new_settings, store_blank_fields=false)
      return unless new_settings
      settings.tap do |hash|
        new_settings.each do |key, value|
          self[key] = value unless value.blank? && !store_blank_fields
        end  
      end  
    end
    alias merge merge!
  
    def merge_into(hash)
      return unless hash && settings
      settings.each do |key, value|
        hash.merge!(key => value) unless commented?([key, value])
      end
    end  
  
    def write_as_yaml_on(io)
      io << "#{name}:\n"
      settings.each do |key, value|
        io << "  #{convert_setting_to_yaml_entry(key, value)}\n"
      end
    end  
  
    def read_from_yml(yml_hash)
      self.settings = yml_hash[self.name] if yml_hash[self.name]
      result_hash = {}
      merge_into(result_hash)
      OpenStruct.new(result_hash)
    end  
      
    def to_hash
      {name => settings}
    end  

    private
    
    def convert_setting_to_yaml_entry(key, value)
      escaped_value = if value.blank?
        nil
      else
        escaped = YAML::dump(value)
        escaped[4..escaped.size - 2]
      end
      [key, escaped_value].join(': ')
    end
    
    def commented(key)
      '#' + key.to_s
    end  
  
    def commented?(setting)
      setting.first =~ /^#/
    end  
  
    def empty_commented_setting(setting)
      [commented(setting), '']
    end  
  end  

  class SingleValuedDefault < Default
    attr_accessor :value

    def initialize(name)
      self.name = name
    end  

    def merge!(new_settings, store_blank_fields=false)
      self.value = new_settings if new_settings
    end
    alias merge merge!
  
    def write_as_yaml_on(io)
      io << "#{name}: #{value}\n"
    end  
  
    def to_hash
      {name => value}
    end  
    
    def merge_into(hash)
      return unless hash
      hash.merge!(name.to_s => value) unless commented?(name.to_s)
    end  
    
    def read_from_yml(yml_hash)
      self.value = yml_hash[self.name]
      self.value
    end  
  end  
end
