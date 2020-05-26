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

module CardTreeMethods

  def revise_belonging_tree_structure
    return if @original_values_of_changed_properties.blank?
    project.tree_configurations.each do |config|
      if original_values  = @original_values_of_changed_properties[config.name]
        config.revise_tree_structure(self, original_values)
      end
    end
    @original_values_of_changed_properties.clear
  end

  def usages_as_tree_relationship_property_in_transitions(card_type_name)
    return [] if new_record?
    relationship_properties_of_my_type = project.relationship_property_definitions.select { |pd| pd.valid_card_type.name == card_type_name }
    my_values_in_property_definitions = relationship_properties_of_my_type.collect { |pd| PropertyValue.create_from_db_identifier(pd, self.id) }
    project.transitions.select { |t| my_values_in_property_definitions.any? { |prop_value| t.uses?(prop_value) } }
  end

  def property_definitions_without_tree
    card_type.property_definitions_with_hidden.reject(&:tree_special?)
  end

  def tree_configuration_ids
    tree_belongings.map(&:tree_configuration_id)
  end

  def repair_trees
    self.property_definitions_with_value.each do |prop_def|
      prop_def.add_card_to_tree(self) if prop_def.respond_to?(:add_card_to_tree)
    end
  end

  def validate_tree_fully= (validate_tree_fully)
    @validate_tree_fully = validate_tree_fully
  end

  def validate_tree_fully?
    @validate_tree_fully ||= false
  end

  # Accepts property_params with url_identifiers
  # Return property_params with url_identifiers
  def honor_trees_for(property_params)
    params_without_project_variables = property_params.reject { |key, value| ProjectVariable.is_a_plv_name?(value) }
    values = PropertyValueCollection.from_params(project, params_without_project_variables, {:method => 'get'}).values
    tree_prop_values = values.select {|value| value.property_definition.is_a?(TreeRelationshipPropertyDefinition) }
    result = {}
    tree_prop_values.group_by { |value| value.property_definition.tree_configuration }.each do |tree, values|
      sorted_values = values.sort_by {|value| value.property_definition.position }
      lowest_level_prop_value = sorted_values.select(&:value).last || sorted_values.first
      relationship = lowest_level_prop_value.property_definition
      result[relationship.name] = lowest_level_prop_value.url_identifier
      prop_type = lowest_level_prop_value.property_type
      parent_card = lowest_level_prop_value.value || self
      tree.relationship_map.each_before(relationship.valid_card_type) do |r|
        result[r.name] = prop_type.db_to_url_identifier(r.db_identifier(parent_card))
      end
      tree.relationship_map.each_after(relationship.valid_card_type) { |r| result[r.name] = nil }
    end
    property_params.merge(result)
  end

  # please don't tweak this method without testing performance
  def each_aggregate_to_compute_for_tree(tree_configuration, &block)
    node = self
    parent_nodes = tree_configuration.find_all_ancestor_cards_without_validation(self)
    if previous_version = previous_version_or_nil
      parent_nodes.concat(tree_configuration.find_all_ancestor_cards_without_validation(previous_version))
    end
    node_property_definitions = node.card_type.property_definitions_with_hidden_without_order
    ([node] + parent_nodes).uniq.compact.each do |candidate_node|
      candidate_node.card_type.aggregate_property_definitions.each do |aggregate_def|
        if aggregate_def.tree_configuration_id == tree_configuration.id
          yield(candidate_node, aggregate_def)
        end
      end
    end
  end

  def temp_store_tree_property_value(tree_name, property_value)
    @original_values_of_changed_properties ||= {}
    @original_values_of_changed_properties[tree_name] ||= []
    @original_values_of_changed_properties[tree_name].delete_if {|value| value.property_definition == property_value.property_definition}
    @original_values_of_changed_properties[tree_name] << property_value
  end

  def can_have_children?(tree_configuration)
    leaf_card_type = tree_configuration.relationships.last.card_types.collect(&:name)

    is_on_tree_sql = %{
      SELECT
        COUNT(*) AS on_tree, 0 AS is_not_leaf_type
      FROM
        tree_configurations tc
        JOIN tree_belongings b ON (tc.id = b.tree_configuration_id AND b.card_id = ?)
      WHERE
        tc.id = #{tree_configuration.id}
        AND tc.project_id = #{project.id}
    }

    is_not_of_leaf_type_sql = %{
      SELECT
        0 AS on_tree, COUNT(*) AS is_not_leaf_type
      FROM
        #{Card.quoted_table_name} c
      WHERE
        c.id = #{self.id}
        AND c.project_id = #{project.id}
        AND LOWER(c.card_type_name) <> LOWER(?)
    }

    can_be_parent_sql = %{
      SELECT
        SUM(parents.on_tree) AS on_tree
        , SUM(parents.is_not_leaf_type) AS is_not_leaf_type
      FROM
        (#{is_on_tree_sql}
        UNION
        #{is_not_of_leaf_type_sql}) parents
    }

    res = ActiveRecord::Base.connection.select_one(SqlHelper.sanitize_sql(can_be_parent_sql, self.id, leaf_card_type))
    res['on_tree'].to_i == 1 && res['is_not_leaf_type'].to_i == 1
  end

  def has_children?(tree_configuration)
    relationship = tree_configuration.find_relationship(self.card_type)
    return false unless relationship

    has_children_sql = %{
      SELECT
        COUNT(*) AS child_count
      FROM
        #{Card.quoted_table_name} c
      WHERE
        c.#{relationship.column_name} = #{self.id}
        AND c.project_id = #{project.id}
    }

    res = ActiveRecord::Base.connection.select_one(has_children_sql)
    res['child_count'].to_i > 0
  end

  def remove_tree_belonging_on_card_type_name_attribute_changed
    #the next line uses a blank? check because on a new card, the initial value for an unpopulated attribute on MySQL is "" not nil as with PostgreSQL.
    #hence checking it with return unless @old_card_type_name would cause scenario_66 to fail on MySQL
    return if @old_card_type_name.blank?
    return if @old_card_type_name.ignore_case_equal?(self.card_type_name)
    old_card_type = project.find_card_type(@old_card_type_name)
    tree_configurations.each { |tc| tc.handle_card_type_change(self, old_card_type) }
  end

  def nil_out_tree_relationships_if_card_type_is_only_thing_changed(property_params)
    return property_params unless property_params.keys.collect { |key| key.to_s.downcase } == ['type']
    return property_params if self.card_type_name.ignore_case_equal?(property_params.values.first)
    tree_configurations.each do |tree_configuration|
      relationship_names = tree_configuration.relationships.collect(&:name)
      nil_out_settings = relationship_names.inject({}) { |acc, name| acc[name] = nil; acc }
      property_params.merge!(nil_out_settings)
    end
    property_params
  end


end
