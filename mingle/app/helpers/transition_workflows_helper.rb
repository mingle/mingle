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

module TransitionWorkflowsHelper
  WORKFLOW_DROPDOWN_PROMPT = 'Select...'
  
  def card_type_properties
    @card_types.inject({}) do |memo, card_type|
      memo[card_type.id] = card_type.enumerable_property_definitions.map { |property_definition| { :name => property_definition.name, :id => property_definition.id } }
      memo
    end
  end
  
  def enable_generate_transitions
    page << "TransitionWorkflowGenerator.instance.enableGenerateTransitions()"
  end
  
  def disable_generate_transitions
    page << "TransitionWorkflowGenerator.instance.disableGenerateTransitions()"
  end
  
  # TODO: we do want to move these into workflow_preview_warnings.rhtml, it's better to have html tag handled over there
  def previewing_transitions_information_messsage(workflow)
    previews = workflow.transitions.size
    content_tag(:p, "You are previewing the #{'transitions'.plural(previews)} that #{'is'.plural(previews) || 'is'} about to get generated. The #{'transitions'.plural(previews)} below will be created #{'only if'.bold} you complete the process by clicking on 'Generate transition workflow'. Also note that the listed hidden date #{'properties'.plural(previews)} will be created along with the #{'transitions'.plural(previews)}.")
  end
  
  def existing_transitions_warning_message(workflow)
    link_back_to_list = link_to('here', :controller                       => 'transitions',
                                        :action                           => 'list',
                                        :filter => {:card_type_id => workflow.selected_card_type.id, :property_definition_id => workflow.selected_property_definition.id})
    existing = workflow.existing_transitions_count
    unless workflow.existing_transitions_count.zero?
      "<p>There #{'is'.plural_verb(existing)} already #{existing.bold} #{'transitions'.plural(existing)} using #{workflow.selected_card_type.name.escape_html.bold} and #{workflow.selected_property_definition.name.escape_html.bold}. Click #{link_back_to_list} to view these existing transitions.</p>"
    end
  end
  
end
