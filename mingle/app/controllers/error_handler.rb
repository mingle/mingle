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

module ErrorHandler

  FORBIDDEN_MESSAGE = "Either the resource you requested does not exist or you do not have access rights to that resource."
  SESSION_RECENTLY_ACCESSED_PAGES = 'session_recently_accessed_pages'

  class InvalidTicketError < StandardError
  end

  class FeatureNotConfigured < StandardError
  end

  class UserAccessAuthorizationError < StandardError
  end

  class InvalidResourceError < StandardError
  end

  def self.included(base)
    base.class_eval do
      alias :rescue_mingle_exception :rescue_action_in_public
      alias :rescue_action_locally :rescue_action_in_public
    end
  end

  def verify_resource(resource)
    raise InvalidResourceError, FORBIDDEN_MESSAGE if resource.blank?
    resource
  end

  def authorize_resource(resource)
    raise_user_access_error if resource.blank?
    resource
  end

  def raise_user_access_error
    raise UserAccessAuthorizationError, FORBIDDEN_MESSAGE
  end

  def display_403_error(exception)
    if exception.is_a?(UserAccessAuthorizationError) && @project
      logger.info("User '#{User.current.try(:login)}' tried to access project '#{@project.try(:identifier)}' but was not authorized")
    end

    respond_to do |format|
      return render(:text => exception.message,  :status => 403) if oauth_client_request?

      back_url = User.current.anonymous? ? login_url : default_back_url
      format.html do
        if back_url == login_url
          store_location
        else
          html_flash[:error] = CurrentLicense.status.valid? ? exception.message : CurrentLicense.status.detail
        end

        if request.xhr?
          render(:update) do |page|
            page.redirect_to back_url
          end
        else
          redirect_to back_url
        end
      end
      format.atom do
        render :text => exception.message,  :status => 403
      end
      format.xml do
        render :xml => exception.xml_message, :status => 403
      end
      format.js do
        flash[:error] = exception.message
        render(:update) { |page| page.reload }
      end
    end
  end

  def rescue_action_in_public(exception)
    case exception
    when Murmur::InvalidArgumentError, Oauth2::Provider::HttpsRequired
      display_400_error(exception)
    when UserAccessAuthorizationError, FeatureNotConfigured, UsersController::UserProfileAuthorizationError
      display_403_error(exception)
    when InvalidResourceError, ActionController::RoutingError, ActionController::UnknownAction, ActiveRecord::RecordNotFound
      display_404_error(exception)
    when ActiveRecord::ConnectionTimeoutError
      display_500_error
    when ActiveRecord::ConnectionNotEstablished
      render(:text  => "", :status  => "404 Not Found")
    when ActionController::MethodNotAllowed
      display_405_error(exception)
    when InvalidTicketError
      flash[:error] = exception.message
      redirect_to :controller => "profile", :action => "forgot_password"
    else
      Alarms.configured { notify_honeybadger(exception) }
      display_500_error
    end
  end

  def show_errors(errors)
    if errors.size == 1
      flash.now[:error] = errors.first
    elsif errors.size > 1
      html_flash.now[:error] = "<ul><li>#{errors.collect(&:escape_html).join('</li><li>')}</li></ul>"
    end
  end

  def display_400_error(exception)
    respond_to do |format|
      format.html do
        render :template => "errors/unknown", :status => 400, :layout => 'error'
      end
      format.atom do
        render :text => exception.message,  :status => 400
      end
      format.xml do
        render :xml => exception.xml_message, :status => 400
      end
    end
  end

  def display_404_error(exception)
    logger.error("404 displayed")
    return render(:text => "Either the resource you requested does not exist or you do not have access rights to that resource",  :status => 404) if oauth_client_request?

    if api_request? || request.xhr?
      render :text => <<-XML, :status => 404
<?xml version="1.0" encoding="UTF-8"?>
<errors>
  <error>
    Either the resource you requested does not exist or you do not have access rights to that resource
  </error>
</errors>
XML
    else
      render :template => "errors/not_found", :status => 404, :layout => 'error'
    end
  end

  def display_405_error(exception)
    exception.handle_response!(response)
    return render(:text => "Either the resource you requested does not exist or you do not have access rights to that resource",  :status => :method_not_allowed) if oauth_client_request?

    unless api_request?
      render :template => "errors/not_found", :status => :method_not_allowed, :layout => 'error'
    else
      render :text => exception.message, :status => :method_not_allowed
    end
  end

  def display_500_error
    Rails.logger.error("500 displayed")

    return render(:text => "We're sorry but Mingle found a problem it couldn't fix",  :status => 500) if oauth_client_request?

    render :template => "errors/unknown", :status => 500, :layout => 'error'
  end
end
