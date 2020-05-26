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

module CardListViewTabNameHelper

  def tab_name(tab)

    ret = h(tab.name)

    if counter = tab.counter
      ret += content_tag(:span, counter, :class => 'tab-counter badge', :title => tab.tooltip)
      return ret.html_safe
    end

    return ret unless tab.dirty?

    if @controller.tab_update_action? && tab.current?
      ret += revert_tab_link(tab)
      ret += save_tab_link(tab) unless tab.name == 'All'
    else
      ret += "*"
    end
    ret
  end

  def revert_tab_link(tab)
    reset_url = url_for(@view.reset_tab_to(tab.name).to_params.merge({:controller => :cards}))
    link_to("Reset",
            reset_url,
            :class => "reset-all-link tab-action-text",
            :id => 'reset_to_tab_default')
  end

  def save_tab_link(tab)
    card_list_view_link_to('Save',
                           @view.to_params.merge({:controller => 'cards', :action => 'create_view', :view => { :name => tab.name } }),
                           :param_options => { :merge => { :user_id => nil, :view => {:name => tab.name }}},
                           :method => 'POST',
                           :id => "#{tab.html_id}_save",
                           :title => "Save current view as '#{tab.name}'",
                           :class => 'update-tab tab-action-text')
  end


end
