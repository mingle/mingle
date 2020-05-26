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

module LoginSystem
  BRUTE_FORCE_TIMEOUT = 1.minute
  BRUTE_FORCE_ATTEMPT_LIMIT = 10
  MINGLE_SLACK_API_DATA = 'HTTP_MINGLE_SLACK_API_DATA'
  HTTP_MINGLE_API_KEY = 'HTTP_MINGLE_API_KEY'


  protected

  # a controller can supply its own version of this
  # method that returns false for any actions that
  # do not require authentication.
  def protect?(action)
    true
  end

  def allow_anonymous_accessing?
    false
  end

  def sign_in
    if params['return-to']
      session['return-to'] = params['return-to']
    end

    Authenticator.invalidate_session_external_authentication_if_not_using_external_authenticator(session)

    if !Authenticator.use_mingle_login_page? && session[:redirected_to_external_authentication] == nil
      session[:redirected_to_external_authentication] = true
      redirect_to authentication_redirect_url
      return
    end

    if (request.method == :post) || (session[:redirected_to_external_authentication])
      begin
        if user = self.authenticate
          flash[:notice]  = "Sign in successful"
          redirect_back_or_default(user)
        else
          set_rollback_only
          if (session[:redirected_to_external_authentication])
            if (Authenticator.has_valid_external_authentication_token?(params))
              session[:redirected_to_external_authentication] = nil
              Kernel.log_error(nil, "Mingle encountered an unexpected error when using your external authentication system. This issue is most likely a Mingle configuration problem. Please check that you have supplied correct settings in #{MINGLE_DATA_DIR}/config/auth_config.yml. One possible cause of this is that the user does not exist in Mingle and you have disabled the auto_enroll feature in your configuration." )
              render :template => "errors/external_authentication_error", :status => 401, :layout => 'error'
            else
              redirect_to authentication_redirect_url
              return
            end
          else
            flash.now[:error]  = "Wrong sign-in name or password"
            @login = params[:user][:login]
            render :template => 'users/login'
           end
        end
      rescue CreateFullUserWhileFullUserSeatsReachedException  => e
        flash.now[:error]  = e.message
        render :template => 'users/login'
      end
    else
      render :template => 'users/login'
    end
  end

  def sign_out(logout_redirect_to=nil)
    User.current.forget_me(cookies) if User.current.respond_to?(:forget_me)
    Session.find_by_session_id(request.session_options[:id]).try(:destroy)

    reset_session
    User.current = nil
    if Authenticator.external_logout_unavailable?
      render :template => "errors/connection_failure_error", :status => 404, :layout => 'error', :locals => {:message => 'You could not be logged out. Please contact you Mingle administrator.', :title => "We're unable to log you out of Mingle"}
      return
    elsif Authenticator.external_logout_available?
      redirect_to Authenticator.sign_out_url(self.login_url)
    elsif logout_redirect_to
      redirect_to logout_redirect_to
    else
      render  :template => 'users/logout'
    end
  end

  def authenticate
    user = Authenticator.authenticate?(params, self.url_for({}))
    if user
      store_login_in_session_and_update_last_login(user)
      if self.params[:remember_me]
        user.remember_me_in(cookies)
      else
        user.forget_me(cookies)
      end
    end
    user
  end

  def valid_api_key?(api_key)
    return false unless api_key
    AuthenticationKeys.auth?(api_key)
  end

  def authenticated?
    if is_api_request_from_slack_app?
      user = slack_auth_user
      if user.nil?
        access_denied
        return false
      end
      User.current = user
      Thread.current['origin_type'] = 'slack'
      return true
    elsif valid_api_key?(request.env[HTTP_MINGLE_API_KEY])
      User.current = User::ApiUser.new
      return
    end

    if basic_auth_enabled && basic_authorization_header =~ /Basic (.*)/
      user = basic_authentication($1)
      logger.debug { "[auth] User '#{user.login}' authenticated. [basic auth]" } if user.present?
    end

    if basic_authorization_header =~ /^APIAuth/
      user = hmac_auth
      logger.debug { "[auth] User '#{user.login}' authenticated. [hmac]" } if user.present?
    end

    if request.env.has_key? 'HTTP_X_HUB_SIGNATURE'
      hmac_signature = request.env['HTTP_X_HUB_SIGNATURE'].split("sha1=").last
      username = params['user']
      user = github_auth(username, hmac_signature)

      logger.debug { "[auth] User '#{user.login}' authenticated. [github_hmac_signature]" } if user.present?
    end

    user ||= load_user_from_session_or_cookie
    logger.debug { "[auth] User '#{user.login}' authenticated. [session/cookie]" } if user.present?

    User.current = user
    logger.debug { "[auth] User is unauthenticated." } if user.nil?

    if !protect?(action_name) || user || allow_anonymous_accessing?
      logger.debug { "[auth] User accessing '#{action_name}' allowed. Anonymous access: #{allow_anonymous_accessing?}" }
      return true
    end

    store_location unless request.post?
    access_denied
    logger.debug { "[auth] Access is denied." }
    return false
  end

  def request_api_uri?
    request.request_uri =~ /\A(#{CONTEXT_PATH})?\/api\//
  end

  def load_user_from_session_or_cookie
    return nil if !verified_request? && request_api_uri?
    (session[:login] && User.find_by_login(session[:login], :include => :user_display_preference)) || load_user_from_cookie
  end

  def basic_authentication(credentials)
    login, password = credentials.unpack("m*")[0].split(":", 2)
    protect_brute_force_attack(:login => login) do
      user = BasicAuthenticator.authenticate?(login, password)
      logger.debug { "Authenticated Basic HTTP Authentication request(login name: #{login}): Sign in #{user ? 'successful' : 'failed'}" }
      if user
        user.update_last_login
      else
        render :text => "Incorrect username or password.\n", :status => 401
      end
      user
    end
  end

  def protect_brute_force_attack(user, &block)
    if user.nil? || user[:login].nil?
      return yield
    end

    counter_key = "try_login_#{user[:login]}"
    try_login_count = Cache.get(counter_key, 0).to_i
    if try_login_count >= BRUTE_FORCE_ATTEMPT_LIMIT
      msg = "You have attempted to log in 10 times. Please try again in one minute."
      respond_to do |format|
        format.html do
          flash.now[:warning] = msg
          render :template => 'users/login'
        end
        format.xml do
          render :text => msg, :status => 401
        end
        format.js do
          render :text => msg, :status => 401
        end
      end
    else
      yield.tap do |user|
        if user.is_a?(User) || session[:login]
          Cache.delete counter_key
        else
          Cache.put counter_key, try_login_count.next, BRUTE_FORCE_TIMEOUT
        end
      end
    end
  end

  # overwrite if you want to have special behavior in case the user is not authorized
  # to access the current operation.
  # the default action is to redirect to the login screen
  # example use :
  # a popup window might just close itself for instance
  def access_denied
    unless performed?
      if request.xhr?
        render :text => 'SESSION_TIMEOUT', :status => 401 and return
      end

      respond_to do |format|
        format.html { redirect_to unauthorized_redirect_options }
        format.atom { render :text => "atom feed is not accessible\n",  :status => 401 }
        format.xml do
          headers["WWW-Authenticate"] = %(Basic realm="Welcome Mingle")
          render :text => "Incorrect username or password.\n", :status => 401
        end
      end
    end
  end

  def unauthorized_redirect_options
    {:project_id => nil, :controller => "profile", :action => "login"}
  end

  # store current uri in  the session.
  # we can return to this location by calling return_location
  def store_location
    session['return-to'] = params if request.request_uri != "/"
  end

  # move to the last store_location call or to the passed default one
  def redirect_back_or_default(user)
    if MingleConfiguration.landing_project.present? && User.count <= 2 && Project.not_template.map(&:identifier) == [MingleConfiguration.landing_project]
      redirect_to card_grid_url(landing_tab.params.merge(:project_id => MingleConfiguration.landing_project, :tab => MingleConfiguration.landing_view_name.gsub(/_/, ' ')))
      return
    end

    target_url = if cookies['last-visited-project'] && Project.find_by_identifier(cookies['last-visited-project']) && (Project.find_by_identifier(cookies['last-visited-project']).member?(user) || user.admin?)
      {:controller => 'projects', :action => 'show', :project_id => cookies['last-visited-project']}
    else
      root_url
    end

    if session['return-to'].nil?
      redirect_to target_url
    else
      redirect_to session['return-to']
      session['return-to'] = nil
    end
  end

  def landing_tab
    Project.find_by_identifier(MingleConfiguration.landing_project).with_active_project do |project|
      project.card_list_views.find_by_name(MingleConfiguration.landing_view_name.gsub(/_/, ' '))
    end
  end


  # begin methods for oauth
  def authenticated_with_oauth?
    if user_id = user_id_for_oauth_access_token
      Rails.logger.info("Authentication via oauth success: #{request.url}")
      User.current = User.find_by_id(user_id)
    elsif looks_like_oauth_request? && oauth_allowed?
      Rails.logger.info("Authentication via oauth failed: #{request.url}")
      render :text => 'The OAuth token provided is invalid.',  :status => :unauthorized
      return false
    else
      authenticated_without_oauth?
    end
  end
  alias_method_chain :authenticated?, :oauth


  def current_user_id_for_oauth
    User.current.id.to_s
  end
  alias_method :current_user_id, :current_user_id_for_oauth

  # end methods for oauth

  def authentication_redirect_url
    redirect_url = Authenticator.sign_in_url(self.url_for({}))
    redirect_url << "&login=#{CGI.escape(session['user_email'])}" unless session['user_email'].blank?
    session['user_login'] = nil
    redirect_url
  end

  private

  def load_user_from_cookie
    user = (cookies['login'] && LoginAccess.find_user_by_login_token(cookies['login']))
    store_login_in_session_and_update_last_login(user) if user
    user
  end

  def store_login_in_session_and_update_last_login(user)
    session[:login] = user.login
    user.update_last_login
  end

  def basic_auth_enabled
    if $basic_auth_enabled.nil?
      AuthConfiguration.load
      logger.debug{ "BASIC HTTP AUTH #{$basic_auth_enabled ? 'enabled' : 'disabled'}" }
    end
    $basic_auth_enabled
  end

  def basic_authorization_header
    [
     'REDIRECT_REDIRECT_X_HTTP_AUTHORIZATION',
     'REDIRECT_X_HTTP_AUTHORIZATION',
     'X-HTTP_AUTHORIZATION',
     'HTTP_AUTHORIZATION',
     'Authorization'
    ].each do |key|
      if request.env.has_key?(key)
        return request.env[key]
      end
    end
    return nil
  end

  def hmac_auth
    if user = User.find_by_login(ApiAuth.access_id(request))
      return user if ApiAuth.authentic?(request, user.api_key)
    end
  end

  def github_auth(username, hmac_signature)
    if user = User.find_by_login(username)
      hmac_digest = OpenSSL::Digest::Digest.new('sha1')
      signature_from_api_key = OpenSSL::HMAC.hexdigest(hmac_digest, user.api_key, request.body.read)
      return user if signature_from_api_key == hmac_signature
    end
  end


  def is_api_request_from_slack_app?
   has_api_headers =  [HTTP_MINGLE_API_KEY, MINGLE_SLACK_API_DATA].all? do |key|
        request.env.has_key?(key)
   end
   MingleConfiguration.saas? && has_api_headers && valid_api_key?(request.env[HTTP_MINGLE_API_KEY])
  end

  def slack_auth_user
    decrypted_data = IntegrationsHelper.decrypt_data_from_slack(request.env[MINGLE_SLACK_API_DATA])
    info = JSON.parse(decrypted_data)
    return User::AdminApiUser.new if info['admin']
    return nil unless info['mingleUserId']
    User.find_by_id(info['mingleUserId'])
  rescue JSON::ParserError
  end

end
