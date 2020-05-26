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

class ProfileController < ApplicationController
  include IntegrationsHelper

  helper :history_subscriptions
  helper :integrations, :slack

  NON_AUTHORIZE_ACTIONS = ['login', 'logout', 'recover_password', 'forgot_password']
  ACTIONS_NOT_NEEDING_ID_PARAM = ['authenticate_in_slack']
  before_filter :check_supports_password_recovery, :only => ['recover_password', 'forgot_password']
  before_filter :check_supports_password_change, :only => ['change_password', 'update_password', 'set_password']
  before_filter :require_user, :except => NON_AUTHORIZE_ACTIONS + ACTIONS_NOT_NEEDING_ID_PARAM
  before_filter :authorize_edit_right, :except => NON_AUTHORIZE_ACTIONS + ACTIONS_NOT_NEEDING_ID_PARAM
  skip_before_filter :check_user, :only => NON_AUTHORIZE_ACTIONS
  skip_before_filter :check_license_expiration
  skip_before_filter :site_activity_monitor, :only => NON_AUTHORIZE_ACTIONS

  skip_filter :need_to_accept_saas_tos

  allow :get_access_for => [:logout, :show, :edit_profile, :change_password, :forgot_password, :login, :api_key, :set_password, :authenticate_in_slack],
        :put_access_for => [:update_profile],
        :redirect_to => {:action => :show}
  privileges UserAccess::PrivilegeLevel::REGISTERED_USER => ["show", "edit_profile", "update_profile", 'api_key', 'update_api_key', 'authenticate_in_slack']

  # overwrite from module LoginSystem
  def protect?(action)
    return false if NON_AUTHORIZE_ACTIONS.include?(action)
    return false if require_valid_ticket
    super(action)
  end

  def login
    @show_copyright = true
    protect_brute_force_attack(params[:user]) do
      sign_in
    end

    if request.method == :post
      Session.clean_expired_sessions
    end
    recheck_license_on_next_request
  end

  def logout
    sign_out(Project.has_anonymous_accessible_project? ? projects_url : login_url)
    recheck_license_on_next_request
  end

  def show
    @slack_team_info = slack_team_info
    if @slack_team_info
      errors = [flash[:error], params[:slack_error]].compact
      flash.now[:error] = errors if errors.any?
      slack_info = slack_user_authorization_info
      @slack_user_signed_in = slack_info[:authenticated]
      @user_info = slack_info[:user]
      flash.now[:notice] = "You have successfully signed in as #{params[:slack_user_name]}" if @slack_user_signed_in && params[:slack_user_name]
    end
    render :template => 'users/show'
  end

  def edit_profile
    clear_password
    render :template => 'users/edit_profile'
  end

  def update_profile
    @user.display_preference.update_preferences(params[:user_display_preference])

    if @user.update_profile(params[:user])
      session[:login] = @user.login
      update_successful("Profile was successfully updated for #{@user.name}.", :controller => 'profile', :action => 'show', :id => @user.id)
    else
      render :template => 'users/edit_profile'
    end
  end

  def set_password
    if recovering_password?
      clear_password
      render :template => 'users/set_password'
    else
      head :forbidden
    end
  end

  def change_password
    clear_password
    render :template => 'users/change_password', :locals => {:action => 'update_password'}
  end

  def update_password
    if !recovering_password?
      if @user.password != User.sha_password(@user.salt, params[:current_password].to_s)
        flash.now[:error] = "The current password you've entered is incorrect. Please enter a different password."
        render :template => 'users/change_password', :locals => {:action => 'update_password'}
        return
      end
    end

    saas_tos_accepted = params.delete(:saas_tos_accepted)
    if check_tos(saas_tos_accepted) && @user.change_password!(params[:user])
      session['user_email'] = @user.email
      target = if Project.accessible_projects_without_templates_for(@user).count == 1
        {:controller => "projects", :action => "show", :project_id => Project.accessible_projects_without_templates_for(@user).first.identifier }
      else
        root_url
      end

      SaasTos.accept(@user) if saas_tos_accepted.present?
      update_successful("Password was successfully changed for #{@user.name}.", target)
    else
      flash.now[:error] = @user.errors.full_messages.join(". ")
      render :template => 'users/change_password', :locals => {:action => 'update_password'}
    end
  end


  def forgot_password
    render :template => 'users/forgot_password'
  end

  def recover_password
    login = params[:login].downcase.strip
    user = User.find_by_login(login)
    if user.nil?
      user = User.find_by_email(login)
    end
    if user
      if user.email.blank?
        set_rollback_only
        flash[:error] = "Your profile does not contain an email address and therefore Mingle is unable to send you a password reset notice. Please contact your Mingle administrator and request that your password be reset."
        redirect_to :action => 'forgot_password'
      else
        begin
          ticket = user.login_access.generate_lost_password_ticket!
          RecoverPasswordMailer.deliver_recover_password(user,
                                                         {:action => 'change_password', :controller => 'profile', :ticket => ticket},
                                                         {:controller => 'projects'})
          flash.now[:notice] = "We have sent an email to the address we have on record. Respond to it within an hour to reactivate your account."
          render :text => '', :layout => true
        rescue Exception => e
          logger.error("Error on sending password recover email:")
          logger.error(e.message)
          logger.error(e.backtrace.join("\n   "))
          set_rollback_only
          flash[:error] = 'This feature is not configured. Contact your Mingle administrator for details.'
          redirect_to :action => 'login'
        end
      end
    else
      set_rollback_only
      flash[:error] = "There is no registered user with sign-in name #{(params[:login].blank? ? '(empty)' : params[:login]).escape_html}"
      redirect_to :action => 'forgot_password'
    end
  end

  def api_key
    render :template => "users/api_key"
  end

  def update_api_key
    @user.update_api_key
    send_data @user.api_key_csv, :filename => "credentials.csv"
  end

  def authenticate_in_slack
    if slack_team_info && !slack_user_authorization_info[:authenticated]
      redirect_to action: :show, id: User.current.id, tab: 'Slack'
    else
      redirect_to root_url
    end
  end

  private

  def clear_password
    @user.password = ""
  end

  def require_user
    @user = User.find(params[:id]) if params[:id]
    @user ||= User.anonymous
  end

  def require_valid_ticket
    return false unless @ticket = params[:lpt] || params[:ticket]
    login_access = LoginAccess.find_by_lost_password_ticket(@ticket)
    if login_access
      @user = login_access.user
      @recovering_password = true
    else
      raise InvalidTicketError, "Your url has expired. Please provide your email again."
    end
  end

  def authorize_edit_right
    user = load_user_from_session_or_cookie
    return true if user && params[:id] && user == User.find(params[:id])
    return true if !user && require_valid_ticket
    return true if !user && !params[:id]
    set_rollback_only
    flash[:error] = FORBIDDEN_MESSAGE
    redirect_to root_url
    false
  end


  def update_successful(message, redirect_options)
    flash[:notice] = message
    redirect_to redirect_options
  end

  def check_tos(saas_tos_accepted)
    if MingleConfiguration.need_to_accept_saas_tos? && !SaasTos.accepted?
      if saas_tos_accepted.blank?
        flash[:error] = "Please accept the Terms of Service"
        return false
      end
    end
    true
  end

  def recovering_password?
    defined?(@recovering_password) && @recovering_password
  end
end
