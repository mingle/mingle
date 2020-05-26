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

class PluginSchemaInfo
  extend SqlHelper
  
  class << self
    def table_name
      "#{ActiveRecord::Base.table_name_prefix}schema_migrations"
    end
    
    def find_by_plugin_name(plugin_name)
      version_match_expression = Regexp.new("(\\d+)-(#{Regexp.escape(plugin_name)})")
      result = select_values("SELECT version FROM #{table_name} WHERE version LIKE '%-#{plugin_name}'").max do |version1, version2|
        version_match_expression.match(version1)[0] <=> version_match_expression.match(version2)[0]
      end
      
      PluginSchemaInfo.new(result)
    end
  end
  
  def initialize(version)
    @version = version
  end
  
  def version_number
    @version =~ /(\d+)-(\w+)/
    $1.to_i
  end
  
  def plugin_name
    @version =~ /(\d+)-(\w+)/
    $2
  end
  
  def update_version(version_number)
    new_version = "#{version_number}-#{plugin_name}"
    PluginSchemaInfo.execute("UPDATE #{PluginSchemaInfo.table_name} SET version = '#{new_version}' WHERE version = '#{@version}'")
    @version = new_version
  end
end
