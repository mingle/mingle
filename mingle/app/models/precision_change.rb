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

class PrecisionChange
  include SqlHelper, SecureRandomHelper
  
  def self.create_change(project, old_value, new_value)
    if new_value > old_value
      PrecisionChange::Increase.new(project, old_value, new_value)
    else
      PrecisionChange::Decrease.new(project, old_value, new_value)
    end
  end

  def initialize(project, old_value, new_value)
    @project, @old_precision, @new_precision = project, old_value, new_value
  end
  
  def run
    update_cards
    update_transitions
    update_card_defaults
    delete_aliased_managed_numeric_values
    adjust_card_list_views
    adjust_history_subscriptions
    update_precision_of_calculated_numbers
    update_project_variables
  end
  
  private
  
  def update_precision_of_calculated_numbers
    set_conditions = all_calculated_property_definitions.inject([]) do |result, calculated_property_definition|
      next result unless calculated_property_definition.numeric?
      result << "#{calculated_property_definition.column_name} = #{connection.as_padded_number(calculated_property_definition.column_name, @new_precision)}"
      result
    end
    connection.bulk_update(:table => Card.table_name, :set => set_conditions.join(', ')) if set_conditions.any?
  end
  
  def all_calculated_property_definitions
    @project.formula_property_definitions_with_hidden + @project.aggregate_property_definitions_with_hidden
  end  
  
end

class PrecisionChange::Increase < PrecisionChange
  
  private
  
  def update_transitions; end
  
  def update_cards; end
  
  def delete_aliased_managed_numeric_values; end
  
  def adjust_card_list_views; end
  
  def adjust_history_subscriptions; end
  
  def update_card_defaults; end
  
  def update_project_variables; end
  
end

