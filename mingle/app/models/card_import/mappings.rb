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

module CardImport
  
  class Mappings
    TAGS_ATTRIBUTE = 'tags'
    COMPLETED_CHECKLIST_ITEMS = 'completed checklist items'
    INCOMPLETE_CHECKLIST_ITEMS = 'incomplete checklist items'
    STANDARD_MAPPINGS = (::Card::STANDARD_PROPERTIES + [TAGS_ATTRIBUTE, COMPLETED_CHECKLIST_ITEMS, INCOMPLETE_CHECKLIST_ITEMS]).collect(&:downcase)
    IGNORE= "ignore"
    TEXT_LIST_PROPERTY = 'managed text list property'
    ANY_TEXT_PROPERTY = 'any text property'
    TREE_RELATIONSHIP_PROPERTY = 'tree relationship property'
    CARD_RELATIONSHIP_PROPERTY = 'card relationship property'
    TREE_BELONGING_PROPERTY = 'whether belongs to this tree'
    NUMERIC_LIST_PROPERTY = 'managed number list property'
    ANY_NUMERIC_PROPERTY = 'any number property'
    USER_PROPERTY = 'user property'
    DATE_PROPERTY = 'date property'
    MISSING = '-'

    CARD_MAPPINGS_TO_REPLACE = %w(name description number type)
    PROPERTY_MAPPINGS_TO_REPLACE = [ANY_NUMERIC_PROPERTY, ANY_TEXT_PROPERTY, DATE_PROPERTY, NUMERIC_LIST_PROPERTY, TEXT_LIST_PROPERTY]
  
    def initialize(header_cells, reader)
      @reader = reader
      @header_cells = header_cells
      @tree_configuration = @reader.tree_configuration
      @mappings = if @reader.original_mapping_overrides
        @header_cells.collect do |header_cell| 
          Mapping.from_override(header_cell, @reader.original_mapping_overrides, @header_cells.index(header_cell), @reader.excel_content) 
        end
      else
        total = @header_cells.size
        @header_cells.inject([]) do |result, header_cell|
          yield header_cell, total, result.size if block_given?
          current_tree_columns = @tree_configuration ? @tree_configuration.tree_property_definitions.collect(&:name) : []
          cell_mapping = Mapping.from_heuristics(header_cell, Heuristics.new(@reader.excel_content), @header_cells.index(header_cell),  current_tree_columns)
          is_not_a_standard_header_cell = !STANDARD_MAPPINGS.ignore_case_include?(header_cell)
          if is_not_a_standard_header_cell && STANDARD_MAPPINGS.ignore_case_include?(cell_mapping.import_as) && cell_mapping.import_as != 'description'
            the_standard_mapping_exists_in_header_cells = @header_cells.ignore_case_include?(cell_mapping.import_as)
            if result.collect(&:import_as).include?(cell_mapping.import_as) || the_standard_mapping_exists_in_header_cells
              cell_mapping.make_enum_property_mapping
            end
          end
          result << cell_mapping
        end
      end
    end
  
    def [](column)
      if mapping = @mappings.detect{ |mapping| mapping.original == column }
        mapping.import_as
      end
    end
  
    def sort_by_index
      @mappings.sort_by(&:index)
    end
  
    def get_by_index(index)
      @mappings[index]
    end
  
    def index_of_attribute(attribute)
      if STANDARD_MAPPINGS.include?(attribute)
        indices = @mappings.select { |mapping| mapping.import_as == attribute }.collect(&:index)
        attribute == 'description' ? indices : indices.first
      else
        @mappings.detect { |mapping| mapping.attribute_name == attribute }.index
      end    
    end  
  
    def maps?(association)
      @mappings.any? { |mapping| mapping.maps?(association) }
    end  
  
    def create_property_definitions(project)
      custom_property_mappings.collect { |mapping| mapping.create_property_definition(project) }
    end  
  
    def to_attributes(values)
      result = {}
      %w(name number tags).each do |attribute|
        has_attribute_with_valid_value = !index_of_attribute(attribute).blank? && !values[index_of_attribute(attribute)].blank? && values[index_of_attribute(attribute)] != MISSING
        result[attribute] = values[index_of_attribute(attribute)] if has_attribute_with_valid_value
      end
      result['description'] = description_from(values) if index_of_attribute('description').any?
      result.merge!(checklist_items(values))
      # merge all card types with custom property values first and then merge with the result hash,
      # otherwise it will change order of iteration of keys in Hash on JRuby
      result.merge(custom_property_values_in(values).merge(all_card_types_in(values)))
    end

    def custom_property_mappings
      @mappings.select { |m| [TEXT_LIST_PROPERTY, USER_PROPERTY, ANY_TEXT_PROPERTY, DATE_PROPERTY, ANY_NUMERIC_PROPERTY, NUMERIC_LIST_PROPERTY].include?(m.import_as) }
    end
  
    def custom_property_values_in(values)
      enum_values = all_enumeration_values_in(values)
      user_logins = all_user_logins_in(values)
      free_text_values = all_free_text_property_values_in(values)
      free_numeric_values = all_free_numeric_property_values_in(values)
      dates = all_date_property_values_in(values)    
      tree_belong_values = @reader.tree_import? ? all_tree_belong_values_in(values)  : {}
      tree_relationship_values = @reader.tree_import? ? all_tree_relationship_values_in(values) : {} 
      card_relationship_values = all_card_relationship_values_in(values)

      enum_values.merge(user_logins).merge(free_text_values).merge(free_numeric_values).merge(dates).merge(tree_belong_values).merge(tree_relationship_values).merge(card_relationship_values)
    end
  
    def all_enumeration_values_in(values)
      all_values_for_property_of_type(TEXT_LIST_PROPERTY, values).merge(all_values_for_property_of_type(NUMERIC_LIST_PROPERTY, values))
    end  
  
    def all_user_logins_in(values)
      all_values_for_property_of_type(USER_PROPERTY, values)
    end  
  
    def all_free_text_property_values_in(values)
      all_values_for_property_of_type(ANY_TEXT_PROPERTY, values)
    end
  
    def all_free_numeric_property_values_in(values)
      all_values_for_property_of_type(ANY_NUMERIC_PROPERTY, values)
    end
  
    def all_date_property_values_in(values)
      all_values_for_property_of_type(DATE_PROPERTY, values)
    end
  
    def all_card_types_in(values)
      all_values_for_property_of_type(Project.card_type_definition.name.downcase, values)
    end  
  
    def all_tree_belong_values_in(values)
      all_values = all_values_for_property_of_type(TREE_BELONGING_PROPERTY, values)
      { @tree_configuration.name => all_values.find_ignore_case(@tree_configuration.name)}
    end
  
    def all_tree_relationship_values_in(values)
      useful_property = @tree_configuration.relationships.collect(&:name)
      tree_relationship_values = all_values_for_property_of_type(TREE_RELATIONSHIP_PROPERTY, values)
    
      tree_relationship_values.keys.each do |property|
        tree_relationship_values.delete(property) unless useful_property.ignore_case_include?(property)
      end
      tree_relationship_values
    end

    def all_card_relationship_values_in(values)
      all_values_for_property_of_type(CARD_RELATIONSHIP_PROPERTY, values)
    end  

    def description_from(values)
      description_indices = @mappings.select { |m| m.import_as == 'description' }.collect(&:index)
      return values[description_indices[0]] if description_indices.size == 1
      description_indices.inject([]) do |desc, index|
        if values[index]
          desc << "h3. #{@header_cells[index]}"
          desc << "p(. #{values[index]}" 
        else
          desc 
        end
      end.join("\n\n")  
    end  
  
    private
  
    def all_values_for_property_of_type(property_type, values)
      Hash.new.tap do |result|
        @mappings.select {|mapping| mapping.import_as == property_type }.each do |mapping|
          value = values[index_of_attribute(mapping.attribute_name)]
          result[mapping.attribute_name] = value unless (value == MISSING || mapping.ignore?)
        end  
      end  
    end  
  
    #Mapping understands what one particular column's header cell is named and how the data for each subsequent row in that column will be imported. It uses Heuristics to determine what the column it represents looks like. Inferences made using Heuristics can be overridden.
    class Mapping
      class << self
        def from_override(cell, overrides, index, contents)
          original = from_heuristics(cell, Heuristics.new(contents), index)
          original.import_as = overrides[cell]
          original
        end
      
        def valid_property_name?(name)
          name =~ PropertyDefinition::VALID_NAME_PATTERN
        end  

        def substitute_display_names(value_pair)
          [substitute_display_name(value_pair.first), value_pair.last]
        end
      
        def substitute_display_name(label)
          if CARD_MAPPINGS_TO_REPLACE.include?(label)
            return "card #{label}"
          elsif PROPERTY_MAPPINGS_TO_REPLACE.include?(label)
            return "new #{label}"
          else
            return label
          end
        end
      
        def from_heuristics(cell, heuristics, index, current_tree_columns=[])
          if mapping_option = mappings_from_existing_property_definitions(cell)
            mapping_options = [mapping_option[0..1]]
            if current_tree_columns.ignore_case_include?(cell)          
              import_as = mapping_option[1]
            else
              import_as = mapping_option.last
            end
          else
            import_as = mappings_from_heuristics(cell, heuristics, index).last
            mapping_option_values = STANDARD_MAPPINGS.dup << TEXT_LIST_PROPERTY << ANY_TEXT_PROPERTY << DATE_PROPERTY << NUMERIC_LIST_PROPERTY << ANY_NUMERIC_PROPERTY
            mapping_options = mapping_option_values.inject([]) { |result, value| result << [value, value] }
          end
        
          self.new(:original => cell, :import_as => import_as, :index => index, :mapping_options => mapping_options)
        end
      
        def mappings_from_existing_property_definitions(cell)
          return [cell.downcase, cell.downcase, cell.downcase] if standard_mapping?(cell)
          return [IGNORE, IGNORE, IGNORE] if tracing_column?(cell)
          return ['description', 'description', 'description'] unless valid_property_name?(cell)
          return ['belongs to tree', TREE_BELONGING_PROPERTY, IGNORE] if tree_belonging_definition(cell)
          return ["existing property", CARD_RELATIONSHIP_PROPERTY, CARD_RELATIONSHIP_PROPERTY] if card_relationship_definition(cell)
          return ["existing tree property", TREE_RELATIONSHIP_PROPERTY, IGNORE] if tree_relationship_definition(cell)
          return ["existing property", ANY_NUMERIC_PROPERTY, ANY_NUMERIC_PROPERTY] if numeric_free_definition(cell)
          return ["existing property", ANY_TEXT_PROPERTY, ANY_TEXT_PROPERTY] if text_definition(cell)
          return ["existing property", DATE_PROPERTY, DATE_PROPERTY] if date_definition(cell)
          return ["existing property", USER_PROPERTY, USER_PROPERTY] if user_definition(cell)
          return ["existing property", NUMERIC_LIST_PROPERTY, NUMERIC_LIST_PROPERTY] if numeric_list_definition(cell)
          return [IGNORE, IGNORE, IGNORE] if calculated_definition(cell)
          return ["existing property", TEXT_LIST_PROPERTY, TEXT_LIST_PROPERTY] if enum_definition(cell)
          nil
        end  
      
        def mappings_from_heuristics(cell, heuristics, index)
          return ['number', 'number'] if heuristics.index_of(:only_first_column, :number_column) == index
          return ['name', 'name']if heuristics.index_of(:first_non_zero_column, :two_words) == index
          return [TEXT_LIST_PROPERTY, TEXT_LIST_PROPERTY] if heuristics.index_of(:all_columns_with_full_match, :empty).include?(index)
          return [ANY_NUMERIC_PROPERTY, ANY_NUMERIC_PROPERTY] if heuristics.index_of(:diverse_columns, :all_numeric).include?(index)
          return [NUMERIC_LIST_PROPERTY, NUMERIC_LIST_PROPERTY] if heuristics.index_of(:all_columns_with_full_match, :all_numeric).include?(index)
          return [DATE_PROPERTY, DATE_PROPERTY] if heuristics.index_of(:all_columns_with_full_match, :date_values).include?(index)          
          return [ANY_TEXT_PROPERTY, ANY_TEXT_PROPERTY] if heuristics.index_of(:diverse_columns, :less_than_three_words).include?(index)
          return ['description', 'description'] if (heuristics.index_of(:all_columns, :many_words) + heuristics.index_of(:all_columns, :verbose_content)).uniq.include?(index)
          return [TEXT_LIST_PROPERTY, TEXT_LIST_PROPERTY]
        end
      
        def tree_belonging_definition(column)
          property_definition(:tree_belonging_property_definitions, column)
        end  
      
        def card_relationship_definition(column)
          property_definition(:card_relationship_property_definitions_with_hidden, column)
        end
      
        def tree_relationship_definition(column)
          property_definition(:relationship_property_definitions, column)
        end
      
        def text_definition(column)
          property_definition(:text_property_definitions_with_hidden, column)
        end

        def date_definition(column)
          property_definition(:date_property_definitions_with_hidden, column)
        end      

        def user_definition(column)
          property_definition(:user_property_definitions_with_hidden, column)
        end

        def numeric_list_definition(column)
          property_definition(:numeric_list_property_definitions_with_hidden, column)
        end
      
        def numeric_free_definition(column)
          property_definition(:numeric_free_property_definitions_with_hidden, column)
        end
      
        def calculated_definition(column)
          property_definition(:calculated_property_definitions_with_hidden, column)
        end  
      
        def enum_definition(column)
          property_definition(:enum_property_definitions_with_hidden, column)
        end

        def standard_mapping?(column)
          STANDARD_MAPPINGS.ignore_case_include?(column)
        end

        def property_definition(definitions, column)
          Project.current.send(definitions).detect {|definition| definition.name.ignore_case_equal?(column) }
        end
      
        def tracing_column?(column)
          PredefinedPropertyDefinitions.tracing_column?(column)
        end
      end  
    
      def initialize(mapping)
        @mapping = mapping
      end
    
      def original
        @mapping[:original]
      end
    
      def import_as
        @mapping[:import_as]
      end  
    
      def index
        @mapping[:index]
      end  
    
      def ignore?
        import_as == IGNORE
      end 
    
      def disable?
        Mapping.tree_belonging_definition(original) || Mapping.tree_relationship_definition(original)
      end
        
      def mapping_options
        mapping_values = @mapping[:mapping_options].reject { |mapping_pair| mapping_pair.last == IGNORE }.map { |mapping_pair| Mapping.substitute_display_names(mapping_pair) }.collect { |mapping_pair| ["as #{mapping_pair.first}", mapping_pair.last]}
        mapping_values << ["(#{IGNORE})",IGNORE]
        Hash[*mapping_values.flatten]
      end
    
      def mapping_options_sorted
        mapping_options.to_a.sort_by{|e| e.first}
      end
    
      def import_as=(import_as)
        @mapping[:import_as] = import_as
      end
    
      def make_enum_property_mapping
        @mapping.merge!(:import_as => TEXT_LIST_PROPERTY)
      end  
    
      def create_property_definition(project)
        self.with_new_valid_prop_def_name project do |attr_name|
          if (import_as == ANY_TEXT_PROPERTY)
            project.create_text_definition(:name => attr_name)
          elsif (import_as == DATE_PROPERTY)
            project.create_date_definition(:name => attr_name)
          elsif (import_as == ANY_NUMERIC_PROPERTY)
            project.create_numeric_free_property_definition(:name => attr_name)
          elsif (import_as == NUMERIC_LIST_PROPERTY)
            project.create_numeric_list_property_definition(:name => attr_name)
          else  
            project.create_text_list_definition(:name => attr_name)
          end
        end
      end

      def with_new_valid_prop_def_name(project)
        return if STANDARD_MAPPINGS.include?(attribute_name)
        return if property_exists_or_is_reserved?(project, attribute_name)
      
        prop_def = EnumeratedPropertyDefinition.new(:project => project, :name => attribute_name)
        raise "Unable to create property #{attribute_name.bold}. Property #{prop_def.errors.full_messages.join(',')}." unless prop_def.valid?
        raise "Unable to create property #{attribute_name.gsub(/\n/, '\n').gsub(/\r/, '\r').bold}. It contains a newline or carriage return character." if has_newline?(attribute_name)
        yield attribute_name if block_given?
      end
    
      def maps?(association)
        association.keys.include?(original) && association[original] == @mapping[:import_as] unless ignore?
      end  
    
      def to_s
        @mapping.inspect
      end  
    
      def attribute_name
        STANDARD_MAPPINGS.include?(@mapping[:import_as]) ? @mapping[:import_as] : original
      end

      def checklist_items?
        [Mappings::INCOMPLETE_CHECKLIST_ITEMS, Mappings::COMPLETED_CHECKLIST_ITEMS].include?(import_as)
      end

      private
    
      def property_exists_or_is_reserved?(project, attribute_name)
        pd = project.reload.find_property_definition_or_nil(attribute_name, :with_hidden => true)
        return false unless pd
        !pd.predefined? || (pd.predefined? && pd.excel_importable?)
      end
    
      def has_newline?(attribute_name)
        attribute_name.strip =~ /[\n\r]/
      end
    end

    def checklist_items(values)
      [INCOMPLETE_CHECKLIST_ITEMS, COMPLETED_CHECKLIST_ITEMS].inject({}) do |checklist_items_mapping, checklist_item_type|
        checklist_item_type_mapping = @mappings.find { |mapping| mapping.import_as == checklist_item_type }

        if checklist_item_type_mapping
          checklist_items_text = values[checklist_item_type_mapping.index] || ''
          checklist_items_mapping[checklist_item_type] = checklist_items_text.split(/\r|\n/).reject(&:blank?)
        end

        checklist_items_mapping
      end
    end
  end
end
