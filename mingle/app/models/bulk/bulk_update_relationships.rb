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

module Bulk
  class BulkUpdateRelationships
    include SqlHelper, CardsChanger
    attr_reader :errors

    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
      @errors = []
    end
  
    def update_relationship_property(relationship, card)
      tree_configuration = relationship.tree_configuration
      return unless valid?(relationship, card, tree_configuration)
      card_types_below = tree_configuration.card_types_after(relationship.valid_card_type)
    
      ensure_given_card_is_on_tree(tree_configuration, card) unless card.nil?

      bulk_update_tool = BulkUpdateTool.new(@project)
      #update parents before move
      bulk_update_tool.compute_aggregates(tree_configuration, @card_id_criteria)

      bulk_relationship_update = CardTypeSpecificBulkRelationshipUpdate.new(@project, tree_configuration, relationship, card, @card_id_criteria)
      card_types_below.each do |card_type|
        bulk_relationship_update.run(card_type)
      end

      #update parents after move
      bulk_update_tool.compute_aggregates(tree_configuration, @card_id_criteria)
      notify_cards_changing(@project)
    end
  
    def on_card_type_change(new_card_type_name)
      BulkCardTypeChange.new(@project, @card_id_criteria).run(new_card_type_name)
    end
  
    private
  
    def ensure_given_card_is_on_tree(tree_configuration, card)
      tree_configuration.add_child(card) unless tree_configuration.include_card?(card)
    end
  
    def card_types_from_selected_cards
      BulkUpdateTool.new(@project).card_types_from_selected_cards(@card_id_criteria)
    end
  
    def valid?(relationship, card, tree_configuration)
      if !card.nil? && relationship.valid_card_type != card.card_type
        self.errors << "Property #{relationship.name.bold} must be set to a card of type #{relationship.valid_card_type.name.bold} and so cannot be set to card #{card.name.bold}, which is a #{card.card_type.name.bold}."
        return false
      end
      
      card_types_below = tree_configuration.card_types_after(relationship.valid_card_type)
      card_types_from_selected_cards.each do |ct|
        unless card_types_below.include?(ct)
          self.errors << "One or more selected cards has card type #{ct.name.bold} and property #{relationship.name.bold} does not apply to it."
          return false
        end
      end
      
      true
    end
  
  end

  class CardTypeSpecificBulkRelationshipUpdate
    include SecureRandomHelper, SqlHelper
  
    def initialize(project, tree_configuration, relationship, card, card_id_criteria)
      @project = project
      @tree_configuration = tree_configuration
      @relationship = relationship
      @card = card
      @card_id_criteria = card_id_criteria
      @bulk_update_tool = BulkUpdateTool.new(@project)
    end
  
    def run(card_type)
      TemporaryIdStorage.with_session do |session_id|
        @selected_cards_and_children_session_id = session_id
        @changed_card_ids_condition = "id IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{@selected_cards_and_children_session_id}')"
        fill_selected_cards_and_children_table(card_type)
        
        @bulk_update_tool.card_versioning.create_card_versions("?.id IN (#{cards_that_will_change(card_type)})", setters(card_type))
        update_cards(card_type)
        ensure_cards_are_in_tree
        update_search_index
      end
    
    end
  
    private
  
    def fill_selected_cards_and_children_table(card_type)
      relationship_pointing_to_type = @tree_configuration.find_relationship(card_type)
      is_last_card_type = relationship_pointing_to_type.nil?
      cards_of_this_type_that_will_change = cards_that_will_change(card_type)
      
      if is_last_card_type
        connection.insert_into(:table => TemporaryIdStorage.table_name,
                               :insert_columns => ["session_id", "id_1"],
                               :select_columns => ["'#{@selected_cards_and_children_session_id}'", "id"],
                               :from => "(#{cards_of_this_type_that_will_change}) #{connection.alias_if_necessary_as('x')}",
                               :generate_id => false)
      else
        
        connection.insert_into(:table => TemporaryIdStorage.table_name,
                               :insert_columns => ["session_id", "id_1"],
                               :select_columns => ["'#{@selected_cards_and_children_session_id}'", "id"],
                               :from => Card.quoted_table_name,
                               :where => %{
                                          (#{Card.quoted_table_name}.id IN (#{cards_of_this_type_that_will_change})) OR
                                          (#{Card.quoted_table_name}.#{relationship_pointing_to_type.column_name} IN (#{cards_of_this_type_that_will_change}) AND
                                           #{Card.quoted_table_name}.id NOT IN (#{selected_cards}))
                               },
                               :generate_id => false)
      end
    end
  
    def card_will_change_condition(selected_cards_of_this_type, card_type)
      tree_relationships = @tree_configuration.relationships
    
      relationship_does_not_already_point_to_card = not_equal_condition("#{Card.quoted_table_name}.#{@relationship.column_name}", @card ? @card.id : nil)
      card_is_selected = "#{Card.quoted_table_name}.id IN (#{selected_cards_of_this_type})"
    
      card_types_above = @tree_configuration.card_types_before(card_type)
      ascendant_relationships = tree_relationships.select { |rel| card_types_above.include?(rel.valid_card_type) }
      ascendant_is_selected = ascendant_relationships.collect do |rel|
        "#{Card.quoted_table_name}.#{rel.column_name} IN (#{selected_cards_of_type(rel.valid_card_type)})"
      end.join(" OR ")
      "#{relationship_does_not_already_point_to_card} OR (#{card_is_selected} AND (#{ascendant_is_selected}))"
    end
  
    def setters(card_type)
      if @card.nil?
        nullify_relationships_above_card_and_below_changed_relationships_parent(card_type)
      else
        setters_one = make_selected_cards_have_no_parents_and_propagate_same_values_to_children(card_type)
        setters_two = move_selected_cards_and_children_beneath_card
        setters_one.merge(setters_two)
      end
    end
  
    def make_selected_cards_have_no_parents_and_propagate_same_values_to_children(card_type)
      relationships_before = @tree_configuration.card_types_before(card_type).collect { |ct| @tree_configuration.find_relationship(ct) }
      setters = {}
      relationships_before.each { |rel| setters[rel.column_name] = "NULL"}
      setters
    end
  
    def move_selected_cards_and_children_beneath_card
      card_types_above = @tree_configuration.card_types_before(@relationship.valid_card_type)
      relationships_above = card_types_above.collect { |ct| @tree_configuration.find_relationship(ct) }
    
      setters = {}
      relationships_above.each do |rel|
        setters[rel.column_name] = ( (@card && rel.value(@card)) ? rel.value(@card).id.to_s : 'NULL')
      end
    
      setters[@relationship.column_name] = @card ? @card.id.to_s : 'NULL'
      setters
    end
  
    def nullify_relationships_above_card_and_below_changed_relationships_parent(card_type)
      relationships_above_selected_card = @tree_configuration.card_types_before(card_type).collect { |ct| @tree_configuration.find_relationship(ct) }
      relationships_to_keep = @tree_configuration.card_types_before(@relationship.valid_card_type).collect { |ct| @tree_configuration.find_relationship(ct) }
      relationships_to_nullify = relationships_above_selected_card - relationships_to_keep
    
      setters = {}
      relationships_to_nullify.each { |rel| setters[rel.column_name] = "NULL"}
      setters
    end
  
    def update_cards(card_type)
      our_setters = setters(card_type).collect { |col, val| "#{col} = #{val}"}
      connection.bulk_update(:table => Card.table_name,
                             :set => %{ #{our_setters.join(',')},
                                        version = version + 1,
                                        modified_by_user_id = #{User.current.id},
                                        updated_at = #{connection.datetime_insert_sql(Clock.now)} },
                             :for_ids => "IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{@selected_cards_and_children_session_id}')")
    end
  
    def selected_cards_of_type(card_type)
      SqlHelper::sanitize_sql("SELECT id FROM #{Card.quoted_table_name} 
         WHERE id #{@card_id_criteria.to_sql} AND
         LOWER(card_type_name) = ?", card_type.name.downcase)
    end
  
    def selected_cards
      %{ SELECT id FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql} }
    end
  
    def ensure_cards_are_in_tree
      connection.insert_into(:table => TreeBelonging.table_name,
                             :insert_columns => ["tree_configuration_id", "card_id"],
                             :select_columns => [@tree_configuration.id, "id"],
                             :from => Card.quoted_table_name,
                             :where => %{ id IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{@selected_cards_and_children_session_id}') AND
                                          id NOT IN (SELECT card_id FROM #{TreeBelonging.table_name} WHERE tree_configuration_id = #{@tree_configuration.id}) })
    end
  
    def cards_that_will_change(card_type)
      selected_cards_of_this_type = selected_cards_of_type(card_type)
      selected_cards_of_this_type + " AND " + card_will_change_condition(selected_cards_of_this_type, card_type)
    end
  
    def update_search_index
      @bulk_update_tool.update_search_index(@changed_card_ids_condition)
    end
  
  end

  class BulkCardTypeChange
    include SqlHelper
  
    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
      @bulk_update_tool = BulkUpdateTool.new(@project)
    end
  
    def run(card_type_name)
      selected_cards_that_will_have_type_changed = sanitize_sql %{
        SELECT #{Card.quoted_table_name}.id
        FROM #{Card.quoted_table_name}
        WHERE LOWER(#{Card.quoted_table_name}.card_type_name) != ? AND
        #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql}
      }, card_type_name.downcase
    
      number_of_cards_to_remove_from_trees = select_value("SELECT COUNT(*) FROM #{Card.quoted_table_name} WHERE id IN (#{selected_cards_that_will_have_type_changed})")
      return if number_of_cards_to_remove_from_trees.to_num == 0
    
      card_types = BulkUpdateTool.new(@project).card_types_from_selected_cards(CardIdCriteria.new("IN (#{selected_cards_that_will_have_type_changed})"))
      card_types.each { |card_type| move_children_up(selected_cards_that_will_have_type_changed, card_type) }
      remove_cards_from_tree(selected_cards_that_will_have_type_changed, card_type_name)
    end
  
    def remove_card_from_tree_properties_and_values
      relationships_to_nil_out = @project.relationship_property_definitions
      relationships_to_nil_out.empty? ? {} : relationships_to_nil_out.inject({}) { |setters, rel| setters[rel.name] = PropertyValue::NOT_SET_VALUE; setters }
    end
  
    private
  
    def move_children_up(all_selected_cards_that_will_have_type_changed, current_card_type)
      selected_cards_of_current_card_type_that_will_be_removed_from_trees = sanitize_sql %{
        SELECT #{Card.quoted_table_name}.id
        FROM #{Card.quoted_table_name}
        WHERE LOWER(#{Card.quoted_table_name}.card_type_name) = ? AND
        #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql}
      }, current_card_type.name.downcase
    
      tree_configurations_with_at_least_one_selected_card = %{
        SELECT #{TreeBelonging.table_name}.tree_configuration_id
        FROM #{TreeBelonging.table_name}
        WHERE #{TreeBelonging.table_name}.card_id IN (#{selected_cards_of_current_card_type_that_will_be_removed_from_trees})
      }
    
      all_relationships_that_could_point_to_a_selected_card = %{
        SELECT #{PropertyDefinition.table_name}.id
        FROM #{PropertyDefinition.table_name}
        WHERE #{PropertyDefinition.table_name}.type = 'TreeRelationshipPropertyDefinition' AND
        #{PropertyDefinition.table_name}.valid_card_type_id = #{current_card_type.id} AND
        #{PropertyDefinition.table_name}.tree_configuration_id IN (#{tree_configurations_with_at_least_one_selected_card})
      }
    
      relationships_to_nil_out = TreeRelationshipPropertyDefinition.find(:all, :conditions => ["id IN (#{all_relationships_that_could_point_to_a_selected_card})"])
    
      if relationships_to_nil_out.any?
        setters_hash = relationships_to_nil_out.inject({}) { |setters_hash, rel| setters_hash[rel.column_name] = "NULL"; setters_hash }.merge("version" => "version + 1")
        setters_array = relationships_to_nil_out.collect { |rel| "#{rel.column_name} = NULL" } + ["version = version + 1"]
      
        card_is_descendent_of_a_removed_card = relationships_to_nil_out.collect do |rel|
          "#{Card.quoted_table_name}.#{rel.column_name} IN (#{selected_cards_of_current_card_type_that_will_be_removed_from_trees})"
        end.join(' OR ')
        card_is_not_a_removed_card = "#{Card.quoted_table_name}.id NOT IN (#{all_selected_cards_that_will_have_type_changed})"
        conditions = "(#{card_is_descendent_of_a_removed_card}) AND (#{card_is_not_a_removed_card})"
      
        @bulk_update_tool.card_versioning.create_card_versions(conditions, setters_hash)
        @bulk_update_tool.update_search_index(conditions)
        @bulk_update_tool.update_card_table(:set => setters_array.join(', '), :where => conditions)
      end
    end
  
    def remove_cards_from_tree(selected_cards_that_will_have_type_changed, card_type_name)
      delete_cards_from_tree_belongings(selected_cards_that_will_have_type_changed, card_type_name)
      # we would normally nullify all relationship properties here, but we do this in card_selection instead so that only one version is created
    end
  
    def delete_cards_from_tree_belongings(selected_cards_that_will_have_type_changed, card_type_name)
      card_type_ids_for_tree = %{
        SELECT valid_card_type_id FROM #{PropertyDefinition.table_name} WHERE tree_configuration_id = tree_configuration.id AND valid_card_type_id IS NOT NULL
        UNION
        SELECT card_type_id FROM #{PropertyTypeMapping.table_name} WHERE property_definition_id IN (SELECT id FROM #{PropertyDefinition.table_name} WHERE tree_configuration_id = tree_configuration.id)
      }
      new_card_type_id = sanitize_sql %{ SELECT #{CardType.table_name}.id FROM #{CardType.table_name} WHERE LOWER(#{CardType.table_name}.name) = ? AND #{CardType.table_name}.project_id = ?}, card_type_name.downcase, @project.id
    
      trees_that_do_not_have_the_card_type = sanitize_sql %{
        SELECT tree_configuration.id FROM #{TreeConfiguration.table_name} tree_configuration
        WHERE (#{new_card_type_id}) NOT IN (#{card_type_ids_for_tree})
      }
    
      sql = %{
        DELETE FROM #{TreeBelonging.table_name}
        WHERE #{TreeBelonging.table_name}.card_id IN (#{selected_cards_that_will_have_type_changed}) AND
          #{TreeBelonging.table_name}.tree_configuration_id IN (#{trees_that_do_not_have_the_card_type})
       }
    
      execute(sql)
    end
  
  end

end
