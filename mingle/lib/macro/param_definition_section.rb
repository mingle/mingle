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

class Macro
  class ParamDefinitionSection
    def initialize(options={})
      @options = options
    end

    def name
      @options[:name] || ''
    end

    def parameter_definitions
      @options[:param_defs] || []
    end

    def identifier
      name.tr(' ','_').underscore
    end

    def disabled?
      @options[:disabled] || false
    end

    def collapsed?
      @options[:collapsed] || false
    end

    def all_param_defs
      parameter_definitions.inject([]) do |all_param_defs, param_def|
        all_param_defs += (param_def.instance_of?(Macro::ParameterDefinition)? [param_def] : param_def.param_defs)
      end
    end
  end
end
