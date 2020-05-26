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
object @easy_charts_macro

attributes :supported_in_easy_charts?

node :chart_data do |macro|
  macro_partial = "macro_editor/easy_charts/#{macro.class.partial_name}"
  partial macro_partial, object: macro
end

node :content_provider do
  @content_provider
end

node :macro_help_urls do
  {
      'pie-chart' => link_to_help('pie-chart'),
      'ratio-bar-chart' => link_to_help('ratio-bar-chart')
  }
end

node :initialProject do
  @project.identifier
end