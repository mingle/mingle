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

class SourceController < ProjectApplicationController
  verify :method => :get, :only => [:index]

  before_filter :check_repository_connectivity, :check_source_browsable, :check_source_ready, :check_repository_empty, :only => :index

  def current_tab
    DisplayTabs::SourceTab.new(@project)
  end

  def index
    @project.reload

    if request.post?
      path = params[:path]
      path = path.split('/') if path.respond_to?(:split)
      redirect_to :action => 'index', :path => path, :rev => params[:rev]
      return
    end

    @view_revision = params[:rev]

    begin
      render_repo_structure_as_on @view_revision
    rescue Repository::NoSuchRevisionError => e
      logger.error {e}
      flash[:not_found] = "No such #{@project.repository_vocabulary['revision']} #{@view_revision.bold}, showing youngest #{@project.repository_vocabulary['revision']}."

      head_term = @project.repository_vocabulary['head']
      if @view_revision == head_term
        flash[:error] = "No #{@project.repository_vocabulary['revision']} #{head_term.bold} found."
        redirect_to :controller => 'repository'
      else
        redirect_to :action => 'index', :path => params[:path], :rev => head_term
      end
    end
  end

  private

  def render_repo_structure_as_on(revision)
    path = ((params[:path].is_a?(Array) ? params[:path] : [params[:path]]) || []).join('/')
    @node = @project.repository_node(path, revision)
    @title = "#{@project.name} #{@project.source_repository_path}"
    if @node.dir?
      @directory = @node
      @children = sorted_children(@directory)
      render :template => 'source/directory'
    elsif @node.binary?
      headers["Content-Type"] = "application/octet-stream"
      headers["Content-Disposition"] = "filename=\"#{@node.name}\";"
      headers["Cache-Control"] = "max-age=0" if request_browser_is_internet_explorer_7

      render :text => Proc.new { |response, output|
        @node.file_contents(output)
      }, :layout => false
    else
      @file = @node
      output = StringIO.new
      @file.file_contents(output)
      output.rewind
      @file_contents = output.read
      render :template => 'source/file'
    end
  end

  def sorted_children(directory)
    directory.children.sort do |left, right|
      if left.dir? and !right.dir?
        -1
      elsif right.dir? and !left.dir?
        1
      else
        left.name <=> right.name
      end
    end
  end

  def request_browser_is_internet_explorer_7
    request.env['HTTP_USER_AGENT'].downcase.include?('msie 7')
  end

  def check_repository_connectivity
    unless @project.can_connect_to_source_repository?
      html_flash.now[:error] = (render_help_link('Configure Project Repository Page', :class => 'page-help-in-message-box') + 'Error in connection with repository. Please contact your Mingle administrator and check your logs.')
      render :text => '', :layout => true
      return false
    end
  end

  def check_source_browsable
    unless @project.source_browsable?
      html_flash.now[:info] = (render_help_link('Source Tab', :class => 'page-help-in-message-box') + "Mingle does not currently support #{@project.repository_name} repository browsing. ")
      render :text => '', :layout => true
      return false
    end
  end

  def check_source_ready
    unless @project.source_browsing_ready?
      html_flash.now[:info] = (render_help_link('Source Tab', :class => 'page-help-in-message-box') + 'Mingle has not finished processing your project repository information. Depending on the size of your repository, this may take a while. Please continue to work as normal.')
      render :text => '', :layout => true
      return false
    end
  end

  def check_repository_empty
    begin
      if @project.source_repository_empty?
        html_flash.now[:notice] = (render_help_link('Source Tab', :class => 'page-help-in-message-box') + 'The repository is empty.')
        render :text => '', :layout => true
        return false
      end
    rescue Exception => e
      error_message = "Mingle can connect to the repository but cannot find the given location. Please check that your project repository settings are configured correctly."
      logger.error("\n#{error_message}\n\nRoot cause of error: #{e}\n#{e.backtrace.join("\n")}\n")
      flash.now[:error] = error_message
      render :text => '', :layout => true
      return false
    end
  end
end
