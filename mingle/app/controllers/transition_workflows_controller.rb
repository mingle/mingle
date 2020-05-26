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

class TransitionWorkflowsController < ProjectAdminController
  helper :transitions

  allow :get_access_for => [:new, :preview]

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["new"]

  def new
    @card_types = @project.card_types
  end

  def preview
    workflow = TransitionWorkflow.new(@project, params[:workflow])
    workflow.build
    render :update do |page|
      if workflow.workflow_transitions.any?
        page.replace_html 'preview_transitions', :partial => 'transitions/transition', :collection => workflow.workflow_transitions, :locals => { :actions_from => 'preview_actions', :show_action_links => false, :div_class => 'transition-workflow-container' }
        page.enable_generate_transitions
        page.replace_html 'flash', :partial => 'workflow_preview_warnings', :locals => { :workflow => workflow }
      else
        page.replace_html 'flash'
        page.disable_generate_transitions
        page.replace_html 'preview_transitions', content_tag('div', "There is no transition to preview because the selected property does not have any values.", :class => 'no-transition-message')
      end
    end
  end

  def generate
    workflow = TransitionWorkflow.new(@project, params[:workflow])
    workflow.create!
    transition_names         = workflow.workflow_transitions.map { |workflow_transition| workflow_transition.name.bold }
    generated_property_names = workflow.workflow_transitions.map { |workflow_transition| workflow_transition.generated_date_property_definition.name.bold }
    count = transition_names.size
    flash[:notice] = "#{'Transitions'.plural(count)} %s and #{'properties'.plural(count)} %s #{'was'.plural(count)} successfully created." % [ transition_names.to_sentence(:last_word_connector => ' and '), generated_property_names.to_sentence(:last_word_connector => ' and ') ]
    redirect_to :controller => 'transitions', :action => 'list', :filter => { :card_type_id => workflow.selected_card_type.id, :property_definition_id => workflow.selected_property_definition.id }
  end
end
