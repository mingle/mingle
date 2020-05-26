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

module ProjectVariablesHelper
  
  def radio_button_for(data_type)
    extended_params = @project_variable.data_type == data_type ? {:value => @project_variable.value, :property_definition_ids => @project_variable.property_definition_ids} : {}
    radio_button 'project_variable', 'data_type', data_type, :onclick => remote_function(:url => { :action => :select_data_type, :project_variable => {:data_type => data_type}.merge(extended_params) }, :method => :get, :complete => '$("spinner").hide()', :before => '$("spinner").show()')
  end
  
  def card_type_radio_button_for(card_type)
    data_type = ProjectVariable::CARD_DATA_TYPE
    radio_button_tag 'project_variable[card_type_id]', 
        (card_type ? card_type.id : nil), 
        (@project_variable.card_type == card_type), 
        :class => "card_type_radio_button",
        :onclick => remote_function(
          :url => {:action => 'select_card_type', :card_type_id => (card_type && card_type.id), :data_type => data_type},
          :submit => 'available_property_definitions_container',
          :complete => '$("spinner").hide()', 
          :before => '$("spinner").show()', 
          :id => (card_type ? card_type.id : 'Any')
        )
  end
    
  def types_for_card_data_type
    @project.tree_configurations.collect do |tree_configuration|
      tree_configuration.all_card_types[0..-2]
    end.flatten.uniq.smart_sort_by(&:name)
  end
  
  def initial_selection_for_card_plv(plv)
    card = plv.project.cards.find_by_id(plv.value.to_i) || Null.new
    [card.number_and_name || "(not set)", card.id.to_s]
  end
  
  def card_plv_drop_list_options(plv)
    {
      :html_id_prefix =>  'plv', 
      :select_options =>  [PropertyValue::NOT_SET_VALUE_PAIR], 
      :initial_selected =>  initial_selection_for_card_plv(plv),
      :appended_actions =>  droplist_appended_actions(:edit, plv)
    }
  end
  
end
