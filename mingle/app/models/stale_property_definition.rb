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

class StalePropertyDefinition < ActiveRecord::Base
  MAKE_STALE_BATCH_SIZE = 500
  set_table_name("stale_prop_defs")
  
  belongs_to :property_definition, :foreign_key => "prop_def_id"
  belongs_to :card
  belongs_to :project
  
  def destroy_without_triggering_observers
    StalePropertyDefinition.delete_without_triggering_observers(self.project_id, self.prop_def_id, self.card_id)
  end
  
  def self.delete_without_triggering_observers(project_id, aggregate_property_definition_id, card_id)
    sql = "DELETE FROM #{StalePropertyDefinition.table_name} WHERE prop_def_id = #{aggregate_property_definition_id} AND card_id = #{card_id} AND project_id = #{project_id}"
    ActiveRecord::Base.connection.execute(sql)
  end
  
  def self.make_stale(project_id, aggregate_property_definition_id, card_ids_condition_sql)
    c = ActiveRecord::Base.connection
    
    formula_property_definitions = formulas_using_aggregate(project_id, aggregate_property_definition_id)
    
    c.insert_into(:table => StalePropertyDefinition.table_name,
                      :insert_columns => [c.quote_column_name('prop_def_id'), 'card_id', 'project_id'],
                      :select_columns => [aggregate_property_definition_id, 'id', project_id],
                      :from => Card.quoted_table_name,
                      :where => card_ids_condition_sql,
                      :generate_id => connection.prefetch_primary_key?(StalePropertyDefinition))
    
    formula_property_definitions.each do |formula_property_definition|
      c.insert_into(:table => StalePropertyDefinition.table_name,
                        :insert_columns => [c.quote_column_name('prop_def_id'), 'card_id', 'project_id'],
                        :select_columns => [formula_property_definition, 'id', project_id],
                        :from => Card.quoted_table_name,
                        :where => card_ids_condition_sql,
                        :generate_id => connection.prefetch_primary_key?(StalePropertyDefinition))
    end

    CardCachingStamp.update(card_ids_condition_sql)
  end

  def self.formulas_using_aggregate(project_id, aggregate_property_definition_id)
    project = Project.find_by_id(project_id)
    aggregate_property_definition = PropertyDefinition.find_by_id(aggregate_property_definition_id)
    aggregate_property_definition.dependant_formulas.nil? ? [] : aggregate_property_definition.dependant_formulas
  end
end
