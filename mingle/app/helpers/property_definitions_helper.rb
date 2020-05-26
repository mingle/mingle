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

module PropertyDefinitionsHelper
  
  def display_edit_link_for(prop_def)
    link_to 'Edit', {:action => 'edit', :id => prop_def}, {:id => "edit_property_def_#{prop_def.id}"}
  end
  
  def display_delete_link_for(prop_def)
    link_to 'Delete', {:action => 'confirm_delete', :id => prop_def.id}, {:id => "delete_property_def_#{prop_def.id}"}
  end
  
  def link_for_cancel
    params[:cancel_url] || url_for(:action => 'index')
  end
  
  def card_type_checkbox_state(prop_def, card_type)
      prop_def.new_record? && prop_def.errors.empty? ? true : @card_types.include?(card_type)
  end
  
  def plvs_will_be_disassociated(plv_names)
    return '' if plv_names.empty?
    "<li>The following #{pluralize(plv_names.size, 'project variable')} will no longer be associated with this property: #{plv_names.sorted_bold_sentence}.</li>"
  end
  
  def create_property_values_description(prop_def)
    if prop_def.is_a?(EnumeratedPropertyDefinition)
      values_link = pluralize(prop_def.values.size, "value")
      link_to values_link, {:controller => 'enumeration_values', :action => 'list', :definition_id => prop_def.id }, :id => "enumeration-values-#{prop_def.id}"
    elsif prop_def.is_a?(TextPropertyDefinition) && prop_def.numeric?
      "Any number"
    elsif prop_def.is_a?(TextPropertyDefinition) && !prop_def.numeric?
      "Any text"
    elsif prop_def.is_a?(DatePropertyDefinition)
      "Any date"
    elsif prop_def.is_a?(UserPropertyDefinition)
      pluralize(prop_def.values.size, "team member")
    elsif prop_def.is_a?(CardRelationshipPropertyDefinition)  
      "Any card"
    else
      pluralize(prop_def.values.size, "value")
    end
  end

  def display_errors
    unless @property_definition.errors.empty?
      error = (@property_definition.errors.full_messages.join('. ') << " ").escape_html
      error << render_help_link('Formula Properties Page', {:class => ''}) if @property_definition.is_a?(FormulaPropertyDefinition)
      html_flash.now[:error] = error
    end
  end
end
