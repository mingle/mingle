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

module MacroEditorHelper
  def label_text_of_macro_parameter(parameter_definition)
    parameter_name = parameter_definition.parameter_name
    if parameter_definition.required?
      "#{parameter_name} #{content_tag('span', "*", :class => 'required')}".html_safe
    else
      parameter_name
    end
  end
  
  def parameter_help_message(parameter_definition)
    "<span class=\"example notes\">Example: #{parameter_definition.example}</span>" unless parameter_definition.example.blank?
  end

  def section_class(section)
    classes = ['section-toggle']
    classes << (section.collapsed? ? 'section-expand' : 'section-collapse')
    classes << 'disabled' if section.disabled?
    classes.join(' ')
  end

  def render_placeholder_for_description?(macro_type)
    %w(pie-chart stack-bar-chart stacked-bar-chart ratio-bar-chart data-series-chart cumulative-flow-graph daily-history-chart).include?(macro_type)
  end
end
