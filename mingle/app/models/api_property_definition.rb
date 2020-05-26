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

class ApiPropertyDefinition

  def self.create(project, options)
    delegator = self.new(project, options)
    if delegator.valid?
      delegator.create_property_definition
    else
      delegator
    end
  end

  PARAMS_TO_METHOD_MAP = { ['string', 'true'] => 'text_list', 
                           ['string', 'false'] => 'any_text', 
                           ['numeric', 'false'] => 'any_number', 
                           ['numeric', 'true'] => 'number_list', 
                           ['user', ''] => 'user', 
                           ['date', ''] => 'date', 
                           ['card', ''] => 'card_relationship',
                           ['formula', ''] => 'formula'
                         }


  class DataTypeValidation
    MANAGED_TYPES = %w(string numeric)
    UNMANAGED_TYPES = %w(user date card formula)
    VALID_TYPES = MANAGED_TYPES + UNMANAGED_TYPES

    attr_reader :errors
    
    def initialize(params)
      @data_type_text = params[:data_type]
      @is_managed_text = params[:is_managed]
      @errors = []
    end
    
    def valid?
      if @data_type_text.blank?
        @errors << 'You must provide the type of the property to create a card property.'
      elsif !VALID_TYPES.include?(@data_type_text.strip.downcase)
        @errors << "There is no such data type: #{@data_type_text}" 
      end
      
      @errors << "An is_managed value of true or false is required for #{@data_type_text}" if is_managed_missing?
      @errors << "is_managed is not applicable for #{@data_type_text} property" if is_managed_unwanted?
      @errors.empty?
    end
    
    protected
    
    def is_managed_missing?
      MANAGED_TYPES.include?(@data_type_text) && !@is_managed_text.to_s.is_boolean_value?
    end
    
    def is_managed_unwanted?
      UNMANAGED_TYPES.include?(@data_type_text) && @is_managed_text
    end
  end
  
  class CardTypesValidation
    attr_reader :errors

    def initialize(project, params)
      @card_types = (params[:card_types] || [])
      @project_card_types = project.card_types
      @errors = []
    end
    
    def valid?
      invalid_card_types.each do |invalid_card_type|
        @errors << "There is no such card type: #{invalid_card_type}"
      end
      @errors.empty?
    end
    
    def valid_card_types
      @project_card_types.select { |card_type| card_type_names.map(&:downcase).include?(card_type.name.downcase) }
    end
    
    def invalid_card_types
      card_type_names.delete_if {|name| project_card_type_names.include?(name.downcase) }
    end
    
    protected
    
    def card_type_names
      @card_types.map { |card_type| card_type[:name] }.compact
    end
    
    def project_card_type_names
      @project_card_types.map(&:name).map(&:downcase)
    end

  end
  
  def initialize(project, options)
    options = {} unless options.is_a?(Hash)

    @project = project
    @options = options.with_indifferent_access
    remove_ignored_attributes

    @data_type_validation = DataTypeValidation.new(@options.dup)
    @card_types_validation = CardTypesValidation.new(@project, @options.dup)

    @is_numeric = @options[:data_type] == "numeric"
    @data_type = @options.delete(:data_type)
    @is_managed = @options.delete(:is_managed)
    @card_type_params = @options.delete(:card_types) || []
  end
  
  def validate_data_type
    @data_type_validation.errors.each { |msg| self.errors.add_to_base(msg) } if !@data_type_validation.valid?
  end
  
  def validate_card_types
    @card_types_validation.errors.each { |msg| self.errors.add_to_base(msg) } if !@card_types_validation.valid?
  end
  
  def valid?
    errors.clear
    validate_data_type
    validate_card_types
    errors.empty?
  end

  def errors
    @errors ||= ActiveRecord::Errors.new(self)
  end

  def create_property_definition
    @project.all_property_definitions.send(create_property_definition_method, @options).tap do |property_definition|
      property_definition.card_types = get_card_types if property_definition.errors.empty?
    end
  end
  
  private
  def create_property_definition_method
    @is_managed = "" if @is_managed.strip.blank?
    key = [@data_type.downcase, @is_managed.downcase]
    "create_#{PARAMS_TO_METHOD_MAP[key]}_property_definition"
  end
  
  def get_card_types
    @card_types_validation.valid_card_types
  end
  
  def remove_ignored_attributes
    [:hidden, :restricted, :transition_only].each { |attr| @options.delete(attr) }
  end
  
  
  def data_type_exists?(data_type)
    PARAMS_TO_METHOD_MAP.keys.map(&:first).include?(data_type.to_s.downcase)
  end
  
  
end
