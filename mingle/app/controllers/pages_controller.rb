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

class PagesController < ProjectAdminController

  skip_project_cache_clearing_on :preview

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [:index, :list, :all_pages, :show, :new, :edit, :editable_content, :attachments, :get_attachment, :chart, :chart_data, :async_macro_data, :chart_as_text, :history],
        :put_access_for => [:update],
        :delete_access_for => [:remove_attachment],
        :redirect_to => { :action => :list }

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["create", "edit", "update", "preview", "update_tags", "update_favorite_and_tab_status", "new", "remove_attachment"],
             UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["destroy"]

  def current_tab
    return super if @action_name == 'list'

    page = page_from_params
    overview_tab = DisplayTabs::OverviewTab.new(@project)
    return overview_tab unless page
    found_favorite = @project.tabs.of_pages.find_by_favorited_id(page.id)
    found_favorite ? {:name => page.name, :type => Page.name} : overview_tab
  end

  def index
    list
    render :action => 'list'
  end

  def list
    @pages = @project.pages.find(:all, :select => 'name').sort_by{|page| page.name.downcase}
  end

  def all_pages
    @pages = @project.pages.find(:all).sort_by{|page| page.name.downcase}
    respond_to do |format|
      format.xml { render_model_xml @pages, :root => 'pages' }
    end
  end

  def update_favorite_and_tab_status
    @page = page_from_params
    if @page
      page_favorite = Favorite.find_or_construct_page_favorite(@project, @page)
      favorite_and_tab_settings = params[:status] || { 'favorite' => nil, 'tab' => nil }
      page_favorite.adjust({:favorite => favorite_and_tab_settings['favorite'], :tab => favorite_and_tab_settings['tab']})
      @project.reload.card_list_views.reload

      render :update do |page|
        page['hd-nav'].replace :partial => 'layouts/tabs', :locals => {:include_sidebar_control => true}
        page.replace 'favorites-container', :partial => 'shared/favorites', :locals => {:allow_view_creation => false}
      end
    else
      render :nothing => true
    end
  end

  def show
    @page = page_from_params
    return page_does_not_exist unless @page

    if (@page.overview_page? && !params[:version] && params[:format] != 'xml')
      flash.keep && redirect_to(project_overview_url(:project_id => @project.identifier, :version => params[:version]))
      return
    else
      add_to_page_view_history(@page.identifier)
    end
    @page_version = if params[:version]
      @page.find_version(params[:version].to_i)
    else
      @page.versions.last
    end

    @title = "#{@page.project.name} #{@page.name}" if @page
    card_context.store_tab_params(params, 'page', CardContext::NO_TREE)

    respond_to do |format|
      format.html { render :template => 'pages/show' }
      format.xml { render_model_xml(params[:version] ? @page_version : @page) }
    end
  end

  def new
    @page = @project.pages.build
    @page.identifier = identifier_from_params
    params[:pagename] = nil
    params[:page_identifier] = @page.identifier
  end

  def create
    clear_readonly_page_param

    @page = @project.pages.build(params[:page].merge(:identifier => identifier_from_params))

    if params[:page] && params[:page][:content]
      @page.content = process_content_from_ui(@page.content)
      @page.editor_content_processing = !api_request?
    end

    @page.tag_with(params[:tags].values) if params[:tags]
    @page.ensure_attachings(*params[:pending_attachments]) if params[:pending_attachments]

    if @page.errors.empty? && @page.save
      respond_to do |format|
        format.html do
          flash[:notice] = 'Page was successfully created.'
          redirect_to :action => 'show', :pagename => @page.identifier
        end
        format.xml do
          head :created, :location => rest_page_show_url(:page_identifier => @page.identifier, :format => 'xml')
        end
      end
    else
      render_on_error(@page.errors.full_messages, 'new')
    end
  end

  def edit
    if @page = page_from_params
      show_latest_version_notice_message_if_needed params[:coming_from_version]
      @page.convert_redcloth_to_html! if @page.redcloth?

    else
      page_does_not_exist
    end
  end

  def editable_content
    @page = page_from_params
    return page_does_not_exist unless @page

    @page_version = if params[:version]
      @page.find_version(params[:version].to_i)
    else
      @page.versions.last
    end

    content = render_to_string(:inline => "<%= @page_version.formatted_content_editor(self) %>")
    render :text => content, :layout => false
  end

  def update
    if request.method == :get
      redirect_to :action => 'list'
      return
    end
    clear_readonly_page_param

    @page = params.key?(:taggable_id) ? @project.pages.find(params[:taggable_id]) : page_from_params
    return page_does_not_exist unless @page

    if params[:page] && params[:page][:content]
      params[:page][:content] = process_content_from_ui(params[:page][:content])
      @page.editor_content_processing = !api_request?
    end

    @page.tag_with(params[:tags].values) if params[:tags]
    @page.content = (params[:page][:content] || '').rstrip
    if params[:deleted_attachments]
      params[:deleted_attachments].keys.each do |file_name|
        @page.remove_attachment(file_name) if params[:deleted_attachments][file_name] == 'true'
      end
    end
    params.merge! :page_identifier => @page.identifier
    if @page.errors.empty? && @page.save
      respond_to do |format|
        format.html do
          flash[:notice] = "Page was successfully updated."
          redirect_to :action => 'show', :pagename => @page.identifier
        end
        format.xml do
          render_model_xml @page
        end
      end

    else
      set_rollback_only
      @page_version = @page.find_version(@page.version)
      @history = History.for_versioned(@project, @page)
      flash.now[:error] = @page.errors.full_messages
      render :action => 'edit'
    end
  end

  def attachments
    @page = page_from_params
    respond_to  do |format|
      format.xml do
        if @page
          render :xml => @page.attachments.to_xml(:root => "attachments")
        else
          render :nothing => true, :status => :not_found
        end
      end
    end
  end

  def get_attachment
    @page = page_from_params
    attachment = @page.attachments.detect { |a| a.file_name == params[:file_name] }
    respond_to  do |format|
      format.xml do
        if attachment
          send_file attachment.file, :disposition => 'inline'
        else
          render :xml => 'Attachment file not exist', :status => 404
        end
      end
    end
  end

  def remove_attachment
    @page = params[:id] ? @project.pages.find(params[:id]) : page_from_params
    file_name = params[:file_name]
    if @page.remove_attachment(file_name) && @page.save
      respond_to do |format|
        format.json { render :json => {:file => params[:file_name]}.to_json }
        format.xml { render :nothing => true, :status => :accepted }
      end
    else
      set_rollback_only
      respond_to do |format|
        format.json { render :json => {:error => "not found", :file => params[:file_name]}.to_json, :status => :not_found }
        format.xml do
          render :nothing => true, :status => :not_found
        end
      end
    end
  end

  def update_tags
    @page = @project.pages.find(params[:taggable_id])
    @page.tag_with(params[:tag_list]) if params[:tag_list]
    if @page.errors.empty? && @page.save
      render(:update) do |page|
        page['version-info'].replace_html :partial => 'shared/version_info', :locals => { :versionable => @page, :show_latest_url => page_show_url(:pagename => Page.name2identifier(@page.name)) }
        %w{top bottom}.each { |location| page["page-edit-link-#{location}"].replace :partial => 'shared/page_edit_link', :locals => { :page => @page, :location => location } }
        page.call 'eval', 'historyLoader.reload();'
      end
    else
      set_rollback_only
      render(:update) do |page|
        flash.now[:error] = @page.errors.full_messages
        page['flash'].replace :partial => 'layouts/flash'
      end
    end
  end

  def destroy
    if page =  page_from_params
      page.destroy
    else
      flash[:error] = "The page you attempted to delete no longer exists."
    end
    redirect_to project_show_url(:project_id => @project.identifier)
  end

  def preview
    @page = if params[:page][:id]
      @project.pages.find(params[:page][:id])
    else
      @project.pages.build(params[:page].merge(:identifier => identifier_from_params))
    end
    @page.content = params[:page][:content]
    # also store it in the session so that charts can fetch content from the session
    session[:renderable_preview_content] = @page.content
    Tag.parse(params[:tags].values).each{|tag| @page.add_tag(tag)} if params[:tags]
    render :partial => 'preview'
  end

  def chart
    @page = page_from_params
    content = params[:preview] ? session[:renderable_preview_content] : @page.content
    generated_chart = Chart.extract_and_generate(content, params[:type], params[:position].to_i, :host_project => @project, :content_provider => @page, :dont_use_cache => params[:preview])
    send_data(generated_chart, :type => "image/png",:disposition => "inline")
  end

  def chart_data
    @page = page_from_params
    @page = @page.find_version(params[:version].to_i) if params[:version]
    content = params[:preview] ? session[:renderable_preview_content] : @page.content
    generated_chart = Chart.extract_and_generate(content, params[:type], params[:position].to_i, :host_project => @project, :content_provider => @page, :dont_use_cache => params[:preview], :preview => params[:preview])
    render :json => generated_chart
  end

  def async_macro_data
    @page = page_from_params
    @page = @page.find_version(params[:version].to_i) if params[:version]
    content = params[:preview] ? session[:renderable_preview_content] : @page.content
    generated_chart = Macro.get(params[:type]).extract_and_generate(content, params[:type], params[:position].to_i, :content_provider => @page, :dont_use_cache => params[:preview], :preview => params[:preview], :view_helper => default_view_helper)
    render :text => generated_chart, :status => 200
  end


  def chart_as_text
    @page = page_from_params
    content = params[:preview] ? session[:renderable_preview_content] : @page.content

    chart = Chart.extract(content, params[:type], params[:position].to_i, :host_project => @project, :content_provider => @page, :dont_use_cache => params[:preview], :preview => params[:preview])
    text_chart = chart.generate_as_text
    render :update do |page|
      page.replace_html 'chart-data', text_chart
    end
  end

  def history
    @page = page_from_params
    raise ActiveRecord::RecordNotFound unless @page
    @history = History.for_versioned(@project, @page)
    render :partial => 'history_container'
  end

  def always_show_sidebar_actions_list
    ['list']
  end

  def add_attachment
    respond_to do |format|
      format.xml do
        @page = page_from_params
        attachments = @page.attach_files(params[:file])
        if @page.save && @page.errors.empty?
          file_name = FileColumn::sanitize_filename(attachments.first.original_filename.downcase)
          head :created, :location => @page.attachments.detect{|at| at.file_name.downcase == file_name}.url
        end
      end
    end
  end

  def hide_too_many_macros_warning
    session[:too_many_macros_warning_visible] ||= []
    session[:too_many_macros_warning_visible] << CGI.unescape(params['page'])
    render :nothing => true
  end

  private

  def show_latest_version_notice_message_if_needed(coming_from_version)
    go_back_link = "<a href='#{page_show_url(:pagename => @page.identifier, :version => coming_from_version)}'>go back</a>"
    latest_version_link = "<a href='#{page_show_url(:pagename => @page.identifier)}'>latest version</a>"
    message = "This page has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, #{go_back_link} to the previous page or view the #{latest_version_link}."
    html_flash.now[:info] = message if coming_from_version && coming_from_version.to_i < @page.version
  end

  def page_does_not_exist
    respond_to do |format|
      format.html do
        unless authorized?(:controller => 'pages', :action => 'new')
          if @project.member?(User.current)
            flash[:error] = "#{@project.role_for(User.current).name}s do not have access rights to create pages."
          else
            flash[:error] = "Anonymous users do not have access rights to create pages."
          end
          redirect_to request.env["HTTP_REFERER"] ? :back : project_show_url
        else
          new
          render :action => 'new'
        end
      end
      format.xml do
        render :nothing => true, :status => :not_found
      end
    end
  end

  def render_on_error(error_message, error_action)
    set_rollback_only
    respond_to do |format|
      format.html do
        flash.now[:error] = error_message
        render :action => error_action
      end
      format.xml do
        render :xml => @page.errors.to_xml, :status => 422
      end
    end
  end

  def identifier_from_params
    params[:page_identifier] || Page.name2identifier(page_name_from_params)
  end

  def page_name_from_params
    params[:pagename] ? params[:pagename] : (params[:page][:name] if params[:page])
  end

  def page_from_params
    @project.pages.find_by_identifier(identifier_from_params)
  end

  def clear_readonly_page_param
    if params[:page]
      params[:page].delete('version')
      params[:page].delete('has_macros')
      params[:page].delete('project_id')
      params[:page].delete('updated_at')
      params[:page].delete('modified_by_user_id')
      params[:page].delete('created_at')
      params[:page].delete('created_by_user_id')
    end
  end

  def default_view_helper
    view = ActionView::Base.new(File.join(Rails.root, "/app/views"), {:cards => @cards, :project => @project}, self)
    view.extend(ApplicationHelper)
    view.extend(CardsHelper)
    view
  end
end
