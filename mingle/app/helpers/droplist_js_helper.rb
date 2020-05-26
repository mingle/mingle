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

# a helper for generating droplist js
# need includer have js_component_id_prefix and input_id method defined
module DroplistJsHelper
  def droplink_id
    "#{js_component_id_prefix}_drop_link"      
  end
  
  def generate_js(view_helper, select_options, initial_selected, url_opts, input_name)
    ajax_call = view_helper.remote_function(
                  :url      => url_opts,
                  :with     => "'#{input_name}=' + $F('#{input_id}')",
                  :before   => view_helper.show_spinner('spinner'),
                  :complete => view_helper.hide_spinner('spinner'))
    <<-JAVASCRIPT
      new DropList({
          selectOptions   : #{select_options.to_json}, 
          htmlIdPrefix    : "#{js_component_id_prefix}",
          initialSelected : #{initial_selected.to_json},
          onchange        : function(){ #{ajax_call} }
        });
    JAVASCRIPT
  end
end
