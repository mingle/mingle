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
  
  class TreeColumnGroup < Struct.new(:tree_config, :columns)
  
    def completed?
      missing_column_names.empty?
    end
  
    def indexes
      columns.collect(&:index)
    end
  
    def incomplete_warning
      unless completed?
        missing_column_phrases = missing_column_names.collect{|name| "'#{name}'"}
        "Properties for tree '#{tree_config.name}' will not be imported because column #{missing_column_phrases.join(', ')} #{missing_column_phrases.size == 1 ? 'was' : 'were'} not included in the pasted data."
      end
    end
  
    def missing_column_names
      column_names = columns.collect { |col| col.name.downcase }
      tree_config.tree_property_definitions.collect { |pd| pd.name unless column_names.include?(pd.name.downcase) }.compact
    end
  
    def to_json(options = {})
      memo = {}
      memo['name'] = tree_config.name
      memo['id'] = tree_config.id
      memo['columns'] = columns.collect(&:name).collect(&:underscored)
      memo.to_json
    end
  end
end
