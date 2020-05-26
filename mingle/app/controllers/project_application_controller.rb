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

class ProjectApplicationController < ApplicationController
  class ProjectActivationFilter
    def self.filter(controller)
      if controller.project
        controller.project.with_active_project do
          yield
        end
      else
        yield
      end
    end
  end

  class << self
    def skip_project_cache_clearing_on(*actions)
      ProjectCacheFacade.instance.use_cached_projects_for(self.name, actions)
    end
  end

  skip_before_filter :authorize_user_access
  before_filter :load_project
  before_filter :ensure_project
  around_filter ProjectActivationFilter
  before_filter :clear_card_context, :if => proc {|controller| controller.params[:format] == 'html'}
  before_filter :require_project_membership_or_admin
  before_filter :authorize_user_access_for_project
  after_filter :update_project_cache
  after_filter :clear_active_project!

  def current_tab
    DisplayTabs::OverviewTab.new(@project)
  end

  def project
    @project
  end

  def card_context
    @card_context = CardContext.new(@project, api_request? ? {} : session["project-#{@project.id}"])
  end

  def last_tab
    card_context.last_tab
  end

  def display_tabs
    DisplayTabs.new(@project, self)
  end

  def admin_action_name
    {:controller => controller_name, :action => action_name}
  end

  def always_show_sidebar?
    always_show_sidebar_actions_list.include?(action_name)
  end

  def always_show_sidebar_actions_list
    ['']
  end

  def default_url_options(options = {})
    super.dup.tap do |options|
      options[:project_id] = @project.identifier if !options.key?(:project_id) && @project && !@project.identifier.blank?
    end
  end

  protected
  def default_back_url
    if come_from_card_and_wiki_page?
      flash[:redirect_from] = request.request_uri # For bug 4651
      flash[:error] = "Read only team member (or Anonymous user) does not have the required permission to perform that action."
      request.env["HTTP_REFERER"]
    else
      accessing_project_has_membership? ? project_show_url : projects_url
    end
  end

  alias :authorize_user_access_for_project :authorize_user_access

  private
  def clear_active_project!
    Project.clear_active_project!
  end

  def add_to_page_view_history(page_identifier)
    view_history = PageViewHistory.new(session[SESSION_RECENTLY_ACCESSED_PAGES] || {})
    view_history.add(@project.id, page_identifier)
    session[SESSION_RECENTLY_ACCESSED_PAGES] = view_history.to_hash
  end

  def clear_card_context
    card_context.clear_current_list_navigation_card_numbers if @project
  end

  def load_project
    if params[:project_id].respond_to?(:to_str)
      @project = ProjectCacheFacade.instance.load_project(params[:project_id], project_cache_request_info)
    end
    if @project && !api_request?
      session["project-#{@project.id}"] ||= {}
      cookies['last-visited-project'] = { :value => @project.identifier, :expires => Time.now.next_year }
    end
  end

  def update_project_cache
    return unless params[:project_id].respond_to?(:to_str)
    if ProjectCacheFacade.instance.use_cache?(project_cache_request_info)
      ProjectCacheFacade.instance.cache_project(@project) if @project
    else
      ProjectCacheFacade.instance.clear_cache(params[:project_id])
    end
  end

  def project_cache_request_info
    {:get_request => request.get?, :controller_class_name => self.class.name, :action_name => self.action_name}
  end

  def accessing_anonymous_project?
    @project && @project.anonymous_accessible? && CurrentLicense.status.valid? && CurrentLicense.status.allow_anonymous?
  end

  def accessing_project_has_membership?
    @project && @project.member?(User.current)
  end

  def ensure_project
    raise InvalidResourceError, FORBIDDEN_MESSAGE unless @project
  end

  #todo:  we need to merge this behavior into ensure_project filter,
  # but we cannot do that until we sort out atom feed security issues
  def require_project_membership_or_admin
    return true if User.current.api_user? ||
      User.current.admin? ||
      accessing_anonymous_project? ||
      accessing_project_has_membership?

    raise_user_access_error
  end

  def come_from_card_and_wiki_page?
    request.env["HTTP_REFERER"] && !flash[:redirect_from] && ['/cards/', '/wiki/'].any?{|c| request.env["HTTP_REFERER"].include?(c) }
  end

end

class ProjectAdminController < ProjectApplicationController
  def current_tab
    DisplayTabs::NullTab.new
  end
end
