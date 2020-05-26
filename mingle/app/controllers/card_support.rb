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

module CardSupport

  def update_card_from_params(card, options={})
    if params[:card]
      [:name, :card_type_name].each do |attr_name|
        if params[:card][attr_name]
          card.write_attribute(attr_name, params[:card][attr_name])
        end
      end
      if params[:card][:description]
        card.description = process_content_from_ui(params[:card][:description])
        card.editor_content_processing = !api_request?
      end
    end

    card_properties = if params[:properties]
      params[:properties]
    elsif params[:card]
      if defined?(@api_delegate) && @api_delegate.present?
        @api_delegate.card_properties
      else
        populate_params_with_card_properties
      end
    end || {}

    type_property = card_properties.find_ignore_case('type')
    if card.card_type_name.blank?
      card.card_type_name = type_property || @project.card_types.first.name
    end
    card.set_defaults(:hidden_only => true) if (options[:include_defaults] && params[:format] != "xml")
    set_defaults_for_slack_api_call(card)
    card.tag_with(params[:tagged_with]) if params[:tagged_with]
    card.update_properties(card_properties, :include_hidden => true)

    if card.errors.empty?
      card.attach_files(*params[:attachments].values) if params[:attachments]
      card.ensure_attachings(*params[:pending_attachments]) if params[:pending_attachments]
    end

    card.comment = params[:comment]
  end

  def set_defaults_for_slack_api_call(card)
      if(params[:include_defaults] && params[:format] =="xml")
       set_defaults_for_hidden_properties(card)
       set_defaults_for_unhidden_properties(card)
      end
  end

  def create_card_from_params
    clear_readonly_card_param
    card = @project.cards.build
    card.attributes = (params[:card] || {}).slice(:number)
    update_card_from_params(card, :include_defaults => true)
    card
  end

  def card_number_link(card, options = {})
    project    = options.delete(:project) || Project.current
    link_text  = options.delete(:link_text) || "<span id='card_number'>##{card.number}</span>"
    url_params = { :action => 'show', :controller=> "cards", :number => card.number, :project_id => project.identifier }.merge(:only_path => true).merge(options)
    "<a href='#{url_for(url_params)}'>#{link_text}</a>"
  end

  def card_success_message(card, action)
    "Card #{card_number_link(card)} was successfully #{action}."
  end

  def card_successly_created_message_with_included_in_view_check(card, view)
    return card_success_message(card, 'created') if view.cards.include?(card)
    "Card #{card_number_link(card)} was successfully created, but is not shown because it does not match the current filter."
  end

  def clear_readonly_card_param
   if params[:card]
      params[:card].delete('version')
      params[:card].delete('has_macros')
      params[:card].delete('project_id')
      params[:card].delete('updated_at')
      params[:card].delete('modified_by_user_id')
      params[:card].delete('created_at')
      params[:card].delete('created_by_user_id')
    end
  end

  def populate_params_with_card_properties(project = nil, parameters = nil)
    project ||= @project
    parameters ||= params
    property_definitions = project.all_property_definitions
    parameters[:card].inject({}) do |properties, pair|
      if prop = property_definitions.detect{|prop| prop.column_name == pair.first}
        properties[prop.name] = pair.last
      end
      properties
    end
  end

  def add_another_card(attributes, properties)
    properties ||= {}
    properties_params = PropertyValueCollection.from_params(@project, properties, :method => 'post').to_get_params
    properties_params.merge!(@card.properties_with_value.to_get_params)
    redirection_params = {:action => 'new', :controller => "cards", :properties => properties_params}
    redirection_params.merge!(:tagged_with => params[:tagged_with]) if params[:tagged_with]
    redirection_params[:plan_objectives] = params[:plan_objectives] if params[:plan_objectives]
    redirection_params[:card] = attributes if attributes
    redirect_to redirection_params
  end

  private

  def set_defaults_for_hidden_properties(card)
    card.set_defaults(:hidden_only => true)
  end

  def set_defaults_for_unhidden_properties(card)
    card.set_defaults(:hidden_only => false)
  end

  module_function :populate_params_with_card_properties
end
