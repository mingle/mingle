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

class ProjectsController < ProjectApplicationController
  skip_before_filter :ensure_project, :except => ['show', 'overview', 'lightweight_model', 'show_info', 'edit', 'update', 'export', 'confirm_delete', 'delete', 'execute_mql']
  skip_before_filter :require_project_membership_or_admin, :only => ['index', 'list', 'unsupported_api_call', 'request_membership', 'admins']

  # ensure test_keywords_for_revisions is a post so that when project.revisions is called, it doesn't stay cached (note: this is a bad reason to do a post -- we can get around the caching issue in a better way later)
  # verify :method => :post, :only => [:test_keywords_for_revisions, :invalidate_content_cache, :recache_revisions, :regenerate_secret_key, :regenerate_changes, :recompute_aggregates, :rebuild_card_murmur_linking], :redirect_to => { :action => :index }
  allow :get_access_for => [:index, :list, :show, :overview, :advanced, :show_info, :new, :edit, :delete, :keywords, :show_page_name_error, :export, :fetch_page_feeds, :lightweight_model, :request_membership, :health_check, :chart_data, :admins],
        :delete_access_for => [:remove_attachment],
        :redirect_to => { :action => :index }

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => %w(new create delete confirm_delete import create_with_spec),
             UserAccess::PrivilegeLevel::PROJECT_ADMIN => %w(update edit regenerate_changes recache_revisions regenerate_secret_key invalidate_content_cache advanced update_keywords recompute_aggregates rebuild_card_murmur_linking),
             UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => %w(remove_attachment update_tags),
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => %w(export chart_data),
             UserAccess::PrivilegeLevel::REGISTERED_USER => %w(request_membership show_info admins)

  BLANK = '-blank'
  INCLUDE = "include"
  EXCLUDE = "exclude"

  def protect?(action_name)
    return false if ['list', 'index'].include?(action_name) && allow_anonymous_accessing?
    super(action_name)
  end

  def current_tab
    @mappings ||= Hash.new(DisplayTabs::OverviewTab.new(@project)).tap do |hash|
      %w{edit update keywords advanced}.each do |action|
        hash[action] = DisplayTabs::NullTab.new
      end
    end
    @mappings[@action_name]
  end

  def overview
    @overview_page = @project.overview_page
    card_context.store_tab_params(params, 'page', CardContext::NO_TREE)
    @title = "#{@project.name} Overview"

    if @overview_page
      add_to_page_view_history(@overview_page.identifier)
      @overview_page_version = if params[:version]
        @overview_page.find_version(params[:version])
      else
        @overview_page #can be changed to @overview_page.versions.last once all pages have atleast one version
      end
    end
  end

  def index
    unless params[:project_id].blank?
      flash.keep
      redirect_to :action => :index, :project_id => nil
      return
    end
    @title = "Projects"
    @heading = "Current Projects"
    @projects = params[:exclude_requestable] == 'true' ? Project.accessible_projects_without_templates_for(User.current) : Project.accessible_or_requestables_for(User.current)
    respond_to do |format|
      format.html { render :action => 'list' }
      format.json do
        render :json => name_and_identifiers(@projects)
      end
      format.xml do
        to_be_rendered = @projects + User.current.accessible_templates
        if params.has_key?(:name_and_id_only)
          to_be_rendered = name_and_identifiers(to_be_rendered)
        end
        render_model_xml(to_be_rendered, :root => 'projects')
      end
    end
  end


  def show
    flash.keep
    add_monitoring_event('open_project', {'project_name' => @project.name})
    tab = display_tabs.first
    redirect_to params.merge(tab.params)
  end

  def show_info
    return display_404_error(nil) if @project.hidden?

    respond_to do |format|
      format.xml { render_model_xml @project }
    end
  end

  def new
    @project = Project.new
  end

  def create
    return head(:unprocessable_entity) if params[:project].blank?
    ensure_identifier(params[:project])

    @project = Project.create(params[:project].merge(:hidden => true))

    add_monitoring_event('create_project', {'project_name' => @project.name, 'template_name' => params['template_name']})

    if @project.valid? && use_template?(params['template_name'])
      options={}
      options[:include_cards] = false if params['include_or_exclude_cards'] == EXCLUDE
      options[:include_pages] = false if params['include_or_exclude_pages'] == EXCLUDE
      merge_project_with_template(@project, params['template_name'], options)
    end

    if @project.valid? && params['as_member'] == 'true'
      @project.add_member(User.current)
    end

    if @project.valid?
      flash[:notice] = "Project #{@project.name.bold} successfully created. "
      @project.update_attribute(:hidden, false)
      respond_to do |format|
        format.html do
          redirect_to(project_show_url(@project.identifier))
        end
        format.xml { head :created, :location => rest_project_show_url(:project_id => @project.identifier, :format => 'xml'), :identifier => @project.identifier }
      end
    else
      set_rollback_only
      add_helpful_name_and_identifier_error_messages_to @project
      flash.now[:error] = @project.errors.full_messages.sort.join(', ')
      respond_to do |format|
        format.html do
          render :action => 'new'
        end
        format.xml { render :xml => @project.errors.to_xml, :status => 422 }
      end
    end
  end

  def add_helpful_name_and_identifier_error_messages_to(project)
    add_helpful_uniqueness_violation_message(:attribute => :identifier, :project => project)
    add_helpful_uniqueness_violation_message(:attribute => :name, :project => project)
  rescue => e
    Rails.logger.error("Error adding nice message for project validation #{e}")
  end

  def add_helpful_uniqueness_violation_message(options)
    attribute = options.delete(:attribute)
    project = options.delete(:project)
    if project.send("#{attribute}_changed?".to_sym)
      dupe = Project.send("find_by_#{attribute}".to_sym, project.send(attribute))
      return unless dupe
      project_type = if dupe.template?
               'template'
             elsif dupe.hidden?
               'hidden_project'
             else
               'project'
             end
      error_message = render_to_string :partial => "projects/duplicate_#{project_type}_error", :locals => { :project => dupe }
      project.errors.add(attribute, error_message)
    end


  end

  def edit
  end

  def admins
    if MingleConfiguration.show_all_project_admins?
    project = Project.find_by_identifier(params[:project_id])
      @admins = project.admins.sort_by {|user| user[:name].downcase}
      render_in_lightbox 'project_admins_list'
    end
  end

  def create_with_spec
    spec = JSON.parse params[:spec]
    spec['project'] ||= params[:project]
    ensure_identifier(spec['project'])
    respond_to do |format|
      format.xml do
        begin
          @project = ProjectCreator.new.create(spec)
          if @project.valid? && params['as_member'] == 'true'
            @project.add_member(User.current)
          end

          head :created, :location => rest_project_show_url(:project_id => @project.identifier, :format => 'xml'), :identifier => @project.identifier
        rescue ActiveRecord::RecordInvalid => e
          render :xml => {:error => e.message }, :status => 422
        end
      end
    end
  end

  def update
    @project.attributes = params[:project]
    if @project.name_changed?
      add_monitoring_event('rename_project', 'old_name' => @project.name_was, 'new_name' => @project.name)
    end

    if @project.save
      flash[:notice] = 'Project was successfully updated.'
      redirect_to :action => 'show', :project_id => @project.identifier
    else
      set_rollback_only
      add_helpful_name_and_identifier_error_messages_to(@project)
      flash.now[:error] = @project.errors.full_messages.join(', ')
      @project.reload
      render :action => 'edit'
    end
  end

  def delete #ugh
    @project_to_delete = @project
    @project = nil
  end

  def confirm_delete
    program_projects = ProgramProject.find_all_by_project_id(@project.id, :include => [:program])
    if program_projects.blank?
      @project.destroy
      flash[:notice] = "#{@project.name.bold} was successfully deleted."
      @project = nil
    else
      referenced_by_plans = program_projects.collect(&:program).collect(&:name)
      flash[:error] = "Project #{@project.name.bold} is referenced by #{pluralize(referenced_by_plans.size, 'plan')}: #{referenced_by_plans.join(', ')}"
    end
    redirect_to :controller => 'projects', :action => 'index', :project_id => nil
  end

  def update_tags
    overview_page = @project.pages.find(params[:taggable_id])
    @project = overview_page.project
    overview_page.tag_with(params[:tag_list]) if params[:tag_list]
    if overview_page.errors.empty? and overview_page.save
      render(:update) do |page|
        %w{top bottom}.each { |location| page["page-edit-link-#{location}"].replace :partial => 'shared/page_edit_link', :locals => { :page => overview_page, :location => location } }
        page.call 'eval', 'historyLoader.reload();'
      end
    else
      set_rollback_only
      render(:update) do |page|
        flash.now[:error] = overview_page.errors.full_messages
        page['flash'].replace :partial => 'layouts/flash'
      end
    end
  end

  def keywords
  end

  def update_keywords
    @project.card_keywords = params[:project][:card_keywords]
    if @project.save
      flash[:notice] = 'Project was successfully updated.'
      redirect_to :action => 'show', :project_id => @project.identifier
    else
      set_rollback_only
      flash.now[:error] = @project.errors.full_messages.join(', ')
      render :action => :keywords
    end
  end

  def test_keywords_for_revisions
    @project.card_keywords = params[:project][:card_keywords]
    @card_number = params[:card_number]

    unless @project.card_keywords.valid?
      set_rollback_only
      @error_msg = @project.card_keywords.invalid_message
      render(:update) do |page|
        page['matched-revisions'].replace_html :partial => 'matched_revisions_error'
      end
      return
    end

    @revisions = @project.revisions_for_card_number(@card_number)[0..9] #todo passing limit into, so that can use sql to collect
    render(:update) do |page|
      page['matched-revisions'].replace_html :partial => 'matched_revisions'
    end
  end

  def show_page_name_error
    set_rollback_only
    flash[:error] = CGI::unescape(params[:error_msg])
    redirect_to params[:page_url]
  end

  def export
    publisher = ProjectExportPublisher.new(@project, User.current, params[:export_as_template] ? true : false)
    publisher.publish_message
    @asynch_request = publisher.progress
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg
    render_in_lightbox 'asynch_requests/progress', :locals => {:deliverable => @project}
  end

  def export_download
    @asynch_request = ProjectExportAsynchRequest.find(params[:id])

    if !@asynch_request.completed?
      redirect_to :controller => 'asynch_requests', :action => 'progress', :id => @asynch_request.id
      return
    end

    if @asynch_request.failed?
      flash.now[:error] = "Project export failed: #{@asynch_request.error_detail}"
    else
      send_file  @asynch_request.filename, :filename => @asynch_request.exported_file_name, :type => 'application/octet-stream'
    end
  end

  def request_membership
    raise_user_access_error unless @project.requestable_for?(User.current)

    if @project.admins.all? { |admin| admin.email.blank? }
      return redirect_index_with_error('This project does not have any project administrators or none of the project administrators has an email address. Please contact your Mingle Administrator for further assistance.')
    end

    unless smtp.configured?
      return redirect_index_with_error('This feature is not configured. Contact your Mingle administrator for details.')
    end

    begin
      MembershipRequestMailer.deliver_request(User.current, @project)
    rescue Exception => e
      return redirect_index_with_error('This feature is not configured. Contact your Mingle administrator for details.')
    end

    flash[:notice] = "Your request for membership to project #{@project.name.bold} has been successful."
    redirect_to :action => 'index', :project_id => nil
  end

  def invalidate_content_cache
    administer('invalidate the content cache'){@project.invalidate_renderable_content_cache('advanced project admin')}
  end

  def recache_revisions
    administer("rebuild the #{@project.repository_vocabulary['revision']} cache"){@project.re_initialize_revisions_cache}
  end

  def regenerate_secret_key
    administer("regenerate the project's secret key"){@project.generate_secret_key!}
  end

  # admin jobs need to monitor progress status
  def regenerate_changes
    administer('rebuild the history index', true){ @project.generate_changes_as_admin }
  end

  def recompute_aggregates
    administer("recalculate the project's aggregate properties", true) { @project.recompute_aggregates_as_admin }
  end

  def rebuild_card_murmur_linking
    administer("rebuild the Murmurs card links", true) { @project.rebuild_card_murmur_links_as_admin }
  end

  def remove_attachment
    @page = @project.overview_page
    file_name =  params[:file_name]

    if @page.remove_attachment(file_name) && @page.save
      respond_to do |format|
        format.json { render :json => {:file => params[:file_name]}.to_json }
      end
    else
      set_rollback_only
      respond_to do |format|
        format.json { render :json => {:error => "not found", :file => params[:file_name]}.to_json, :status => :not_found }
      end
    end
  end

  def fetch_page_feeds
    render(:update) do |page|
      feed_query = history_filter_query_string(:page_identifier => params[:page_identifier])
      page['feed'].replace_html :partial => 'history/feed', :locals => {:request_params => feed_query, :email_link => 'Watch this page'}
    end
  end

  def health_check
    @project.corruption_check
    unless (@project.corrupt? || params[:no_message_if_ok])
      flash[:notice] = 'We have not identified any issues with your project data or structure. Please continue to work as normal.'
    end

    ProjectCacheFacade.instance.clear_cache(@project.identifier)

    flash.keep
    redirect_to params[:forward_url] || :back
  end

  def lightweight_model
    respond_to do |format|
      format.xml { render :xml => @project.as_lightweight_model }
    end
  rescue => err
    logger.error err.message
    respond_to do |format|
      format.xml { render :xml => {:message => err.message}.to_xml, :status => 500  }
    end
  end

  def always_show_sidebar_actions_list
    ['edit', 'advanced', 'keywords']
  end

  def chart_data
    respond_to do |format|
      format.json { render layout: false}
    end
  end

  protected

  def load_project
    super
    unless @project
      @project = Project.find_by_identifier(params[:project_identifier]) if params[:project_identifier]
      session["project-#{@project.id}"] ||= {} if @project
    end
  end

  def handle_error(error_msg)
    @error_msg = error_msg
    render :partial => 'matched_revisions_error'
  end

  private
  def anonymous_accessible?(project)
    User.current.anonymous? && project.anonymous_accessible?
  end

  def use_template?(template_name)
    !template_name.blank? && template_name != BLANK
  end

  def merge_project_with_template(project, template_name, options)
    strategy = if template_name =~ /^custom_(\w+)/
      DBTemplate.new($1)
    elsif template_name =~ /^yml_(\w+)/
      ConfigurableTemplate.new($1)
    elsif template_name =~ /^in_progress_(\w+)/
      ConfigurableTemplate.in_progress_template($1)
    end
    strategy && strategy.qualified? && strategy.copy_into(project, options)
  end

  def redirect_index_with_error(message)
    flash[:error] = message
    redirect_to :action => 'index', :project_id => nil
  end

  def smtp
    SmtpConfiguration
  end

  def administer(action, blocked=false)
    yield
    important_text = blocked ? "The results of this action will not be apparent immediately. You will be unable to request this action again until this request has been completed." : "The results of this action will not be apparent immediately, and multiple requests to #{action} will not make this action any quicker."
    flash[:notice] = "Your request to #{action} has been accepted and will complete in the background. #{important_text.bold} Please continue to work as normal."
  rescue => e
    set_rollback_only
    logger.error("Error requesting admin function #{action}. #{e}:\n#{e.backtrace.join("\n")}")
    flash[:notice] = nil
    flash[:error] = "You request to #{action} failed. Please contact your Mingle administrator."
  ensure
    redirect_to :action => 'advanced'
  end

  def name_and_identifiers(projects)
    projects.map do |project|
      icon_path = project.icon && '/' + project.icon_relative_path
      {:name => project.name, :identifier => project.identifier, :icon => icon_path }
    end
  end

  def ensure_identifier(project)
    if project['identifier'].blank? && project['name'].to_s.length > 0
      project['identifier'] = Project.unique(:identifier, project['name'].to_s.downcase.gsub(/[^a-z\d]/, ''))
    end
  end
end
