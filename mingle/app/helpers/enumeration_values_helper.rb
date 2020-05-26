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

module EnumerationValuesHelper
  def color_panel_for(enum_value)
    { :partial  => "shared/color_panel",
      :locals  => { :color_provider => enum_value,
                    :form_options => {:url => { :controller => 'enumeration_values', :action => 'update_color', :id => enum_value }}}}
  end

  def allow_reorder?
    !@prop_def.numeric? && authorized?(:controller => :property_definitions, :action => 'reorder')
  end

  def card_count_link(enum_value, count)
    text = enumerate(count, 'card')
    if count > 0
      query = "#{enum_value.property_definition.name.inspect} = #{enum_value.value.inspect}"
      link_to(text, {:controller => "cards", :action => "list", :filters => {:mql => query}})
    else
      content_tag :span, text
    end
  end
end
