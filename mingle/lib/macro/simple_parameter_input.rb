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

 class SimpleParameterInput
  
  def initialize(partial_name)
    @partial = partial_name
  end

  def input_type
    'textbox'
  end
  
  COLOR_PALETTE = SimpleParameterInput.new('color_palette_parameter_input')
  DEFAULT = SimpleParameterInput.new('simple_parameter_input')
  PAIR = SimpleParameterInput.new('pair_parameters')
  GROUP = SimpleParameterInput.new('grouped_parameters')

  attr_reader :partial
end

class DropDownParameter < SimpleParameterInput
  def input_type
    'dropdown'
  end
end

class TagsFilterParameter < SimpleParameterInput
  def input_type
    'tags_filter'
  end
end
