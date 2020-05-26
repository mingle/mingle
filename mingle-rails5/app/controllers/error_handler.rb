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

  FORBIDDEN_MESSAGE = 'Either the resource you requested does not exist or you do not have access rights to that resource.'

  class UserAccessAuthorizationError < StandardError
  end

  class InvalidResourceError < StandardError
  end

  class InvalidTicketError < StandardError
  end

  class InvalidArgumentError < StandardError
  end

  def self.included(base)
    base.class_eval do
      #TODO: Need to handle exception for oauth2 provider once its moved
      rescue_from Exception do |exception|
        Alarms.configured {Honeybadger.notify(exception)}
        display_500_error
      end
      rescue_from InvalidArgumentError, with: :display_400_error
      rescue_from UserAccessAuthorizationError, UsersController::UserProfileAuthorizationError, with: :display_403_error
      rescue_from InvalidResourceError, ActionController::RoutingError, ActiveRecord::RecordNotFound, with: :display_404_error
      rescue_from ActiveRecord::ConnectionNotEstablished do |exception|
        render(plain: '', status: '404 Not Found')
      end
      rescue_from ActiveRecord::ConnectionTimeoutError, with: :display_500_error
      rescue_from ActionController::MethodNotAllowed, with: :display_405_error
      rescue_from InvalidTicketError do |exception|
        flash[:error] = exception.message
        redirect_to forgot_password_profile_path
      end
    end
  end

  def display_400_error(exception)
    respond_to do |format|
      format.html do
        render template: 'errors/unknown', :status => 400, layout: 'error'
      end
      format.atom do
        render :text => exception.message,  :status => 400
      end
      format.xml do
        #TODO: need to serialize exception in xml format once customized xml serializer is moved
        render xml: exception.message, :status => 400
      end
    end
  end

  def display_403_error(exception)
    if exception.is_a?(UserAccessAuthorizationError) && @project
      logger.info("User '#{User.current.try(:login)}' tried to access project '#{@project.try(:identifier)}' but was not authorized")
    end

    respond_to do |format|
      #TODO: handle exception once oauth plugin is moved
      # return render(:text => exception.message,  :status => 403) if oauth_client_request?

      back_url = User.current.anonymous? ? login_url : default_back_url
      format.html do
        if back_url == login_profile_url
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
        render plain: exception.message,  status: 403
      end
      format.xml do
        #TODO: need to serialize exception in xml format once customized xml serializer is moved
        render xml: exception.message, status: 403
      end
      format.js do
        flash[:error] = exception.message
        render(:update) { |page| page.reload }
      end
    end
  end

  def display_404_error(exception)
    logger.error('404 displayed')
    #TODO: handle exception once oauth plugin is moved
    # return render(:text => "Either the resource you requested does not exist or you do not have access rights to that resource", :status => 404) if oauth_client_request?

    if api_request? || request.xhr?
      render plain: <<-XML, status: 404
      <?xml version="1.0" encoding="UTF-8"?>
      <errors>
        <error>
          Either the resource you requested does not exist or you do not have access rights to that resource
        </error>
      </errors>
            XML
    else
      render :template => 'errors/not_found', :status => 404, :layout => 'error'
    end
  end

  def display_405_error(exception)
    # TODO: do we really nead to set headers here.
    # exception.handle_response!(response)
    #TODO: handle exception once oauth plugin is moved
    # return render(:text => "Either the resource you requested does not exist or you do not have access rights to that resource",  :status => :method_not_allowed) if oauth_client_request?

    unless api_request?
      render :template => 'errors/not_found', :status => :method_not_allowed, :layout => 'error'
    else
      render plain: exception.message, status: :method_not_allowed
    end
  end

  def display_500_error
    Rails.logger.error('500 displayed')

    #TODO: handle exception once oauth plugin is moved
    # return render(:text => "We're sorry but Mingle found a problem it couldn't fix",  :status => 500) if oauth_client_request?

    render template: 'errors/unknown', status: 500, layout: 'error'
  end


end
