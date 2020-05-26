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

class RevisionsController < ProjectApplicationController

  allow :get_access_for => :show

  def current_tab
    DisplayTabs::SourceTab.new(@project)
  end

  def show
    unless @project.can_connect_to_source_repository?
      html_flash.now[:error] = (render_help_link('Configure Project Repository Page', :class => 'page-help-in-message-box') +
        'Error in connection with repository. Please contact your Mingle administrator and check your logs.')
      render :text => '', :layout => true
      return false
    end

    @mingle_revision = @project.revisions.find_by_identifier(params[:rev])
    @revision_show_error = revision_not_in_mingle_error if @mingle_revision.nil?
    @view_cache = RevisionsViewCache.new(@project) if @revision_error.nil?
    @view_cache.remove_error_file(params[:rev])  # ensure bg job re-attempts caching if it previously failed
    render :template => 'revisions/show'
  end

  private

  def revision_not_in_mingle_error
    "#{@project.repository_vocabulary['revision'].titleize} #{params[:rev]} does not yet exist in this project. Most likely Mingle has not yet cached this #{@project.repository_vocabulary['revision']} and you can check back in a few minutes. If this is not a recent #{@project.repository_vocabulary['revision']} please check that it exists in your source #{@project.repository_vocabulary['repository']}."
  end

end
