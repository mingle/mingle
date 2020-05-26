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

class AsynchRequestsController < ApplicationController

  allow :get_access_for => [:progress, :open_progress]

  def progress
    @title = "Progress"
    if request.xhr?
      @asynch_request = User.current.asynch_requests.find(params[:id])
      flash.now[@asynch_request.info_type] = progress_msg

      if @asynch_request.completed?
        recheck_license_on_next_request
        render_success
      else
        render_in_progress
      end
    end
  end

  def open_progress
    @asynch_request = User.current.asynch_requests.find(params[:id])
    flash.now[@asynch_request.info_type] = progress_msg
    render_in_lightbox 'asynch_requests/progress', :locals => {:deliverable => deliverable}
  end

  def deliverable
    deliverable_type = params[:project_id] ? Deliverable::DELIVERABLE_TYPE_PROJECT : Deliverable::DELIVERABLE_TYPE_PROGRAM
    deliverable_id = params[:project_id] || params[:program_id]

    @deliverable ||= Deliverable.find_by_identifier_and_type(deliverable_id, deliverable_type)
  end

  private

  def render_success
    controller = self

    render(:update) do |page|
      page.replace 'asynch-request-flash', :partial => 'asynch_requests/flash'
      page.progress_bar.update 'progress-indicator', 1
      page.hide "asynch_request_spinner"
      if url = @asynch_request.complete_url(controller, params)
        flash[@asynch_request.info_type] = flash.now[@asynch_request.info_type]
        page.redirect_to url.is_a?(Hash) ? url.merge(:escape => false) : url
      end
      page.show "close_lightbox_link"
      page << asynch_request_progress_lightbox_fix_height_js
    end
  end

  def render_in_progress
    block_accessible_deliverable = deliverable
    render(:update) do |page|
      page.replace 'asynch-request-flash', :partial => 'asynch_requests/flash'
      page.progress_bar.update 'progress-indicator', @asynch_request.progress_percent.to_f
      page << delayed_remote_call(:url => @asynch_request.callback_url(params, block_accessible_deliverable))
      page << asynch_request_progress_lightbox_fix_height_js
    end
  end

  def progress_msg
    @asynch_request.progress_msg.blank? ? 'Importing in progress...' : @asynch_request.progress_msg
  end

end
