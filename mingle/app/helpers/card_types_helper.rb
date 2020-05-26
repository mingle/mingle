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

module CardTypesHelper
  def color_panel_for(card_type)
    { :partial  => "shared/color_panel",
      :locals  => { :color_provider => card_type,
                    :form_options => {:url => { :controller => 'card_types', :action => 'update_color', :id => card_type }}}}
  end

  def allow_reorder?
    authorized?(:controller => 'card_types', :action => 'reorder')
  end

  def is_checked?(prop_def)
    @checked_property_definitions.include?(prop_def)
  end
end
