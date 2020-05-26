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

class UsersController < ApplicationController
  helper :history_subscriptions
  helper :integrations, :slack
  helper_method :list_action_url


  class UserProfileAuthorizationError < StandardError; end

  before_filter :check_supports_password_change, :only => ['change_password','update_password']
  before_filter :require_user, :except => ['index', 'list', 'new', 'create', 'hide_sidebar', 'show_sidebar', 'delete', 'mark_notification_read', 'plan']

  allow :get_access_for => [:index, :list, :new, :show, :change_password, :edit_profile, :select_project_assignments, :deletable, :avatar, :plan],
        :put_access_for => [:update_profile, :mark_notification_read, :update_api_key],
        :redirect_to => {:action => :list}

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN  => ["toggle_activate", "toggle_light", "list", "index", "new", "create", "edit_profile", "update_profile", "change_password", "update_password", "toggle_admin", "delete", "plan", "deletable"],
             UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["show", "select_project_assignments", "assign_to_projects", "list", "index"]

  def require_user
    @user = User.find_by_id_exclude_system(params[:id])
  end

  def plan
    render :plan
  end

  def index
    list
    respond_to do |format|
      format.html { render :action => 'list' }
      format.xml { render_user_xml User.find_all_in_order }
      format.js do
        render(:update) { |page| page.replace_html 'content', :partial => 'users_list' }
      end
    end
  end

  def list
    registration = CurrentLicense.registration
    set_if_maxs_reached_on_license(registration)
    html_flash[:info] = registration.license_warning_message if (registration.license_warning_message && User.current.admin?)
    params[:search] ||= {:order_by => 'name', :direction => 'ASC'}
    @search = ManageUsersSearch.new params[:search], User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = User.search(@search.query, params[:page], :exclude_deactivated_users => @search.exclude_deactivated_users?, :order_by => @search.order_by, :direction => @search.direction)
    flash.now[:info] = @search.result_message(@users) unless @search.blank?
  end

  def deletable
    @users = User.deletable_users
  end

  def new
    registration = CurrentLicense.registration
    html_flash[:info] = registration.license_warning_message if registration.license_warning_message
    if registration.max_active_full_users_reached? && registration.max_active_light_users_reached?
      redirect_to list_action_url
    end
    @user = User.new
    set_if_maxs_reached_on_license(registration)
    @user.user_type = 'light' if @max_active_full_users_reached
  end

  def show
    return display_404_error(nil) unless @user

    respond_to do |format|
      format.html do
        render :template => 'users/show'
      end
      format.xml do
        render_user_xml @user
      end
    end
  end

  def avatar
    icon_url = @template.user_icon_url(@user)
    redirect_to icon_url
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      add_monitoring_event('create_user', {'user_login' => @user.login})
      recheck_license_on_next_request
      respond_to do |format|
        format.html do
          role = @user.admin? ? "Administrator" : (@user.light? ? 'Light user' : 'Full user')
          flash[:notice] = "#{role} was successfully created."
          redirect_to list_action_url
        end
        format.xml do
          head :created, :location => rest_user_show_url(:id => @user.id, :format => 'xml')
        end
      end
    else
      set_rollback_only
      respond_to do |format|
        format.html do
          if message = CurrentLicense.registration.license_warning_message
            html_flash.now[:info] = message
          end
          render :action => 'new'
        end
        format.xml do
          render :xml => @user.errors.to_xml, :status => 422
        end
      end
    end
  end

  def edit_profile
    @user.password = ""
  end

  def select_project_assignments
    select_project_assignments_html = render_to_string(:partial => 'select_project_assignments')
    render(:update) do |page|
      page.inputing_contexts.update(select_project_assignments_html)
    end
  end

  def assign_to_projects
    assigments = params[:project_assignments].values.reject { |project_assignment| project_assignment[:project].blank? }

    projects = assigments.collect do |project_assignment|
      project_identifier = project_assignment["project"]
      project = Project.find_by_identifier(project_identifier)
      next if !project.admin?(User.current)
      project.add_member(@user, project_assignment["permission"])
      ProjectCacheFacade.instance.clear_cache(project_identifier)
      project
    end.compact.uniq

    flash[:notice] = "#{@user.name.bold} has been added to #{'project'.plural(projects.size)} #{projects.collect(&:name).bold.to_sentence} successfully."
    redirect_to :back
  end

  def update_profile
    if request.method == :get
      redirect_to list_action_url
      return
    end

    @user.display_preference.update_preferences(params[:user_display_preference])

    params[:user].delete(:last_login_at)
    if @user.admin_update_profile(params[:user])
      respond_to do |format|
        format.html do
          flash[:notice] = "Profile was successfully updated for #{@user.name}."
          redirect_to :action => 'show'
        end
        format.xml do
          render_user_xml @user
        end
      end
    else
      set_rollback_only
      respond_to do |format|
        format.html do
          flash.now[:error] = @user.errors.full_messages.map { |error| error.escape_html }
          render :template => 'users/edit_profile'
        end
        format.xml do
          render :xml => @user.errors.to_xml, :status => 422
        end
      end
    end
  end

  def change_password
    @user.password = ""
    render :template => 'users/change_password', :locals => {:action => 'update_password'}
  end

  def update_password
    if @user == User.current && @user.password != User.sha_password(@user.salt, params[:current_password].to_s)
      flash.now[:error] = "The current password you've entered is incorrect. Please enter a different password."
      render :template => 'users/change_password', :locals => {:action => 'update_password'}
      return
    end

    if @user.change_password!(params[:user])
      flash[:notice] = "Password was successfully changed for #{@user.name}."
      redirect_to (params[:search].present? ? list_action_url : {:action => 'show'})
    else
      set_rollback_only
      flash[:error] = @user.errors.full_messages
      redirect_to({:action => 'change_password', :id => @user}.merge(@template.list_action_params))
    end
  end

  def toggle_admin
    unless @user.activated?
      flash[:error] = "#{@user.name.bold} is deactivated!"
    else
      @user.admin = !@user.admin?
      @user.save
      if @user.errors.empty?
        recheck_license_on_next_request
        flash[:notice] = "#{@user.name.bold} is #{@user.admin? ? 'now' : 'not'} an administrator."
      else
        set_rollback_only
        flash[:error] = @user.errors.full_messages
      end
    end
    redirect_to_user_list_page
  end

  def toggle_activate
    if @user == User.current
      flash[:error] = "#{@user.name.bold} has logined!"
    else
      @user.update_attribute(:activated, !@user.activated?)
      if @user.errors.empty?
        recheck_license_on_next_request
        flash[:notice] = "#{@user.name.bold} is now #{@user.activated? ? 'activated' : 'deactivated'}."
      else
        set_rollback_only
        flash[:error] = @user.errors.full_messages
      end
    end
    redirect_to_user_list_page
  end

  def toggle_light
    @user.light = !@user.light?
    @user.save
    if @user.errors.empty?
      recheck_license_on_next_request
      flash[:notice] = "#{@user.name.bold} is now a #{@user.light? ? 'light' : 'full'} user."
    else
      set_rollback_only
    end
    redirect_to_user_list_page
  end

  def hide_sidebar
    session[:hide_sidebar] = true
    render :nothing => true
  end

  def show_sidebar
    session[:hide_sidebar] = false
    render :nothing => true
  end

  def delete
    users_to_delete = User.batched_find(params[:user_ids])

    if users_to_delete.include?(User.current)
      flash[:error] = "Cannot delete yourself, #{User.current.name.bold}."
    else
      if users_to_delete.all?(&:destroy)
        flash[:notice] = "#{users_to_delete.collect(&:login).to_sentence.bold} deleted successfully."
      else
        set_rollback_only
        flash[:error] = users_to_delete.collect { |u| u.errors.full_messages }.join
      end
    end
    redirect_to deletable_list_url
  end

  def mark_notification_read
    user = User.current
    user.mark_notification_read(params[:message])
    user.save
    render :nothing => true
  end

  def update_api_key
    @user.update_api_key
    send_data @user.api_key_csv, :filename => "credentials.csv"
  end

  private

  def render_user_xml(users)
    render_model_xml users, :with_last_login_time => User.current.admin?
  end

  def list_action_url
    { :action => 'list' }.merge(@template.list_action_params)
  end

  def redirect_to_user_list_page
    url = list_action_url
    render(:update) do |page|
      page.redirect_to url.merge(:escape => false)
    end
  end

  def set_if_maxs_reached_on_license(registration)
    @max_active_full_users_reached = registration.max_active_full_users_reached?
    @max_active_light_users_reached = registration.max_active_light_users_reached?
    @full_users_used_as_light = registration.full_users_used_as_light?
  end
end
