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

class DataFixesController < ApplicationController

  include Messaging::Base

  before_filter :sysadmin_only
  verify :method => [:put, :post, :options], :only => [:apply]

  def list
    respond_to do |format|

      format.json do
        render :json => DataFixes.list
      end

      format.html do
        render "data_fixes/list"
      end

    end
  end

  def apply
    respond_to do |format|

      format.json do
        unless params[:fix] && params[:fix][:name] && DataFixes.resolve(params[:fix])
          render :json => "Invalid data fix", :status => :not_found
          return
        end

        process_request
        head :ok
      end

      format.html do
        process_request

        # really just an alias to this controller + action, but keeping route the same for familiarity/backwards compatibility
        redirect_to :controller => "sysadmin", :action => "data_fixes"
      end

    end
  end

  def required
    unless params[:fix] && params[:fix][:name] && DataFixes.resolve(params[:fix])
      render :json => "Invalid data fix", :status => :not_found
      return
    end
    render :json => DataFixes.resolve(params[:fix]).required?
  end

  protected

  def process_request
    if params[:fix][:queued] == "true"
      message = Messaging::SendingMessage.new(:fix => params[:fix])
      send_message(DataFixesProcessor::QUEUE, [message])
    else
      DataFixes.apply(params[:fix])
    end
  end

  def sysadmin_only
    head(:forbidden) unless (MingleConfiguration.saas? ? User.current.system? : User.current.admin?)
  end

end