class PrecisionChange::Decrease < PrecisionChange
  
  private
  
  def update_cards
    (@project.numeric_list_property_definitions_with_hidden + @project.numeric_free_property_definitions_with_hidden).each do |prop_def|
      execute <<-SQL 
        UPDATE #{Card.quoted_table_name}
        SET #{prop_def.column_name} = #{connection.as_padded_number(prop_def.column_name, @new_precision)}
        WHERE #{connection.value_out_of_precision(prop_def.column_name, @new_precision)} 
      SQL
    end
  end
  
  def update_transitions
    TemporaryIdStorage.with_session do |prereqs_to_update_session_id|
      TemporaryIdStorage.with_session do |actions_to_update_session_id|
        prereqs_to_update = TemporaryIdStorage.table_name
        actions_to_update = TemporaryIdStorage.table_name
    
        execute <<-SQL
          INSERT INTO #{prereqs_to_update} (session_id, id_1)
            (SELECT '#{prereqs_to_update_session_id}', tp.id FROM #{TransitionPrerequisite.table_name} tp
            JOIN #{PropertyDefinition.table_name} pd ON (pd.id = tp.property_definition_id AND 
                pd.type IN ('#{EnumeratedPropertyDefinition.name}', '#{TextPropertyDefinition.name}')) AND 
                pd.is_numeric = #{connection.true_value}
            JOIN #{Transition.table_name} t ON (t.id = tp.transition_id)
            WHERE t.project_id = #{@project.id} AND #{connection.value_out_of_precision("tp.value", @new_precision)})
        SQL
        
        execute <<-SQL
          INSERT INTO #{actions_to_update} (session_id, id_1)
            (SELECT '#{actions_to_update_session_id}', ta.id FROM #{TransitionAction.table_name} ta
            JOIN #{PropertyDefinition.table_name} pd ON (pd.id = ta.target_id AND
                pd.type IN ('#{EnumeratedPropertyDefinition.name}', '#{TextPropertyDefinition.name}')) AND
                pd.is_numeric = #{connection.true_value}
            JOIN #{Transition.table_name} t ON (t.id = ta.executor_id)
            WHERE t.project_id = #{@project.id} AND ta.executor_type = '#{Transition.name}' AND #{connection.value_out_of_precision("ta.value", @new_precision)})
        SQL
    
        execute <<-SQL
          UPDATE #{TransitionPrerequisite.table_name} SET value = #{connection.as_padded_number('value', @new_precision)}
          WHERE #{TransitionPrerequisite.table_name}.id IN (SELECT #{prereqs_to_update}.id_1 FROM #{prereqs_to_update} WHERE session_id = '#{prereqs_to_update_session_id}')
        SQL
        
        execute <<-SQL
          UPDATE #{TransitionAction.table_name} SET value = #{connection.as_padded_number('value', @new_precision)}
          WHERE #{TransitionAction.table_name}.id IN (SELECT #{actions_to_update}.id_1 FROM #{actions_to_update} WHERE session_id = '#{actions_to_update_session_id}')
        SQL
      end
    end
  end
  
  def update_card_defaults
    TemporaryIdStorage.with_session do |defaults_to_update_session_id|
      execute <<-SQL
        INSERT INTO #{TemporaryIdStorage.table_name} (session_id, id_1)
          (SELECT '#{defaults_to_update_session_id}', ta.id FROM #{TransitionAction.table_name} ta
          JOIN #{PropertyDefinition.table_name} pd ON (pd.id = ta.target_id AND
              pd.type IN ('#{EnumeratedPropertyDefinition.name}', '#{TextPropertyDefinition.name}')) AND
              pd.is_numeric = #{connection.true_value}
          JOIN #{CardDefaults.table_name} cd ON (cd.id = ta.executor_id)
          WHERE cd.project_id = #{@project.id} AND ta.executor_type = '#{CardDefaults.name}' AND #{connection.value_out_of_precision("ta.value", @new_precision)})
      SQL
      
      execute <<-SQL
        UPDATE #{TransitionAction.table_name} SET value = #{connection.as_padded_number('value', @new_precision)}
        WHERE #{TransitionAction.table_name}.id IN (SELECT #{TemporaryIdStorage.table_name}.id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{defaults_to_update_session_id}')
      SQL
    end
  end
  
  def delete_aliased_managed_numeric_values
    @project.numeric_list_property_definitions_with_hidden.each do |property_definition|
      
      rows = select_all_rows <<-SQL
        SELECT #{connection.as_padded_number('ev.value', @new_precision)} AS value, MIN(ev.position) AS position, COUNT(*) AS alias_count FROM #{EnumerationValue.table_name} ev
        WHERE ev.property_definition_id = #{property_definition.id}
        GROUP BY #{connection.as_padded_number('ev.value', @new_precision)}
        ORDER BY position
      SQL
      rows = rows.each_with_index { |row, index| row['position'] = index + 1 }
      
      rows.each do |row|
        if row['alias_count'].to_i > 1
          recreate_new_managed_value(row, property_definition)
        else
          update_existing_managed_value(row, property_definition)
        end
      end
    end
  end
  
  def recreate_new_managed_value(row, property_definition)
    TemporaryIdStorage.with_session do |session_id|
      ids_to_delete = TemporaryIdStorage.table_name
      execute <<-SQL
        INSERT INTO #{ids_to_delete} (session_id, id_1)
          (SELECT '#{session_id}', ev.id FROM #{EnumerationValue.table_name} ev
           WHERE ev.property_definition_id = #{property_definition.id} AND
                 #{number_comparison_sql('ev.value', '=', row['value'], @new_precision)}
          )
      SQL
      
      sql = <<-SQL
        SELECT value FROM #{EnumerationValue.table_name} ev
        WHERE ev.id IN (SELECT id_1 FROM #{ids_to_delete} WHERE session_id = '#{session_id}')
      SQL
      values = select_all_rows(sql).collect { |value_row| value_row['value'] }.sort
      
      execute <<-SQL
        DELETE FROM #{EnumerationValue.table_name}
        WHERE id IN (SELECT id_1 FROM #{ids_to_delete} WHERE session_id = '#{session_id}')
      SQL
      
      new_value = values.first.to_num_maintain_precision(@new_precision)
      
      insert_columns = %w{value position property_definition_id}
      values = ["'#{new_value}'", row['position'], property_definition.id]
      if connection.prefetch_primary_key?
        insert_columns.unshift('id')
        values.unshift(connection.next_id_sql(EnumerationValue.table_name))
      end
      
      execute <<-SQL
        INSERT INTO #{EnumerationValue.table_name} (#{insert_columns.join(',')}) 
        VALUES (#{values.join(',')})
      SQL
      
      set_appropriate_card_values_to(property_definition, new_value)
    end
  end
  
  def set_appropriate_card_values_to(property_definition, value)
    execute <<-SQL
      UPDATE #{Card.quoted_table_name}
      SET #{property_definition.column_name} = '#{value}'
      WHERE #{number_comparison_sql(property_definition.column_name, '=', connection.quote(value))}
    SQL
  end
  
  def update_existing_managed_value(row, property_definition)
    execute <<-SQL
      UPDATE #{EnumerationValue.table_name} SET
      value = #{connection.as_padded_number(connection.quote(row['value']), @new_precision)}, 
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
            #{number_comparison_sql('value', '=', row['value'], @new_precision)} AND
            #{connection.value_out_of_precision('value', @new_precision)}
    SQL
    
    execute <<-SQL
      UPDATE #{EnumerationValue.table_name} SET
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
            #{number_comparison_sql('value', '=', row['value'], @new_precision)}
    SQL
  end
  
  def adjust_card_list_views
    @project.card_list_views.select { |view| view.filters.is_a?(Filters) && !view.filters.empty? }.each do |view|
      view.filters.using_numeric_property_definition.each { |filter| filter.value = filter.value.to_num_maintain_precision(@new_precision).to_s }
      view.save
    end
  end
  
  def adjust_history_subscriptions
    @project.history_subscriptions.select { |subscription| subscription.filter_property_names.size > 0 }.each do |subscription|
      history_filter_params = subscription.to_history_filter_params
      
      subscription.filter_property_names.each do |prop_name|
        prop_def = @project.find_property_definition(prop_name, :with_hidden => true)
        next unless prop_def.numeric?
        if history_filter_params.involved_filter_properties[prop_name]
          value = history_filter_params.involved_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, value.to_num_maintain_precision(@new_precision).to_s)
        end
        if history_filter_params.acquired_filter_properties[prop_name]
          value = history_filter_params.acquired_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, value.to_num_maintain_precision(@new_precision).to_s)
        end
      end
      
      subscription.save
    end
  end
  
  def update_project_variables
    execute <<-SQL
      UPDATE #{ProjectVariable.table_name}
      SET value = #{connection.as_padded_number('value', @new_precision)}
      WHERE #{connection.value_out_of_precision('value', @new_precision)}
            AND data_type = #{connection.quote(ProjectVariable::NUMERIC_DATA_TYPE)}
            AND project_id = #{@project.id}
    SQL
  end
end
