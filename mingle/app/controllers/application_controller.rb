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

if defined?(ApplicationController)
  raise "should never load ApplicationController twice, which will cause duplicate filter get registered!!!"
end

# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  protect_from_forgery

  module ClassMethods
    def allow(options={})
      if options[:get_access_for] == :none
        self.verify :method => :post
        return
      end
      if options[:get_access_for]
        self.verify :method => [:get, :post, :options], :only => options[:get_access_for]
      end
      if options[:put_access_for]
        self.verify :method =>[:put, :post, :options], :only => options[:put_access_for]
      end
      if options[:delete_access_for]
        self.verify :method => [:delete, :post, :options], :only => options[:delete_access_for]
      end
      non_post_verified_methods = Array(options[:get_access_for]) + Array(options[:put_access_for]) + Array(options[:delete_access_for])
      non_post_verified_methods += [:unsupported_api_call]
      self.verify :method => :post, :except => non_post_verified_methods, :redirect_to => options[:redirect_to]
    end

    def privileges(authorizer_actions)
      controller = self.name.titleize.split[0..-2].join('_').downcase
      ::UserAccess.init(controller, authorizer_actions)
    end
  end
  extend ClassMethods

  include LoginSystem
  include Oauth2::Provider::ApplicationControllerMethods
  include ErrorHandler
  include HelpDocHelper
  include UnsupportedApiCall
  include PluralizationSupport
  include WillPaginateHelper
  include UserAccess
  include LightboxHelper
  include MetricsHelper

  helper :property_editor, :browser_detect, :metrics, :generic_tab_name

  filter_parameter_logging :password, :license_key, :content, :body, :description, :ticket, :token, :api_key, :tab_separated

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
            set_rollback_only if rollback_only? || !controller.send(:error_message).blank?
            raise ForceRollbackException.new if TransactionFilter.rollback_only?
          end
        end
      rescue ForceRollbackException => e
      end
    end
  end

  include FeatureToggleFilter
  before_filter :set_secure_cookie
  before_filter :set_secure_headers
  before_filter :set_csp_header
  before_filter :check_feature_toggle

  before_filter :clear_current_user
  before_filter :clear_thread_local_cache
  before_filter :check_need_install
  before_filter :check_license
  before_filter :authenticated?
  around_filter SampleProfileFilter.new
  before_filter :check_downgrade
  before_filter :check_user
  around_filter :record_current_controller_name
  before_filter :authorize_user_access
  before_filter :need_to_accept_saas_tos
  before_filter :check_license_expiration
  before_filter :site_activity_monitor, :unless => :api_request?
  before_filter :filter_params

  around_filter :wrap_in_transaction
  after_filter :prevent_frame_embedding
  after_filter :clear_thread_local_cache

  def with_absolute_urls
    previous = defined?(@absolute_urls) ? @absolute_urls : false
    @absolute_urls = true
    begin
      yield
    ensure
      @absolute_urls = previous
    end
  end

  def default_url_options(options = {})
    options ||= {}
    options[:only_path] = false if defined?(@absolute_urls) && @absolute_urls
    options
  end

  def render_inline(content)
    render_to_string(:inline => content)
  end

  def render_model_xml(serializable, options={})
    render :xml => model_xml(serializable, options)
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
          return render(:text => escape_and_format(flash[:error]), :status => 403) if oauth_client_request?
          return render(:template => 'errors/external_authentication_error', :status => 403) if Authenticator.using_external_authenticator?

          flash[:error] = "The Mingle account for #{current_user.login.bold} is no longer active. Please contact your Mingle administrator to resolve this issue."
          redirect_to :controller => 'profile', :action => 'login'
        end
        format.xml do
          render :text => "Deactivated user.", :status => 404
        end
      end

      return false
    end
  end

  def oauth_client_request?
    params[:format].nil? && oauth_allowed? && looks_like_oauth_request?
  end

  def api_request?
    uri_path = URI(URI::encode(request.request_uri)).path
    uri_path.ends_with?('.xml') || uri_path.ends_with?('.json') || uri_path.ends_with?('.atom')
  end

  def tab_update_action?
    false
  end

  protected

  def process_content_from_ui(content)
    return content if api_request?
    [ManuallyEnteredMacroEscaper, ManuallyEnteredBangBangImageEscaper].each do |escaper|
      content = escaper.new(content).escape
    end
    content
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

  def set_rollback_only
    TransactionFilter.set_rollback_only
  end

  def default_back_url
    root_url
  end

  def allow_anonymous_accessing?
    CurrentLicense.status.allow_anonymous? && Project.has_anonymous_accessible_project?
  end

  def authorize_user_access
    unless authorized?(params)
      raise UserAccessAuthorizationError, FORBIDDEN_MESSAGE
    end
  end

  def element_highlight_js(element_id)
    "new Effect.SafeHighlight('#{element_id}')"
  end
  helper_method :element_highlight_js

  private

  def clear_current_user
    User.current = nil
  end

  def clear_thread_local_cache
    ThreadLocalCache.clear!
  end

  def record_current_controller_name
    Thread.current[:controller_name] = controller_path
    yield
  ensure
    Thread.current[:controller_name] = nil
  end

  def recheck_license_on_next_request
    flash[:license_error] = nil
    CurrentLicense.clear_cached_license_status!
  end

  def check_license
    if !CurrentLicense.downgrade? && CurrentLicense.status.invalid?
      html_flash[:license_error] = CurrentLicense.status.detail
    end
  end

  def check_downgrade
    if CurrentLicense.downgrade? && !User.current.system? && !User.current.anonymous?  && !MingleConfiguration.display_export_banner?
      @downgrade_view = render_to_string(:partial => "account/downgrade")
    end
  end

  def need_to_accept_saas_tos
    return true unless MingleConfiguration.need_to_accept_saas_tos?
    if !api_request? && !SaasTos.accepted?
      redirect_to :controller => 'saas_tos', :action => 'show'
      return false
    end
    return true
  end

  def check_license_expiration
    return true if MingleConfiguration.saas? && !CurrentLicense.status.paid?
    if !api_request? && !session['license_expiration_warning_dismissed'] && CurrentLicense.status.expiring_soon?
      store_location
      redirect_to :controller => 'license', :action => 'warn'
    end
  end

  def check_supports_password_recovery
    unless Authenticator.supports_password_recovery?
      flash[:error] = "Password recovery is not supported."
      redirect_to root_url
      return false
    end
  end

  def check_supports_password_change
    unless Authenticator.supports_password_change?
      redirect_to root_url
      return false
    end
  end

  def detect_api_version
    API::detect_version(params, @project, self)
  end

  def model_xml(serializable, options={})
    serializable.to_xml({ :version => params[:api_version], :view_helper => @template }.merge(options))
  end

  # safari UTF-8 weirdness ??
  def strip(value)
    unless value.nil?
      value = value.gsub(/\302\240/, '')
      value = value.strip
    end
    value
  end

  def local_request?
    !Rails.env.production? && super
  end

  def error_message
    if flash[:error]
      flash[:error]
    elsif flash.now && flash.now[:error]
      flash.now[:error]
    end
  end

  def escape_and_format(s)
    MingleFormatting.replace_mingle_formatting(ERB::Util.h(s))
  end

  def prevent_frame_embedding
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
  end

  def set_secure_cookie
    request.session_options = request.session_options.merge({:secure => request.ssl?})
  end

  def check_need_install
    if Install::InitialSetup.need_install?
      redirect_to :controller => 'install'
      return false
    end
  end

  def set_secure_headers
    headers['X-CONTENT-TYPE-OPTIONS'] = 'NOSNIFF'
    headers['Strict-Transport-Security'] = 'max-age=16070400; includeSubDomains'
    headers['X-XSS-Protection'] = '1; mode=block'
  end

  def set_csp_header
    if MingleConfiguration.csp?
      csp = {
        :"default-src" => %w('self'),
        :"script-src" => %w(
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
        :"connect-src" => %w(
          'self'
          https://s3-us-west-1.amazonaws.com
          https://*.s3-us-west-1.amazonaws.com
          wss://*.firebaseio.com
          https://*.cloudfront.net
          https://api.mixpanel.com
          https://*.pingdom.net
        ),
        :"img-src" => %w(
          *
          'self'
          data:
          blob:
        ),
        :"style-src" => %w(
          'unsafe-inline'
          'self'
          https://*.cloudfront.net
        ),
        :"font-src" => %w(
          'self'
          https://*.cloudfront.net
          data:
          themes.googleusercontent.com
        ),
        :"frame-src" => %w(
          'self'
          https://www.google.com
          maps.google.com
          calendar.google.com
          https://*.firebaseio.com
          https://*.thoughtworks.com
          platform.twitter.com
        ),
        :"frame-ancestors" => %w('self')
      }

      headers['Content-Security-Policy'] = headers['X-Content-Security-Policy'] = (csp.inject([]) do |result, entry|
        result << "#{entry[0]} #{entry[1].join(" ")};"
        result
      end).join(" ")
    end
  end

  def filter_params
    logger.warn "Found authenticity_token in params. Requested sources controller : #{params[:controller]}, action : #{params[:action]}" if params['authenticity_token'].present?
    params.delete('authenticity_token')
  end
end
