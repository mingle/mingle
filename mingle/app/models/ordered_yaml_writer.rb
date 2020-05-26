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

class OrderedYAMLWriter
  
  def initialize(parameter_definitions)
    @parameter_definitions = parameter_definitions
  end
  
  def write(params, prefix='  ')
    params.stringify_keys!
    @parameter_definitions.inject("") do |result, pd|
      pd_name = pd.parameter_name.to_s
      next result if params[pd_name].blank? && !pd.required?
      result << if Array === params[pd_name]
        yaml_strings = params[pd_name].collect do |value|
          OrderedYAMLWriter.new(pd.list_of.parameter_definitions).write(value, "#{prefix}  ").gsub(/\A#{prefix}  /, "#{prefix}- ")
        end
        %Q{#{prefix}#{pd.parameter_name}:\n#{yaml_strings.join}}
      else
         # If a parameter has a single quote ( "Type" = "Story" WHERE "STATUS" = "Ne'w") which would result
         # in ( '"Type" = "Story" WHERE "STATUS" = "Ne''w"') after YAML.dump hence CardQuery would treat  ('"Type" = "Story" WHERE "STATUS" = "Ne')
         # as a single single property. To avoid such situation we have to remove starting and ending single quotes, and replace double '' with single '.
        pd_val = YAML.dump(parse_boolean(params[pd_name]), line_width: 9999).gsub(/\A---\s+/, '').gsub(/''/,"'").strip
        pd_val = (pd_val.start_with?("'") && pd_val.end_with?("'")) ? pd_val.gsub(/\A'|'\Z/, '').strip : pd_val
        %Q{#{prefix}#{pd.parameter_name}: #{pd_val}\n}
      end
    end
  end

  def parse_boolean(param)
    return false if param =~ /\Afalse\Z/
    return true if param =~ /\Atrue\Z/
    param
  end
end
