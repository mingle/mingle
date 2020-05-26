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

class M114Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M114PropertyDefinition', :foreign_key => 'project_id'
  has_many :cards, :class_name => 'M114Card', :foreign_key => 'project_id'
  
  def activate
    M114Card.set_table_name "#{ActiveRecord::Base.table_name_prefix}#{identifier}_cards"
    M114Card.reset_column_information

    M114CardVersion.set_table_name "#{ActiveRecord::Base.table_name_prefix}#{identifier}_card_versions"
    M114CardVersion.reset_column_information
  end
end

class M114PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm114_type' #disable single table inheretance
  belongs_to :project, :class_name => 'M114Project', :foreign_key => 'project_id'
end

class M114Card < ActiveRecord::Base
  belongs_to :project, :class_name => 'M114Project', :foreign_key => 'project_id'
end

class M114CardVersion < ActiveRecord::Base
  belongs_to :project, :class_name => 'M114Project', :foreign_key => 'project_id'
end

class ChangeEmptyStringsInPropertyValueColumnsToNull < ActiveRecord::Migration
  def self.up
    M114Project.find(:all).each do |p|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{p.identifier}_cards")
      
      p.activate

      property_definitions_to_update = p.property_definitions.reject { |pd| pd.kind_of?(DatePropertyDefinition) || pd.kind_of?(AssociationPropertyDefinition) }
      card_update_sql_statements = property_definitions_to_update.collect { |pd| set_to_null_if_blank(pd.column_name, M114Card.table_name) }
      card_version_update_sql_statements = property_definitions_to_update.collect { |pd| self.set_to_null_if_blank(pd.column_name, M114CardVersion.table_name) }
      (card_update_sql_statements + card_version_update_sql_statements).each { |s| ActiveRecord::Base.connection.execute(s) }
    end
  end

  def self.set_to_null_if_blank(column_name, table_name)
    SqlHelper.sanitize_sql("update #{quote_table_name(table_name)} set #{quote_column_name(column_name)} = ? where #{quote_column_name(column_name)} = ?", nil, '')
  end  

  def self.down
    raise ActiveRecord::IrreversibleMigration, "data patch. should not be reversed to recreate bad data!"
  end
end
