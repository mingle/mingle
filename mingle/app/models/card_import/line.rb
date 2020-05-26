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
  class Line
    attr_accessor :values, :headers, :project, :ignore_fields, :row_number
  
    def initialize(line, headers, project, ignores, row_number)
      self.values = line
      self.headers = headers
      self.project = project
      self.ignore_fields = ignores
      self.row_number = row_number
    end
  
    def number
      attributes['number']
    end
  
    def card_type
      project.find_card_type(attributes['type'])
    end
  
    def attributes
      headers.attributes_for(values)
    end
    memoize :attributes
  
    def translate(tree_configuration=nil)
      attributes = @headers.attributes_for(values)
      card = new_or_existing_card_with_number(delete_from_hash(attributes, 'number'))
      card.assign_number unless card.number
      card.assign_name unless find_key(attributes, 'name') || @ignore_fields.collect(&:downcase).include?('name') || !card.new_record?

      if @headers.tags_column_defined?
        tag_list = delete_from_hash(attributes, 'tags')
        card.tag_with(tag_list)
      end
    
      if card.new_record?
        type_name, type_value = attributes.detect {|name, value| name.downcase == 'type'}
        set_property_value(card, 'Type', type_value) if type_value
        card.set_defaults
      end

      if @headers.checklist_items_defined?
        checklist_items_mappings = [Mappings::INCOMPLETE_CHECKLIST_ITEMS, Mappings::COMPLETED_CHECKLIST_ITEMS]
        card.checklist_items.destroy_all unless card.new_record?
        card.add_checklist_items(attributes.slice(*checklist_items_mappings))
        attributes.delete_if { |key, _| checklist_items_mappings.include?(key.downcase) }
      end

      invalid_users = {} 
    
      in_current_tree = in_current_tree?(attributes, tree_configuration)
                     
      attributes.each do |name, value|
        begin
          if ['name', 'description'].include?(name.downcase)
            card.send("#{name.downcase}=", value) unless value.blank? 
          else 
            set_property_value(card, name, value, in_current_tree)
          end
        rescue CardImport::InvalidUserError
          (invalid_users[name] ||= []) << value
        end    
      end

      card.tap do |c|
        next if invalid_users.empty?
        invalid_columns = invalid_users.keys
        invalid_values = invalid_users.values.flatten
        error_message = "Error with #{invalid_users.keys.sort.to_sentence} #{invalid_columns.size > 1 ? 'columns' : 'column'}. "
        error_message << "Project team does not include #{invalid_values.sort.to_sentence}. "
        error_message << "User property values must be set to current team member logins."
        c.errors.add_to_base(error_message)
      end  
    end 
  
    def in_current_tree?(attributes, tree_configuration = nil)
      return false unless tree_configuration
      tree_name, tree_value = attributes.detect{|name, value| name.ignore_case_equal?(tree_configuration.name)}
      tree_belong_property_defintion = tree_configuration.tree_belong_property_definition
      tree_belong_property_defintion.property_type.parse_import_value(tree_value)
    end

    def set_property_value(card, name, value, in_current_tree = false)
      begin
        definition = @project.find_property_definition(name, :with_hidden => true)
        # The property value will be ignored if the definition is transition only and the card is not new record
        return if definition.transition_only_for_updating_card?(card)
        return if !in_current_tree && definition.is_a?(TreeRelationshipPropertyDefinition)
        options = {}
        options.merge!({:just_change_version => true}) if definition.is_a?(TreeBelongingPropertyDefinition)
        return definition.update_card(card, nil, options) if value.blank?
        property_type = definition.property_type
        definition.update_card(card, property_type.parse_import_value(value), options)
      rescue ::PropertyDefinition::InvalidValueException => e
        raise CardImport::CardImportException.new(e.message)
      end    
    end  

    def new_or_existing_card_with_number(number)
      number =~ /^\#*(\d+)$/
      card = $1 ? @project.cards.find_or_initialize_by_number($1.to_i) : Card.new
      card.project = @project
      card.card_type = @project.card_types.first unless card.card_type
      card
    end

    # keys must be strings, lookup is case-insensitive
    def delete_from_hash(hash, key) 
      key = find_key(hash, key)
      hash.delete(key) if key
    end

    # keys must be strings, lookup is case-insensitive
    def find_key(hash, key)
      hash.keys.detect{|k| k.downcase == key}
    end
  end

end
