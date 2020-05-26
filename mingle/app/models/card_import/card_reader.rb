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

#CardReader understands how to interpret a tab-seperated string, as data for cards. It understands this in light of the structure of the project the data is being imported into.
#Behaviour related to understanding the first row, which is a special row called the Header is delegated to the Header class.
#The actual mechanics of translating a particular row of data using the headers, into a card, is delegated to the Line class.
module CardImport
  class CardReader
    include Enumerable
    attr_reader :headers, :excel_content, :tree_configuration, :project

    def initialize(project, excel_content, mapping_overrides=nil, user=User.current, tree_configuration = nil)
      @excel_content = excel_content
      raise CardImport.no_content if @excel_content.blank?
      @project = project
      @user = user
      @tree_configuration = tree_configuration
    
      yield "Importing excel content...", 100, 1 if block_given?
    
      header_cells = @excel_content.cells.header
      @mapping_overrides = if mapping_overrides.is_a?(Array)
        Hash[*header_cells.dup.zip(mapping_overrides).flatten]
      else
        mapping_overrides
      end
    
      @headers = CardImport::Header.new(header_cells || [], self) do |header_cell, total, completed|
        yield "Analysing header #{header_cell.italic} (Completed #{completed} of #{total})", total, completed if block_given?
      end    
      @ignore_fields = (@mapping_overrides.nil?)? [] : @mapping_overrides.collect {|header| header[0] if header[1] == CardImport::Mappings::IGNORE}.compact
    end                                               
  
    def validate
      if @mapping_overrides
        ['name', 'number', 'tags', 'type'].each do |import_as|
          raise CardImport.multiple_columns_marked_as(CardImport::Mappings::Mapping.substitute_display_name(import_as)) if @mapping_overrides.values.select{|value| import_as == value}.size > 1
        end
      end
      verify_card_numbers
      check_field_lengths
      raise CardImport.new_type_but_no_authorization(@headers.new_types) if @headers.has_new_types && !@project.admin?(@user)
      raise CardImport.duplicate_header if @headers.has_duplicates
      @headers.validate_prop_def_names_with(@project) do |errors|
        raise CardImport::CardImportException.new(errors.join("<br/>"))
      end
    end
  
    def check_field_lengths
      attribute_length_limit = Card.columns_hash['name'].limit
      @too_long = {}
      @excel_content.lines(@project, @ignore_fields, @headers).each do |line|
        attributes = line.attributes
        attributes = attributes.reject{|name, value| name.downcase == 'description'}
        attributes.each do |attr_name, value|
          if value and value.length > attribute_length_limit
            @too_long[line.row_number] ||= []
            @too_long[line.row_number] << (attr_name == 'name' ? 'Name' : attr_name)
          end
        end
      end
      raise CardImport.fields_exceed_limit(@too_long) if @too_long.any?
    end
  
    def warnings
      result = []
      result << CardImport::DUPLICATE_HEADER_ERROR if @headers.has_duplicates
      result << @headers.tree_property_warning
      result << @headers.missing_name_warning
      result << @headers.missing_type_warning
      result << @headers.protected_cell_warnings
      result << @headers.formula_columns_warning
      result << @headers.aggregate_columns_warning
      result += tree_column_groups.collect(&:incomplete_warning)
      result.compact.join(MingleFormatting::MINGLE_LINE_BREAK_MARKER).strip
    end  
  
    def update_schema
      @new_property_definitions = @headers.create_property_definitions(@project)
      @project.reload.update_card_schema
      @headers
    end
  
    def each(&block)
      card_saver = Proc.new { |card, row_number| yield(card) }
      each_with_row_number(&card_saver)
    end
  
    def each_with_row_number(&block)
      # create all missing values and types
      @headers.all_enumeration_values_and_card_types.each do |property_name, values|
        values.smart_sort.each do |value|
          @project.find_property_definition(property_name, :with_hidden => true).create_value_if_not_exist(value)
        end
      end
    
      max_number = @excel_content.lines(@project, @ignore_fields, @headers).collect { |line| line.number.to_i }.max
      @project.reset_card_number_sequence_to(max_number)
    
      if tree_import?
        @excel_content.lines(@project, @ignore_fields, @headers).each_sorted_by_card_type(@tree_configuration) { |line| yield(read(line), line.row_number) }
      else
        @excel_content.lines(@project, @ignore_fields, @headers).each { |line| yield(read(line), line.row_number) }
      end
    end
  
    def size
      @excel_content.size
    end  

    def [](index)
      read(@excel_content.lines(@project, @ignore_fields, @headers)[index])
    end  
  
    def verify_card_numbers
      return unless @headers.number_column_defined?
      card_number_list = []
      @excel_content.lines(@project, @ignore_fields, @headers).each do |line|
        card_number = line.number
        next if card_number.blank?
        unless card_number =~ /^\#*(\d+)$/
          raise CardImport.invalid_card_number(card_number)
        end
        if card_number_list.include?($1)
          raise CardImport.duplicate_cards_numbered(card_number)
        end

        if $1.to_i > Project::MAX_NUMBER
          raise CardImport.card_number_too_large(card_number)
        end  
        card_number_list << $1
      end   
    end
  
    def mapping_overrides
      @mapping_overrides ||= (@headers.mappings.sort_by_index.inject({}) do |mappings, import_mapping|
        mappings[import_mapping.original] = import_mapping.import_as
        mappings
      end)
    end
  
    def original_mapping_overrides
      @mapping_overrides
    end
     
    def protected_property_definition_names
      @project.property_definitions.select{|prop_def| prop_def.transition_only}.collect(&:name)
    end

    def tree_property_definitions
      @project.property_definitions.select{|prop_def| prop_def.type == "TreeRelationshipPropertyDefinition"}
    end
  
    def tree_import?
      @tree_configuration && current_column_group.completed?
    end
  
    def available_trees
      completed_tree_column_groups.collect(&:tree_config)
    end
  
    def tree_column_groups
      tree_columns = @headers.columns.select(&:tree_column?)
      tree_columns.group_by(&:tree_config).collect{ |pair| CardImport::TreeColumnGroup.new(*pair) }
    end
  
    def current_column_group
      tree_column_groups.detect{ |group| group.tree_config == @tree_configuration }
    end
  
    def completed_tree_column_groups
      tree_column_groups.select(&:completed?)
    end
      
    def incompleted_tree_column?(index)
      incompleted_tree_column_groups.collect(&:indexes).flatten.include?(index)
    end
    
    def incompleted_tree_column_groups
      tree_column_groups - completed_tree_column_groups
    end
  
    private  
    def read(line)
      card = line.translate(@tree_configuration)
      ensure_new_property_definitions_available_to_card_type(card)
      card
    end  
  
    def ensure_new_property_definitions_available_to_card_type(card)
      @new_property_definitions.each do |new_prop_def|
        unless card.property_value(new_prop_def).not_set? || new_prop_def.has_card_type?(card.card_type)
          card.card_type.add_property_definition new_prop_def
          @project.card_types.reload
        end
      end
    end  

  end
end
