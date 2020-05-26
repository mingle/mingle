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

require 'strscan'

class M139CardTypesPropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types_property_definitions"
  belongs_to :property_definition, :class_name => 'M139PropertyDefinition', :foreign_key => 'property_definition_id'
end

class M139Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  
  def card_schema
    M139CardSchema.new(self)
  end
  
  def card_table_name
    "#{ActiveRecord::Base.table_name_prefix}#{identifier}_cards"
  end
  
  def card_version_table_name
    "#{ActiveRecord::Base.table_name_prefix}#{identifier}_card_versions"
  end
end

class M139CardSchema
  def initialize(project)
    @project = project
  end
  
  def remove_column(column_name)        
    connection.remove_column(@project.card_table_name, column_name)
    connection.remove_column(@project.card_version_table_name, column_name)
  end
  
  private
  
  def connection
    @project.connection
  end
  
end

class M139PropertyDefinition < ActiveRecord::Base
  include SecureRandomHelper
  include MigrationHelper
  
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm139_type' # disable single table inheritance
  
  belongs_to :project, :class_name => 'M139Project', :foreign_key => 'project_id'
  has_many :card_types_property_definitions, :dependent => :destroy, :class_name => 'M139CardTypesPropertyDefinition', :foreign_key => 'property_definition_id'
  
  def destroy
    ActiveRecord::Base.transaction do
      project.reload
      project.card_schema.remove_column(column_name)
      super
    end
    
    project.reload
    remove_property_changes
    remove_property_definition_from_search
  end
  
  def remove_property_changes
    event_table_name = 'events'
    change_table_name = 'changes'
    
    event_ids_for_project = 'tt' + random_32_char_hex
    begin
      project.connection.create_table(event_ids_for_project) do |t|
        t.column "event_id", :integer,  :null => false
      end
      project.connection.execute("INSERT INTO #{quote_table_name event_ids_for_project} (event_id) (SELECT id FROM #{safe_table_name(event_table_name)} WHERE project_id = #{project.id})")
      delete_changes_sql = "DELETE FROM #{safe_table_name change_table_name} WHERE field = ? AND type = 'PropertyChange' AND event_id IN (SELECT event_id FROM #{ quote_table_name event_ids_for_project})"
      project.connection.execute(SqlHelper.sanitize_sql(delete_changes_sql, name))
    ensure
      project.connection.drop_table(event_ids_for_project)
    end
  end
  
  def remove_property_definition_from_search
    sql = "INSERT INTO #{safe_table_name("update_full_text_index_requests")} (searchable_id, searchable_type, project_id)
           SELECT id, 'Card', #{project.id} FROM #{quote_table_name project.card_table_name} WHERE project_id = #{project.id}"
    connection.execute(sql)
  end
  
end

class M139CardTypesPropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types_property_definitions"
  belongs_to :property_definition, :class_name => "M139PropertyDefinition", :foreign_key => 'property_definition_id'
end

class M139Parser
  def unquote(value)
    case value
    when /^'(.*)'$/ then $1
    when /^"(.*)"$/ then $1
    else value
    end
  end
  
  def parse(str)
    @input = str
    tokens = []
    str = "" if str.nil?

    scanner = StringScanner.new(str)

    until scanner.eos?
      case
      # note: all these empty 'when' clauses are in here on purpose
      when scanner.scan(/\s+/)
      when m = scanner.scan(/((\d+\.?\d*)|(\d*\.?\d+))/)
      when m = scanner.scan(/\+/i)
      when m = scanner.scan(/\-/i)
      when m = scanner.scan(/\*/i)
      when m = scanner.scan(/\//i)
      when m = scanner.scan(/\(/i)
      when m = scanner.scan(/\)/i)
      when m = scanner.scan(/\{/i)
      when m = scanner.scan(/\}/i)
      when m = scanner.scan(/\[/i)
      when m = scanner.scan(/\]/i)
      when m = scanner.scan(/'([^']*)'/)
        tokens.push   unquote(m)
      when m = scanner.scan(/"([^"]*)"/)
        tokens.push   unquote(m)
      when m = scanner.scan(/\w+/)
        tokens.push   m
      end
    end
    tokens
  end
end

class RemoveFormulaPropertiesThatUseAggregates < ActiveRecord::Migration
  
  def self.up
    parser = M139Parser.new
    formulas_to_destroy = []
    
    M139PropertyDefinition.find(:all, :conditions => ["type = 'FormulaPropertyDefinition'"]).each do |fpd|
      component_property_names = parser.parse(fpd.formula)
      component_property_names.each do |property_name|
        component_property = M139PropertyDefinition.find(:first, :conditions => "project_id = #{fpd.project_id} AND LOWER(name) = '#{property_name.downcase}'")
        formulas_to_destroy << fpd if component_property['type'] == 'AggregatePropertyDefinition'
      end
    end
    
    formulas_to_destroy.uniq.each(&:destroy)
  end

  def self.down
  end
end
