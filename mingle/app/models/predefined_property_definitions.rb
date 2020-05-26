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

module PredefinedPropertyDefinitions

  module PredefinedMixin
    attr_accessor :nullable, :excel_importable
    def nullable?
      nullable
    end

    def card_types
      Project.current.card_types
    end

    def groupable?
      false
    end

    def colorable?
      false
    end

    def finite_valued?
      false
    end

    def excel_importable?
      excel_importable
    end
  end

  # ruby_name   => predefined_type_creator
  TYPES = {
    'type'              => lambda { |project| project.card_type_definition },
    'number'            => lambda { |project| create_definition project, 'IntegerPropertyDefinition', 'Number',            'number',              false },
    'name'              => lambda { |project| create_definition project, 'TextPropertyDefinition',    'Name',              'name',                false },
    'project'           => lambda { |project| create_definition project, 'ProjectPropertyDefinition', 'Project',           'project_id',          false, false },
    'description'       => lambda { |project| create_definition project, 'TextPropertyDefinition',    'Description',       'description',         true },
    'project_card_rank' => lambda { |project| create_definition project, 'PreciseNumberPropertyDefinition', 'Project Card Rank', 'project_card_rank', false, false },
    'modified_by'       => lambda { |project| create_definition project, 'UserPropertyDefinition',    'Modified by',       'modified_by_user_id', false, false },
    'created_by'        => lambda { |project| create_definition project, "UserPropertyDefinition",    'Created by',        'created_by_user_id',  false, false },
    'created_on'        => lambda { |project| create_definition project, "DatePropertyDefinition",    'Created on',        'created_at',          false, false },
    'modified_on'       => lambda { |project| create_definition project, "DatePropertyDefinition",    'Modified on',       'updated_at',          false, false }
  }

  def create_definition(project, class_name, name, column_name, nullable, excel_importable = true, other_opts={})
    opts = {:project => project, :name => name, :column_name => column_name, :editable => false, :ruby_name => column_name}.merge(other_opts)
    ret = class_name.constantize.new(opts)
    ret.is_predefined = true
    ret.extend(PredefinedMixin)
    ret.nullable = nullable
    ret.excel_importable = excel_importable
    ret
  end
  module_function :create_definition

  def find(project, name)
    ruby_name = name.to_str.downcase.gsub(/\s/, '_')
    TYPES[ruby_name].call(project) if TYPES[ruby_name]
  end
  module_function :find

  def tracing_column_names
    ['Created by', 'Modified by']
  end
  module_function :tracing_column_names

  def tracing_column?(column)
    tracing_column_names.any? { |tracing_column_name| tracing_column_name.downcase == column.downcase }
  end
  module_function :tracing_column?
end
