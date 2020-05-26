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

module PropertyEditorsPageId

  def card_type_editor_id(context)
    droplist_link_id(Project.card_type_definition, context)
  end

  def card_type_dropdown_id(context)
    droplist_dropdown_id(Project.card_type_definition, context)
  end

  def card_type_option_id(value, context)
    droplist_option_id(Project.card_type_definition, value, context)
  end

  def droplist_option_id(property_name, value, context=nil)
    droplist_part_id(property_name, "option_#{value}", context)
  end

  # new property editor id for click and show droplist or field
  def property_editor_id(property_name, context="show")
    context = nil if new_property_editor?(context)
    contextualise(context, prop(property_name).html_id)
  end

  # for old property editor, please use this one
  def droplist_link_id(property_name, context = nil)
    part_name = new_property_editor?(context) ? nil : 'drop_link'
    droplist_part_id(property_name, part_name, context)
  end

  def droplist_dropdown_id(property_name, context=nil)
    droplist_part_id(property_name, 'drop_down', context)
  end

  def property_value_widget(property_name)
    "css=##{property_editor_panel_id(property_name)} .property-value-widget"
  end

  def property_editor_panel_id(property_name, context=nil)
    droplist_part_id(property_name, "panel", context)
  end

  def property_editor_property_name_id(property_name, context)
    "css=##{property_editor_panel_id(property_name, context)} .property-name"
  end

  def property_editor_tooltip_id(property, context)
    if new_property_editor?(context)
      property_editor_property_name_id(property, context)
    else
      "css=##{droplist_part_id(property, 'span', context)} span"
    end
  end

  def property_editor_drop_down_search_field_id(property, context)
    "css=##{droplist_dropdown_id(property, context)} .dropdown-options-filter"
  end

  def editlist_link_id(property_name, context = nil)
    part_name = new_property_editor?(context) ? nil : 'edit_link'
    droplist_part_id(property_name, part_name, context)
  end

  def editlist_inline_editor_id(property_name, context=nil, part_name = 'field')
    droplist_part_id(property_name, part_name, context)
  end

  def droplist_part_id(property_name, part_name=nil, context=nil)
    [property_editor_id(property_name, context), part_name].compact.join("_")
  end

  def new_property_editor?(context)
    %w(show edit).include?(context)
  end

  def prop(property_name)
    property_name.respond_to?(:name) ? property_name : Project.current.reload.find_property_definition(property_name.to_s, :with_hidden => true)
  end

  def contextualise(context, id)
    if context.blank?
      id
    else
      context + "_" + id
    end
  end
end
