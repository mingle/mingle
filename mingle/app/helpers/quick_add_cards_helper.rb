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

module QuickAddCardsHelper

  def card_creation_could_change_content?
    on_history_page? || on_card_show? || on_page_show?
  end

  def on_history_page?
    params[:from_url][:controller] == 'history'
  end

  def on_card_show?
    params[:from_url][:controller] == 'cards' && ['show'].include?(params[:from_url][:action])
  end

  def on_page_show?
    (params[:from_url][:controller] == 'pages' && params[:from_url][:action] == 'show') ||
      (params[:from_url][:controller] == 'projects' && params[:from_url][:action] == 'overview')
  end

  def request_a_project_resource?(request_uri)
    request_uri =~ /^#{CONTEXT_PATH}\/projects\/#{Project::IDENTIFIER_REGEX}/
  end

  def request_card_list?
    card_list_action?(@controller.controller_name, @controller.action_name)
  end

  def card_list_action?(controller_name, action_name)
    controller_name == 'cards' && ['list', 'index'].include?(action_name)
  end

  def link_to_add_card_with_defaults(text = "Add Card", html_options = {}, from_url=params, card_properties={}, use_filters = false)
    link_to_remote(text, {
           :url => {:action => 'add_card_popup',
                    :controller => "quick_add_cards",
                    :project_id => @project.identifier,
                    :from_url => from_url,
                    :card_properties => card_properties,
                    :use_filters => use_filters},
           :method => :post,
           :before   => "disableLink('add_card_with_defaults', '');InputingContexts.push(new LightboxInputingContext());",
           :complete => "enableLink('add_card_with_defaults', '');"
        }, html_options)
  end

end
