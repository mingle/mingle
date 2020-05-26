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

#Header understands how the first row of a tab-separated import determines property definitions. It uses this information to convert any other row into a hash of attributes that can be used to build a Card.
module CardImport
  class Header
    include ActionView::Helpers::TextHelper
  
    attr_reader :mappings, :columns

    def initialize(header_cells, reader)
      @header_cells = header_cells
      @reader = reader
      @mappings = CardImport::Mappings.new(header_cells, reader) do |*args|
        yield *args if block_given?
      end
      @columns = []
      @header_cells.each_with_index { |cell, index| @columns << CardImport::Column.new(index, cell, @reader.project) }
    end
  
    def cells
      @header_cells
    end
  
    def protected_cell?(header_cell)
      @reader.protected_property_definition_names.any?{|protected_cell| protected_cell.upcase == header_cell.upcase}
    end

    def create_property_definitions(project)
      @mappings.create_property_definitions(project).compact
    end

    def attributes_for(values)
      @mappings.to_attributes(values)
    end

    def number_column_defined?
      !@mappings.index_of_attribute('number').nil?
    end

    def tags_column_defined?
      !@mappings.index_of_attribute('tags').nil?
    end  
  
    def maps?(association)
      @mappings.maps?(association)
    end  

    def size
      @header_cells.size
    end
  
    def has_duplicates
      cells = @header_cells.collect{|cell| cell.downcase.gsub(/ +/, ' ')}
      cells.uniq != cells
    end  
  
    def missing_name_warning
      return CardImport::MISSING_NAMES_WARNING if has_missing_column('name')
    end
  
    def formula_columns_warning
      formula_columns = formula_column_names
      return "Cannot set value for formula #{'property'.plural(formula_columns.size)}: #{formula_columns.bold.to_sentence}" if formula_columns.any?
    end
  
    def aggregate_columns_warning
      aggregate_columns = aggregate_column_names
      return "Cannot set value for aggregate #{'property'.plural(aggregate_columns.size)}: #{aggregate_columns.bold.to_sentence}" if aggregate_columns.any?
    end
  
    def missing_type_warning
      return "Some cards being imported do not have a card type. If you continue, Mingle will provide the first card type which is  #{Project.current.card_types.first.name.bold} in current project." if has_missing_column('type')
    end
  
    def has_new_types
      return false unless @mappings.index_of_attribute('type')
      new_types.size > 0
    end
  
    def new_types
      return [] unless @mappings.index_of_attribute('type')
      types = @reader.excel_content.cells.collect { |line| line[@mappings.index_of_attribute('type')] }.uniq
      existing_types = Project.current.card_types.collect { |ct| ct.name.downcase }
      new_types = []
      types.each do |type|
        if !type.blank? && !existing_types.include?(type.downcase) && !new_types.include?(type)
          new_types << type
        end
      end
      new_types
    end
  
    def protected_cell_warnings
       unless (protected_cells = @header_cells.select{|cell| protected_cell?(cell)}).empty?
          protected_cells.collect{|protected_cell| "Property #{protected_cell.bold} is transition only and will be ignored when updating cards. When creating new cards, these values will be set."}
       end
    end

    def tree_property_warning
      tree_property_cells = @reader.tree_property_definitions.select do |prop_def|
        @header_cells.include?(prop_def.name) 
      end
       unless tree_property_cells.empty?
          tree_property_cells.collect{|tree_property| "Property #{tree_property.name.bold} is tree property, and will only be updated if #{tree_property.tree_configuration.name} is set to yes."}
       end
    end
  
    def validate_prop_def_names_with(project)
      errors = []
      @mappings.custom_property_mappings.each do |mapping|
        begin
          mapping.with_new_valid_prop_def_name project
        rescue => e
          errors << e.message
          raise e
        end
      end
      yield errors if errors.any?
    end    
  
    def all_enumeration_values_and_card_types
      Hash.new.tap do |result|
        @reader.excel_content.cells.each do |line|
          @mappings.all_enumeration_values_in(line).merge(@mappings.all_card_types_in(line)).each do |key, value|
            existing_values = (result[key] ||= [])
            existing_values << value unless value.blank? || existing_values.any?{ |existing_value| existing_value.downcase.trim == value.downcase.trim }
          end  
        end  
      end  
    end

    def checklist_items_defined?
      @mappings.index_of_attribute(Mappings::INCOMPLETE_CHECKLIST_ITEMS).present? ||
          @mappings.index_of_attribute(Mappings::COMPLETED_CHECKLIST_ITEMS).present?
    end
  
    private
  
    def has_missing_column(name)
      return true unless @mappings.index_of_attribute(name)
      @reader.excel_content.cells.any? { |line| line[@mappings.index_of_attribute(name)].blank? }
    end
  
    def formula_column_names
      column_names_for(:formula_property_definitions_with_hidden) 
    end
  
    def aggregate_column_names
      column_names_for(:aggregate_property_definitions_with_hidden)
    end
  
    def column_names_for(property_definition_association_name)
      project_prop_defs = Project.current.send(property_definition_association_name)
      @header_cells.inject([]) do |result, cell|
        result += project_prop_defs.select { |pd| pd.name.ignore_case_equal?(cell) }
      end.compact.collect(&:name)
    end  
  
  end
end
