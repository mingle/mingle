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

class TransitionsController < ProjectAdminController
  include IntegrationsHelper
  helper :slack, :integrations
  SELECTED_MEMBERS = 'selected_members'
  SELECTED_GROUPS = 'selected_groups'

  allow :get_access_for => [:list, :show, :index, :new, :edit], :redirect_to => {:action => :list}

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>["new", "create", "edit", "update", "destroy"]

  def list
    @transitions = @project.transitions

    respond_to do |format|
      format.html do
        @slack_team_info = slack_team_info
        if @slack_team_info
          get_mapped_transitions
        end
        render :action => 'list'
      end
      format.xml do
        render_model_xml @transitions, :root => "transitions"
      end
    end
  end

  alias_method :index, :list

  def show
    @transition = @project.transitions.find(params[:id])
    render_model_xml @transition
  end

  def new
    @transition = Transition.new
    set_mapped_slack_channels
  end

  def create
    @transition = @project.transitions.build
    @transition.project = @project
    save(@transition, 'new', :created_transition_id)
  end

  def edit
    @transition = @project.transitions.find(params[:id])

    set_mapped_slack_channels
  end

  def update
    @transition = @project.transitions.find(params[:id])
    @transition.clean_actions_and_prerequisites!
    save(@transition, 'edit', :updated_transition_id)
  end

  def destroy
    transition = @project.transitions.find(params[:id])
    transition.destroy
    flash[:notice] = "Transition #{transition.name.bold} was successfully deleted"
    redirect_back_to_list
  end

  def always_show_sidebar_actions_list
    ['list']
  end

  private

  def save(transition, redirect_action, list_redirect_param_name)
    update_transition_attributes(transition)
    return unless user_prerequisites_check_pass?(redirect_action)

    create_missing_enumeration_values(params[:requires_properties], params[:sets_properties])

    if transition.errors.empty? && transition.save
      render_empty_notice_flash
      show_require_user_to_enter_info_box(transition)

      if MingleConfiguration.transition_to_channel_mapping_enabled? && need_to_create_or_update_slack_channel_mapping?
        response = SlackApplicationClient.new(Aws::Credentials.new).map_transition(MingleConfiguration.app_namespace, @project.team.id, params[:selected_slack_channel_id], transition.id, transition.name)
        flash[:info] = (flash[:info] || '') + "Transition #{transition.name} was updated but slack channel failed to update: " +response[:error] if !response[:ok]
      end
      redirect_back_to_list(list_redirect_param_name => transition.id)
    else
      set_rollback_only
      set_mapped_slack_channels
      @selected_channel_id = params[:selected_slack_channel_id]
      flash.now[:error] = transition.errors.full_messages.join('. ')
      render :action => redirect_action
    end
  end

  def need_to_create_or_update_slack_channel_mapping?
    return false if params[:is_selected_channel_inaccessible].eql?('true') || params[:is_selected_channel_inaccessible].eql?(true)
    params[:selected_slack_channel_id] != params[:previously_selected_slack_channel_id]
  end

  def set_mapped_slack_channels
    @slack_team_info = slack_team_info
    if @slack_team_info
      fetch_mapped_slack_channels
    end
  end

  def update_transition_attributes(transition)
    transition.name = params['transition']['name']
    transition.require_comment = params['transition']['require_comment'] == 'true'
    transition.card_type = @project.card_types.find_by_name(params['transition']['card_type_name'])

    transition.add_value_prerequisites(params[:requires_properties])
    transition.add_set_value_actions(params[:sets_properties])
    transition.add_remove_card_from_tree_actions(params[:sets_tree_belongings])
    transition.add_user_prerequisites((params[:user_prerequisites] || {}).values) if params[:used_by] == SELECTED_MEMBERS
    transition.add_group_prerequisites((params[:group_prerequisites] || {}).values) if params[:used_by] == SELECTED_GROUPS
  end

  def user_prerequisites_check_pass?(redirect_action)
    if params[:used_by] == SELECTED_MEMBERS && (params[:user_prerequisites] || []).empty?
      return rollback_with_warning("Please select at least one team member", redirect_action)
    end
    if params[:used_by] == SELECTED_GROUPS && (params[:group_prerequisites] || []).empty?
      return rollback_with_warning("Please select at least one group", redirect_action)
    end
    return true
  end

  def rollback_with_warning(message, redirect_action)
    set_rollback_only
    flash.now[:error] = message
    render :action => redirect_action
    return false
  end

  def create_missing_enumeration_values(requires_property_names_and_values, sets_property_names_and_values)
    PropertyDefinition.create_new_enumeration_values_from(requires_property_names_and_values, @project) if requires_property_names_and_values
    PropertyDefinition.create_new_enumeration_values_from(sets_property_names_and_values,     @project) if sets_property_names_and_values
  end

  def show_require_user_to_enter_info_box(transition)
    if transition.require_user_to_enter? || transition.has_optional_input?
      flash[:info] = "Transition #{transition.name.bold} cannot be activated using the bulk transitions panel because some properties are set to #{Transition::USER_INPUT_REQUIRED} or #{Transition::USER_INPUT_OPTIONAL}."
    end
  end

  def redirect_back_to_list(extra_params = {})
    redirect_to({ :action => 'list', :filter => params[:filter] }.merge(extra_params))
  end

  def render_empty_notice_flash
    # JS will set the actual message.
    flash[:notice] = ""
  end

  def get_mapped_transitions
    list_channels_response = fetch_slack_channels
    @team_mapped = list_channels_response[:teamMapped]
    transitions = list_channels_response[:transitions] || {}
    @mapped_transitions = {}
    transitions.each do | transition_id, channel_id |
      channel = list_channels_response[:channels].find { |ch| ch[:id] == channel_id }
      @mapped_transitions[transition_id.to_i] = channel.nil? ? channel : OpenStruct.new(channel)
    end
  end

  def fetch_mapped_slack_channels
    list_channels_response = fetch_slack_channels
    @team_mapped = list_channels_response[:teamMapped]
    channels = list_channels_response[:channels]
    @mapped_channels = (select_mapped_channel(channels).map { |ch| OpenStruct.new(ch) } || []).sort_by(&:name) unless channels.nil?
    transitions = list_channels_response[:transitions]
    @selected_channel_id = transitions[@transition.id.to_s] unless transitions.nil?
  end

  def select_mapped_channel(channels)
    channels.select { |ch| ch[:mapped] && ch[:teamId] == Project.current.team.id }
  end

  def fetch_slack_channels
    return {} unless MingleConfiguration.transition_to_channel_mapping_enabled?
    slack_client.list_channels(MingleConfiguration.app_namespace, Project.current.team.id, User.current.id)
  end
end
