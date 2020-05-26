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

class ApplicationController < ActionController::Base
  MINGLE_ROOT_PATH = '/'

  # Rails will reset session if authenticity_token does not match
  protect_from_forgery with: :exception


  module ClassMethods
    # TODO needs to get all methods for this module from rails 2.3.18 ApplicationController's class methods
    def privileges(authorizer_actions)
      controller = self.name.titleize.split[0..-2].join('_').downcase
      ::UserAccess.init(controller, authorizer_actions)
    end
  end
  extend ClassMethods
  # include Oauth2::Provider::ApplicationControllerMethods
  include ErrorHandler
  include UserAccess
  include MetricsHelper
  include LoginSystem

  before_action :set_csp_header
  before_action :check_feature_toggle

  before_action :clear_current_user
  before_action :clear_thread_local_cache
  before_action :check_need_install
  before_action :check_license
  #TODO: remove this when login system is moved
  # before_action :set_current_user
  before_action :authenticated?
  before_action :check_downgrade
  before_action :check_user
  before_action :need_to_accept_saas_tos
  before_action :check_license_expiration
  before_action :site_activity_monitor, :unless => :api_request?
  before_action :filter_params
  around_action :record_current_controller_name
  before_action :authorize_user_access
  around_action :wrap_in_transaction

  after_action :prevent_frame_embedding

  class TransactionFilter
    def self.set_rollback_only
      Thread.current['rollback_only'] = true
    end

    def self.rollback_only?
      Thread.current['rollback_only']
    end

    class ForceRollbackException < StandardError
    end

    def self.filter(controller)
      # don't use transactions on GETs
      return yield if controller.request.get?

      Thread.current['rollback_only'] = nil
      begin
        Project.transaction do
          Messaging::Mailbox.transaction do
            yield
            TransactionFilter.set_rollback_only if rollback_only? || !controller.send(:error_message).blank?
            raise ForceRollbackException.new if TransactionFilter.rollback_only?
          end
        end
      rescue ForceRollbackException => e
      end
    end
  end

  private

  def check_feature_toggle
    unless FEATURES.active_action?(self.controller_name, self.action_name)
      head :not_found
    end
  end

  def site_activity_monitor
    return if User.current.system? || User.current.anonymous?
    Cache.get("site_activity_#{User.current.id}", 1.hours.to_i) do
      add_monitoring_event('site_activity')
      User.current.update_last_login
      if ProfileServer.configured?
        ProfileServer.sync_user(User.current) rescue nil
      end
      'set'
    end
  end

  def wrap_in_transaction(&block)
    TransactionFilter.filter(self, &block)
  end

  def record_current_controller_name
    Thread.current[:controller_name] = self.class.controller_path
    yield
  ensure
    Thread.current[:controller_name] = nil
  end

  def clear_current_user
    User.current = nil
  end

  def clear_thread_local_cache
    ThreadLocalCache.clear!
  end

  def api_request?
    uri_path = URI(URI::encode(request.path)).path
    uri_path.ends_with?('.xml') || uri_path.ends_with?('.json') || uri_path.ends_with?('.atom')
  end

  def need_to_accept_saas_tos
    return true unless MingleConfiguration.need_to_accept_saas_tos?
    if !api_request? && !SaasTos.accepted?
      redirect_to saas_tos_show_path
      return false
    end
    true
  end

  def check_user
    unless User.current.activated?
      User.current.forget_me(cookies) if User.current.respond_to?(:forget_me)
      reset_session

      flash[:error] = nil
      flash[:notice] = nil
      current_user = User.current
      User.current = User.anonymous
      respond_to do |format|
        format.html do

          #TODO: need to move oauth2 provider plugin
          # return render(:text => escape_and_format(flash[:error]), :status => 403) if oauth_client_request?

          return render(template: 'errors/external_authentication_error', status: 403) if Authenticator.using_external_authenticator?

          flash[:error] = "The Mingle account for #{current_user.login} is no longer active. Please contact your Mingle administrator to resolve this issue."
          redirect_to login_profile_path
        end
        format.xml do
          render plain: 'Deactivated user.', status: 404
        end
      end

      return false
    end
  end

  def authorize_user_access
    unless authorized?(params)
      raise UserAccessAuthorizationError, FORBIDDEN_MESSAGE
    end
  end

  def check_need_install
    if Install::InitialSetup.need_install?
      redirect_to install_index_path
      return false
    end
  end

  def check_license
    if CurrentLicense.expiry_or_reached_max_users?
      html_flash[:license_error] = CurrentLicense.status.detail
    end
  end

  def check_downgrade
    if CurrentLicense.downgrade? && !User.current.system? && !User.current.anonymous?
      @downgrade_view = render_to_string(:partial => 'account/downgrade')
    end
  end

  def check_license_expiration
    return true if MingleConfiguration.saas? && !CurrentLicense.status.paid?
    session[:init] = true
    if !api_request? && !session['license_expiration_warning_dismissed'] && CurrentLicense.status.expiring_soon?
      store_location
      redirect_to :controller => 'license', :action => 'warn'
    end
  end

  def store_location
    session['return-to'] = params if request.path != '/'
  end

  def default_back_url
    root_url
  end

  def set_csp_header
    csp = {
        default_src: %w('self'),
        script_src: %w(
          'unsafe-inline'
          'unsafe-eval'
          'self'
          https://*.pingdom.net
          cdn.mxpnl.com
          https://cdn.firebase.com
          https://*.firebaseio.com
          https://*.cloudfront.net
          https://s3.amazonaws.com
          platform.twitter.com
        ),
        connect_src: %w(
          'self'
          https://s3-us-west-1.amazonaws.com
          https://*.s3-us-west-1.amazonaws.com
          wss://*.firebaseio.com
          https://*.cloudfront.net
          https://api.mixpanel.com
          https://*.pingdom.net
        ),
        img_src: %w(
          *
          'self'
          data:
          blob:
        ),
        style_src: %w(
          'unsafe-inline'
          'self'
          https://*.cloudfront.net
        ),
        font_src: %w(
          'self'
          https://*.cloudfront.net
          data:
          themes.googleusercontent.com
        ),
        frame_src: %w(
          'self'
          https://www.google.com
          maps.google.com
          calendar.google.com
          https://*.firebaseio.com
          https://*.thoughtworks.com
          platform.twitter.com
        ),
        frame_ancestors: %w('self')
    }

    headers['Content-Security-Policy'] = headers['X-Content-Security-Policy'] = (csp.inject([]) do |result, entry|
      result << "#{entry[0].to_s.dasherize} #{entry[1].join(' ')};"
      result
    end).join(' ')
  end

  def filter_params
    logger.warn "Found authenticity_token in params. Requested sources controller : #{params[:controller]}, action : #{params[:action]}" if params['authenticity_token'].present?
  end

  def prevent_frame_embedding
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
  end

  def error_message
    if flash[:error]
      flash[:error]
    elsif flash.now && flash.now[:error]
      flash.now[:error]
    end
  end
end
