# -*- coding: utf-8 -*-

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

class TeamController < ProjectAdminController

  include ActionView::Helpers::JavaScriptHelper, InvitesHelper

  allow :get_access_for => [:index, :list, :list_users_for_add_member, :invite_suggestions, :show_user_selector], :redirect_to => { :action => :index }
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["add_user_to_team", 'destroy', "enable_auto_enroll", "list_users_for_add_member", "set_permission"],
  UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => ["show_member_email"],
  UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["invite_user", "invite_suggestions"]

  def index
    list
    respond_to do |format|
      format.html do
        render :action => 'list'
      end

      format.json do
        if params[:page] && params[:page].to_i != @users.current_page
          render(:json => [])
        else
          render(:json => users_data(@users))
        end
      end

      format.xml do
        render_model_xml @project.users.collect{ |u| ProjectsMember.new(@project, u) }, :root => "projects_members", :dasherize => false
      end
    end
  end

  def list
    @search = ManageUsersSearch.new search_params, User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = @project.users.search(@search.query, params[:page], search_params)
    flash.now[:info] = @search.result_message(@users, 'team members') unless @search.blank?
  end

  def list_users_for_add_member
    @search = ManageUsersSearch.new search_params, User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = User.search(@search.query, params[:page])

    if params[:user_id]
      @users = [User.find(params[:user_id])]
      render :template => 'team/single_user_for_adding'
      return
    end

    flash.now[:info] = @search.result_message(@users) unless @search.blank?
  end

  def show_user_selector
    @search = ManageUsersSearch.new(search_params, true)
    @users = @project.users.search(@search.query, params[:page], search_params)
    respond_to do |format|
      format.json do
        @data = pagination_data_attrs(@users).merge('data-users' => users_data(@users))
        render(:json => @data)
      end

      format.js do
        @data = pagination_data_attrs(@users).merge('data-users' => users_data(@users).to_json)
        render_in_lightbox('team/show_user_selector', :replace => true)
      end
    end
  end

  def invite_suggestions
    users_emails = User.search(params[:term]).map(&:email).compact
    project_users_emails = @project.users.map(&:email)
    invite_emails = users_emails - project_users_emails
    render :json => invite_emails
  end

  def invite_user
    email = params[:email]
    user = User.find_by_email(email)

    if !invites_enabled? && request.format != Mime::JSON
      head(:method_not_allowed)
      return
    end

    if user.nil? && CurrentLicense.registration.max_active_full_users_reached?
      add_monitoring_event('invite_when_license_full')
      error_html = if MingleConfiguration.new_buy_process?
                     buy_popup("To add another user, you'll have to upgrade your plan.")
                   else
                     render_to_string(:template => 'team/invite_to_team_failed', :layout => false, :locals => { :user_count => CurrentLicense.registration.max_active_full_users})
                   end
      render :json => {'errorHtml' =>  error_html}.to_json, :status => :unprocessable_entity
      return
    end

    message_type, status = if user
      [:deliver_invitation_for_existing_user, :ok]
    else
      user = User.create_from_email(email)
      [:deliver_invitation_for_new_user, :created]
    end

    if user.valid?
      InviteToTeamMailer.send(message_type, :inviter => User.current, :invitee => user, :project => @project)
      @project.reload
      @project.add_member(user)
      _license_alert_message = show_low_on_licenses_alert? ? license_alert_message : nil
      buy = MingleConfiguration.new_buy_process? && CurrentLicense.registration.max_active_full_users_reached? ? buy_popup('Invitation sent! Max active user limit is reached, you need to upgrade to add more users.') : nil
      render :json => {:id => user.id, :name => user.name, :icon => @template.user_icon_url(user), :color => Color.for(user.name), :buy => buy, :license_alert_message => _license_alert_message}.to_json, :status => status
    else
      render :json => { 'errorMessage' => user.errors.full_messages.join("\n") }.to_json, :status => :unprocessable_entity
    end

  end

  def add_user_to_team
    @user = User.find(params[:user_id])
    @project.add_member(@user, params[:readonly] ? :readonly_member : :full_member)
    flash.now[:notice] = "#{@user.name.bold} has been added to the #{@project.name.bold} team successfully."
    render(:update) do |page|
      page.refresh_flash
      page.replace @user.html_id, :partial => 'user_for_add_member', :object => @user
    end
  end

  def destroy
    @selection = MultiMemberSelection.for_user_selection(@project, params[:selected_users])
    destroy_selection(:users_tab)
  end

  def set_permission
    member = @project.users.find(params[:user_id])
    role = params[:membership][:permission]

    return render :text => "#{member.name.bold} is restricted to only light user access", :status => :bad_request if member.invalid_role?(role)

    @project.add_member(member, role)
    flash[:notice] = "#{member.name.bold} is now a #{@project.role_for(member).name.downcase}."
    redirect_url = list_url_options('users_tab', :escape => false)
    render(:update) do |page|
      page.redirect_to(redirect_url)
    end
  end

  def always_show_sidebar_actions_list
    ['list', 'list_users_for_add_member']
  end

  def enable_auto_enroll
    @project.update_attribute(:auto_enroll_user_type, params[:auto_enroll_user_type])
    if request.xhr?
      render :nothing => true
    else
      redirect_to list_url_options
    end
  end

  private
  def users_data(users)
    users.map do |user|
      {
        :id => user.id.to_s,
        :login => user.login,
        :name => user.name,
        :icon => @template.user_icon_url(user),
        :color => Color.for(user.name),
        :label => user.name + user.login #for searching through the team list
      }
    end
  end

  def buy_popup(msg)
    @include_planner = CurrentLicense.status.enterprise?
    @buy_tier = CurrentLicense.status.buy_tier
    @message = msg
    render_to_string(:partial => 'account/edit')
  end

  def destroy_selection(redirect_to_tab)
    if @selection.blank?
      redirect_to list_url_options(redirect_to_tab)
      return
    end

    unless params[:confirm] || @selection.no_deletion_warnings?
      return render :template => "team/confirm_destroy", :locals => {:tab => redirect_to_tab }
    end

    @selection.delete_all
    if @selection.any_errors?
      flash[:error] = @selection.error_message
      set_rollback_only
      redirect_to list_url_options(redirect_to_tab)
    else
      flash[:notice] = @selection.successful_removal_message
      redirect_to list_url_options(redirect_to_tab)
    end
  end

  def list_url_options(redirect_to_tab=params[:tab], extra_options={})
    {:action => 'list', :tab => redirect_to_tab }.merge(extra_options).update(params.slice(:page, :selected_memberships, :search))
  end

  def pagination_data_attrs(collection)
    {
      'data-current-page' => collection.current_page,
      'data-per-page' => collection.per_page,
      'data-total-entries' => collection.total_entries,
      'data-total-pages' => collection.total_pages
    }
  end

  def search_params
    return {} if params[:search].blank?
    params[:search]
  end
end
