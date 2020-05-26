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

class CardsController < ProjectApplicationController
  CYCLE_TIME_THRESHOLD = 2

  include CardSupport
  include CardListSupport
  include CardListViewState

  helper :trees, :murmurs, :lanes, :card_list_view_tab_name
  before_filter :detect_api_version

  skip_before_filter :clear_card_context
  skip_project_cache_clearing_on :expand_hierarchy_node, :collapse_hierarchy_node, :expand_tree_node, :collapse_tree_node, :save_context_and_redirect, :preview, :confirm_delete

  allow :get_access_for => [:attachments, :bulk_tagging_panel, :can_be_cached,
                            :card_name, :card_summary, :chart, :chart_data, :chart_as_text, :async_macro_data,
                            :daily_history_chart, :comments, :confirm_copy, :copy_to_project_selection,
                            :execute_mql, :format_number_to_project_precision, :format_string_to_date_format,
                            :get_attachment, :index, :murmurs, :refresh_comments, :refresh_comments_partial,
                            :require_comment_for_bulk_transition, :require_popup_for_transition, :popup_show,
                            :require_popup_for_transition_in_popup, :show, :transitions, :list, :new,
                            :edit, :history, :popup_history, :select_tree, :bulk_set_properties_panel, :show_tree_cards_quick_add,
                            :show_properties_container,
                            :show_tree_cards_quick_add_on_card_show_page, :show_tree_cards_quick_add_to_root,
                            :card_transitions, :render_macro, :rendered_description, :in_progress, :confirm_delete,
                            :dependencies_statuses],
        :put_access_for => [:update_restfully],
        :delete_access_for => [:remove_attachment],
        :redirect_to => {:action => :list}

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["update_property_color", "destroy", "bulk_destroy", "confirm_delete", "confirm_bulk_delete", "reorder_lanes"],
             UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["new", "create", "edit", "update", "preview", "update_property", "update_property_on_lightbox", "bulk_set_properties_panel", "bulk_set_properties", "bulk_tagging_panel", "remove_card_from_tree", "remove_card_from_tree_on_card_view",  "create_view", "create_view_async", "bulk_transition", "transition", "bulk_transition", "transition_in_popup", "transition_in_old_popup", "require_popup_for_transition", "require_popup_for_transition_in_popup", "require_comment_for_bulk_transition", "remove_attachment", "set_value_for", "tree_cards_quick_add", "tree_cards_quick_add_to_root", "add_children", "bulk_add_tags", "bulk_remove_tag", "update_tags", "add_comment", "show_tree_cards_quick_add", "show_tree_cards_quick_add_to_root", "show_tree_cards_quick_add_on_card_show_page", "update_restfully", "add_comment_restfully", "dependencies_statuses", "reorder_tags"],
             UserAccess::PrivilegeLevel::READONLY_TEAM_MEMBER => ['copy', 'confirm_copy', 'copy_to_project_selection', 'render_macro'],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => ['csv_export']

  attr_reader :card

  def index
    flash.keep
    respond_to do |format|
      format.html do
        view = CardListView.find_or_construct(@project, params)
        if view.nil?
          report_view_missing_and_redirect_to_last_card_view(params[:view])
        elsif view.new_record?
          redirect_to view.to_params
        else # this is for keeping the url clean
          forward_to_list
        end
      end
      format.xml do
        # ActiveResource uses 'index' for Card.find(:all), so don't redirect
        forward_to_list
      end
    end
  end

  def list
    cards_result_setup
    return if @view.nil?
    return unless display_tree_setup
     respond_to do |format|
      format.html do
        render :action => 'list'
      end
      format.xml do
        render :layout => false
      end
      format.js do
        excluded = [:tabs] if @view.maximized
        refresh_list_page(:except => excluded)
      end
    end
  end

  def dependencies_statuses
    # protect against abuse, should only have as many cards as grid view allows (except edge case where live wall adds a card beyond this limit)
    numbers = params[:cards].slice(0, CardViewLimits::MAX_GRID_VIEW_SIZE).compact.map(&:to_i).uniq || []

    result = {}

    if (numbers.size)
      Card.find_each(:conditions => "#{Card.connection.quote_column_name("number")} in (#{numbers.join(",")})") do |card|
        result[card.number] = {:raised => card.raised_dependencies_status, :resolving => card.dependencies_resolving_status}
      end
    end

    render :json => result.to_json
  end

  def expand_hierarchy_node
    subtree = toggle_node_setup
    return unless subtree

    respond_to do |format|
      format.js do
        refresh_list_page(:except => [:flash, :results]) do |page|
          page.insert_html :after, subtree.root.html_id, :partial => 'hierarchy_nodes', :locals => {:parent_node => subtree.root}
          page.hierarchy_view.replaceSubtree(subtree.root)
          page.replace 'cards-header', :partial => 'cards_header_in_hierarchy'
          page.replace_html 'table-column-header', :partial => 'hierarchy_card_table_head'
        end
      end
    end
  end

  def collapse_hierarchy_node
    return unless toggle_node_setup
    respond_to do |format|
      format.js do
        refresh_list_page(:except => [:flash, :results]) do |page|
          page.replace 'cards-header', :partial => 'cards_header_in_hierarchy'
          page.replace_html 'table-column-header', :partial => 'hierarchy_card_table_head'
        end
      end
    end
  end

  def expand_tree_node
    subtree = toggle_node_setup
    return unless subtree
    respond_to do |format|
      format.js do
        refresh_list_page(:except => [:results]) do |page|
          page.replace "sub_tree_#{subtree.root.html_id}", :partial => 'sub_tree', :locals => {:node => subtree.root}
          page.tree_view.get_tree.replaceSubtree(subtree.root)
          page.replace 'tree-header', :partial => 'tree_header'
        end
      end
    end
  end

  def collapse_tree_node
    return unless toggle_node_setup
    respond_to do |format|
      format.js do
        refresh_list_page(:except => [:results]) do |page|
          page.replace 'tree-header', :partial => 'tree_header'
        end
      end
    end
  end

  def save_context_and_redirect
    card_context.current_list_navigation_card_numbers = params[:context_numbers].split(',').collect(&:to_i)
    redirect_to params[:redirect_url]
  end

  def show
    @card = @project.cards.find_by_number(params[:number].to_i)
    return card_does_not_exist("Card #{params[:number]} does not exist.") if @card.nil?

    @displaying_latest_version = params[:version].blank? || params[:version].to_i == @card.version || @card.find_version(params[:version].to_i).nil?
    setup_all_card_numbers

    unless api_request?
      params.delete(:tab)
      @tab_name = current_tab[:name]
      params.merge!(:tab => @tab_name)
      @title =  "##{@card.number} - #{@card.name} - #{@card.project.name}"
      @current_context_filter_description = card_context.last_tab_filter_description
    end

    target_template = if @displaying_latest_version && authorized?('cards:update')
      @transitions = @card.transitions
      if params[:version] && params[:version].to_i != @card.version
        flash[:notice] = "Version #{params[:version]} of this card doesn't exist. Display the current version instead."
      end
      'cards/show'
    else
      @card_version = @card.find_version(params[:version].to_i) || @card
      'cards/show_card_version'
    end

    card_context.clear_last_tab_params_on_context_lost(@card.number) unless api_request?

    respond_to do |format|
      format.html { render :template => target_template }
      format.xml {
        render_model_xml(@card_version || @card, card_xml_options(params))
      }
    end

    card_context.clear_last_tab_params_on_tab_change(current_tab[:name]) unless api_request?
  end

  def show_properties_container
    card = @project.cards.find_by_number(params[:number].to_i)
    return card_does_not_exist("Card #{params[:number]} does not exist.") if card.nil?

    render :update do |page|
      page.replace_html 'show-properties-container', :partial => "show_properties_container", :locals => {:card => card}
      page.replace_html 'toggle_hidden_properties_bar', :partial => 'toggle_hidden_properties_bar', :locals => { :card => card }
    end
  end

  def rendered_description
    @card = @project.cards.find_by_number!(params[:number].to_i)
    render :template => "cards/rendered_description", :layout => false
  end

  def transitions
    card = @project.cards.find_by_number(params[:number].to_i)
    return card_does_not_exist("Card #{params[:number]} does not exist.") if card.nil?
    @transitions = card.transitions
    respond_to do |format|
      format.xml { render_model_xml @transitions, :root => "transitions", :schema => 'card_transition' }
      format.json do
        render :json => (@transitions.map do |t|
          {:name => t.name,
            :id => t.id,
            :require_popup => t.accepts_user_input?,
            :card_id => card.id,
            :card_number => card.number,
            :project_id => @project.identifier }
        end)
      end
    end
  end

  def card_transitions
    result = {}
    cards = @project.cards.find(params[:card_ids])
    cards.each do |card|
      transitions = card.transitions.reject { |transition| transition.require_user_to_enter? || transition.has_optional_input? }
      result[card.id] = transitions.map { |transition| { :name => escape_and_format(transition.name), :html_id => transition.html_id, :id => transition.id, :require_comment => transition.require_comment? } }
    end

    respond_to do |format|
      format.js do
        render :update do |page|
          page << "BulkTransitions.instance.updateTransitions(#{result.to_json})"
        end
      end
    end
  end

  def in_progress
    q = []
    u = User.current.login

    @project.ownership_properties[0..9].each do |name|
      q << "#{name.inspect} = #{u.inspect}"
    end

    columns = %w(number name card_type_name).map {|c| Project.connection.quote_column_name(c)}.join(", ")
    result = q.empty? ? [] : @project.cards.find(:all, :mql => q.join(" or "), :limit => 10, :select => columns).map do |r|
      {
        :number => r["number"],
        :name => r["name"],
        :type => r["card_type_name"],
        :url => card_show_path(:project_id => @project.identifier, :number => r["number"])
      }
    end
    render :json => result
  end

  def attachments
    @card = @project.cards.find_by_number(params[:number].to_i)
    respond_to do |format|
      format.xml do
        if @card
          render :xml => @card.attachments.to_xml(:methods => [:url, :file_name], :only => [], :root => "attachments")
        else
          render :nothing => true, :status => :not_found
        end
      end
    end
  end

  def comments
    card =  @project.cards.find_by_number(params[:number].to_i)
    respond_to do |format|
      format.xml do
        if card
          render_model_xml card.comments, :root => "card_comments", :dasherize => false
        else
          render :nothing => true, :status => :not_found
        end
      end
    end
  end

  def murmurs
    @card =  @project.cards.find_by_number(params[:number].to_i)

    unless @card
      render :nothing => true, :status => :not_found
      return
    end

    respond_to do |format|

      format.json do
        json = Cache.get(Keys::Discussion.new.path_for(@card.discussion, "discussion_murmurs")) do
          @card.discussion.map do |m|
            render_to_string(:partial => 'murmurs/murmur_chat_compact', :locals => {:murmur => m})
          end
        end
        render :json => json, :status => :ok
      end

      format.html do
        render :partial => 'discussions', :locals => { :card => @card, :discussion => @card.discussion }
      end

      format.xml do
        render_model_xml(@card.discussion.murmurs, :root => 'murmurs', :truncate => true)
      end

    end
  end

  def add_comment_restfully
    card = @project.cards.find_by_number(params[:number].to_i)

    unless card
      render :nothing => true, :status => :not_found
      return
    end

    card.add_comment(params[:comment])

    respond_to do |format|

      format.json do
        head :created
      end

      format.xml do
        render_model_xml card.comments.first
      end

    end
  end

  def get_attachment
    @card = @project.cards.find_by_number(params[:number].to_i)
    attachment = @card.attachments.detect { |a| a.file_name == params[:file_name] }
    respond_to do |format|
      format.xml do
        if attachment
          send_file attachment.file
        else
          render :xml => 'Attachment file not exist', :status => 404
        end
      end
    end
  end

  def select_tree
    last_params = card_context.parameters_for(params['tab'], params['tree_name'] || CardContext::NO_TREE)
    redirect_params = params.merge(last_params).merge(:action => :list)

    if !params['tree_name'] && CardView::Style.require_tree?(redirect_params[:style])
      redirect_params.delete(:style)
    end

    redirect_to redirect_params
  end

  def render_macro
    @card = if params[:id].present?
      @project.cards.find(params[:id].to_i)
    else
      @project.cards.new
    end

    session[:renderable_preview_content] = params[:macro]
    rendered_content = (render_to_string :partial => 'cards/render_macro')[1..-1]
    render :text => rendered_content, :status => (@card.macro_execution_errors.any? ? 422 : 200)
  end

  def preview
    set_rollback_only

    @card = if params[:card_number]
      @project.cards.find_by_number(params[:card_number].to_i)
    else
      @project.cards.new
    end
    @card.attributes = params[:card]
    @card.update_properties(params[:properties])

    # also store it in the session so that charts can fetch content from the session
    session[:renderable_preview_content] = @card.description
    @card.project = @project

    @card.validate
    flash.now[:error] = @card.errors.full_messages if @card.errors.any?

    render :partial => 'preview'
  end

  def card_summary
    render_card_popup_json(@project.cards.find_by_numbers_with_eager_loading(params[:numbers].split(','), [:taggings]))
  end

  def popup_show
    card = @project.cards.find_by_number(params[:number])
    if card.blank?
      render :text => "Cannot find card #{params[:number]}", :status => 404
      return
    end
    displaying_latest_version = params[:version].blank? || params[:version].to_i == card.version || card.find_version(params[:version].to_i).nil?
    locals = { }
    card_lightbox_partial = 'cards/card_lightbox_show'
    singleton_id = "#{@project.identifier}/#{card.prefixed_number}"

    if !displaying_latest_version
      version = params[:version].to_i
      card = card.find_version(version)
      card_lightbox_partial = 'cards/card_lightbox_version_show'
      singleton_id += ":#{version}"
    else
      locals.merge!(:allowed_to_edit => authorized?(:action => 'update'), :render_transition_forms => render_transition_forms?)
      @view ||= CardListView.find_or_construct(@project, params) if render_transition_forms?
    end

    locals.merge!(:card => card)

    convert_content_to_html_if_necessary(card)
    render_in_lightbox(card_lightbox_partial, :locals => locals, :lightbox_opts => {
        :close_on_blur => true,
        :lightbox_css_class => 'view-mode',
        :after_update => 'MingleUI.lightbox.cards', :ensure_singleton_with_id => singleton_id
    })
  end

  def new
    # on a post this can potentially create tags in the database
    # the easiest way to avoid that is to just roll back that transaction
    set_rollback_only
    @view = CardListView.find_or_construct(@project, last_tab)
    tags = (params[:card] || {}).delete(:tagged_with)
    @card = @project.cards.build_with_defaults(params[:card], params[:properties])
    @card.tag_with(tags) if tags.present?
    @card.validate
    if @card.errors.any?
      flash.now[:warning] = @card.errors.full_messages.join(" ")   # we flash warning because showing an error on a page that the user hasn't submitted yet is weird
    end
  end

  def create
    @card = create_card_from_params
    if @card.errors.empty? && @card.save && update_associations(@card)
      add_monitoring_event('create_card', {'project_name' => @project.name})

      respond_to do |format|
        format.html do
          flash[:highlight] = @card.html_id
          if params[:add_another].to_s == 'true'
            html_flash[:notice] = card_success_message(@card, 'created')
            add_another_card({}, params[:properties])
          else
            view = CardListView.find_or_construct(@project, last_tab)
            html_flash[:notice] = card_successly_created_message_with_included_in_view_check(@card, view)
            redirect_to(last_tab)
          end
        end
        format.xml do
          head :created, :location => rest_card_show_url(:number => @card.number, :format => 'xml')
        end
      end
    else
      set_rollback_only
      respond_to do |format|
        format.html do
          @view = CardListView.find_or_construct(@project, params)
          render_on_error @card.errors.full_messages, 'new'
        end
        format.xml do
          render :xml => @card.errors.to_xml, :status => 422
        end
      end
    end
  end

  def edit
    set_rollback_only
    if @card = @project.cards.find_by_number(params[:number].to_i)
      show_latest_version_notice_message_if_needed params[:coming_from_version]
    else
      return card_does_not_exist("Card #{params[:number]} does not exist.")
    end
    convert_content_to_html_if_necessary(@card)

    update_card_from_params(@card)

    @history = History.for_versioned(@project, @card)
  end

  def update
    if request.method == :get
      redirect_to :action => 'list'
      return
    end
    return if params[:format] == 'xml'
    return card_does_not_exist("Card(id=#{params[:id]}) does not exist.") unless @card = find_and_update_card

    if @card.errors.empty? && @card.save && update_associations(@card)
      respond_to do |format|
        format.html do
          html_flash[:notice] = card_success_message(@card, 'updated')
          if params[:add_another].to_s == 'true'
            add_another_card({}, params[:properties])
          else
            redirect_to(:action => 'show', :number => @card.number)
          end
        end

        format.json do
          card_response = { :name => @card.name, :number => @card.number, :event => @project.last_event_id}
          (params[:properties] || {}).keys.each do |prop_def_name|
            card_response[:properties] ||= {}
            value = @card.property_value(prop_def_name)
            card_response[:properties][prop_def_name] = value.url_identifier
          end
          render :json => card_response.to_json, :status => :ok

        end
      end
    else
      set_rollback_only
      respond_to do |format|
        format.html do
          flash[:error] = @card.errors.full_messages
          uploaded_filenames = params[:attachments].values.collect { |val| FileColumn::sanitize_filename(val.original_filename) unless val.blank? }.compact if params[:attachments]
          flash[:info] = "You will need to reattach the #{'file'.plural(uploaded_filenames.size)} #{uploaded_filenames.bold.to_sentence}" unless uploaded_filenames.blank?
          @history = History.for_versioned(@project, @card)
          render_on_error @card.errors.full_messages, 'edit'
        end

        format.js do
          render :nothing => true, :status => 422
        end

        format.json do
          render :json => @card.errors.full_messages.to_json,  :status => 422
        end
      end
    end
  end

  def update_restfully
    return unless params[:format] == 'xml'
    return card_does_not_exist(nil) unless @card = @api_delegate.find_card
    update_card(@project.admin?(User.current))
    return should_not_update_old_card_version if update_old_version_in_rest

    @card.validate_not_applicable_properties = true
    if @card.errors.empty? && @card.save
      render_model_xml(@card, card_xml_options(params))
    else
      set_rollback_only
      render :xml => @card.errors.to_xml, :status => 422
    end
  end

  def confirm_delete
    @card = @project.cards.find_by_number(params[:number].to_i)
    return already_deleted unless @card
    card_selection = CardSelection.new(@project, [@card])
    @warnings = card_selection.warnings
    @destroy_params = { :controller => 'cards', :action => 'destroy', :number => @card.number }
    render_in_lightbox 'confirm_delete'
  end

  def destroy
    @card = @project.cards.find_by_number(params[:number].to_i)
    return already_deleted unless @card
    setup_all_card_numbers
    if @card.destroy
      @all_card_numbers.delete(@card.number) if @all_card_numbers
      card_context.current_list_navigation_card_numbers = @all_card_numbers
      flash[:notice] = "Card ##{@card.number} deleted successfully."
      if @next && @all_card_numbers.any?
        redirect_to :action => 'show', :number => @next
      else
        redirect_to last_tab
      end
    else
      set_rollback_only
      flash[:error] = @card.errors.full_messages
      redirect_to :action => 'show', :number => @card.number
    end
  end

  def confirm_bulk_delete
    @card_selection = CardListView.find_or_construct(@project, params).card_selection
    @card = CardSelection.cards_from(@project, params[:selected_cards]).first if params[:selected_cards].split(',').size == 1
    @warnings = @card_selection.warnings
    @destroy_params = params.merge({:action => 'bulk_destroy'})
    render_in_lightbox('confirm_delete')
  end

  def bulk_destroy
    @card_selection = CardListView.find_or_construct(@project, params).card_selection
    if @card_selection.destroy
      flash[:notice] = "#{'Card'.plural(params[:selected_cards].to_s.split(',').size)} deleted successfully."
      redirect_to last_tab
    else
      flash[:error] = @card_selection.errors
      redirect_to last_tab
    end
  end

  def copy_to_project_selection
    @card = @project.cards.find_by_number params[:number]

    @projects = @card.copiable_projects

    card_copy_dialog = render_to_string(:partial => "copy_to_project_selection")
    render(:update) do |page|
      page.inputing_contexts.update(card_copy_dialog)
    end
  end

  def confirm_copy
    @card = @project.cards.find_by_number params[:number]
    @selected_project = Project.find_by_identifier params[:selected_project_id]
    copier = @card.copier(@selected_project)

    if (copier.within_same_project? && copier.missing_attachments.empty?)
      # if copying to same project and there's nothing wrong, no need to confirm
      do_copy(copier)
    else

      respond_to do |format|
        format.xml do
          render :partial => "copy_confirmation", :locals => {:copier => copier}
        end

        format.js do
          lightbox_content = render_to_string(:partial => "copy_confirmation", :locals => {:copier => copier})
          render(:update) do |page|
            page.inputing_contexts.update(lightbox_content)
          end
        end
      end

    end

  end

  def copy
    @card = @project.cards.find_by_number params[:number]
    @selected_project = Project.find_by_identifier params[:selected_project_id]
    do_copy(@card.copier(@selected_project))
  end

  def create_view
    @view = @project.card_list_views.create_or_update(params, self)
    if @view.errors.any?
      set_rollback_only
      flash[:error] = @view.errors.full_messages
      redirect_to last_tab
    else
      flash[:favorite_id] = @view.favorite.id
      redirect_to @view.favorite.to_params
    end
  rescue ActiveRecord::RecordInvalid => e
    set_rollback_only
    flash[:error] = e.message
    redirect_to last_tab
  end

  def create_view_async
    @view = @project.card_list_views.create_or_update(params, self)
    if @view.errors.any?
      render :status => :unprocessable_entity, :text => @view.errors.full_messages.join(", ")
    else
      head :ok
    end
  rescue ActiveRecord::RecordInvalid => e
    render :status => :unprocessable_entity, :text => e.message
  end

  def show_export_options
    @view = CardListView.find_or_construct(@project, params)
    render_in_lightbox 'export_options', :view => @view
  end

  def csv_export
    @view = CardListView.find_or_construct(@project, params)
    include_description = (params[:export_descriptions] == 'yes')
    include_all_columns = (params[:include_all_columns] == 'yes')
    @csv_export = @project.export_csv_cards(@view, include_description, include_all_columns)
    UserDisplayPreference.current_user_prefs.update_preferences({:export_all_columns => include_all_columns, :include_description => include_description})
    if (params[:skip_download] != 'yes')
      headers['Content-Disposition'] = "attachment; filename=\"#{@project.identifier}.csv\""
      headers['Content-Type'] = 'text/csv'
    end
    render :layout => false
  end

  def bulk_set_properties_panel
    @view = CardListView.find_or_construct(@project, params)
    @card_selection = @view.card_selection

    if @view.invalid_selection?
      flash.now[:error] = @view.errors.full_messages.join("\n")
      render(:update) do |page|
        page.refresh_flash
      end
    else
      render(:update) do |page|
        page.refresh_flash
        page['bulk-set-properties-panel'].replace_html(render(:partial => 'bulk_set_properties_panel'))
      end
    end
  end

  def bulk_set_properties
    @view = CardListView.find_or_construct(@project, params)
    @card_selection = @view.card_selection
    number_of_cards_being_updated = @card_selection.count
    if CardViewLimits.allow_bulk_update?(number_of_cards_being_updated)
      changed_property_name = params[:changed_property]
      @card_selection.update_property(changed_property_name, params[:properties][changed_property_name])
      if @card_selection.errors.empty?
        notify_bulk_number_of_cards_udpated(number_of_cards_being_updated)
      else
        set_rollback_only
        flash.now[:error] = @card_selection.errors
      end
    else
      flash.now[:error] = "Bulk update is limited to #{CardViewLimits::MAX_CARDS_TO_BULK_UPDATE} cards. Try refining your filter."
    end
    @view.clear_cached_results_for(:cards)
    @view.reset_paging
    @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

    refresh_list_page(:except => [:tabs])
  end

  def bulk_tagging_panel
    @view = CardListView.find_or_construct(@project, params)
    card_selection = @view.card_selection
    @tags_common_to_all = card_selection.tags_common_to_all
    @tags_common_to_some = card_selection.tags_common_to_some
    render(:update) do |page|
      page.refresh_flash
      page['bulk-tagging-panel'].replace_html(render(:partial => 'bulk_tagging_panel'))
    end
  end

  def bulk_remove_tag
    bulk_tagging do |card_selection|
      tag = @project.tags.find(params[:tag_id])
      card_selection.remove_tag(tag.name) if tag
    end
  end

  def bulk_add_tags
    bulk_tagging do |card_selection|
      card_selection.tag_with(params[:tags])
    end
  end

  def bulk_transition
    if params[:transition_id].blank?
      set_rollback_only
      flash[:error] = "Please select a transition."
      redirect_to last_tab
      return
    end
    transition = @project.transitions.find(params[:transition_id])

    unless transition.valid_on_execute?(params[:user_entered_properties], params[:comment])
      set_rollback_only
      flash[:error] = transition.errors.full_messages
      redirect_to last_tab
      return
    end

    begin
      cards = CardSelection.cards_from(@project, params[:selected_cards])
      cards.each do |card|
        transition.execute(card, nil, params[:comment])
        raise TransitionNotAvailableException.new(card.errors.full_messages.join(" ")) if card.errors.any?
      end

      msg = "#{transition.name.escape_html.bold} successfully applied to "
      msg << if cards.length > 1
        "cards #{cards.collect{ |card| card_number_link(card) }.join(', ')}"
      else
        "card #{card_number_link(cards[0])}"
      end
      html_flash[:notice] = msg
    rescue TransitionNotAvailableException => tnaEx
      set_rollback_only
      msg = add_periods_when_necessary([tnaEx.message]).first
      flash[:error] = msg + "All work was cancelled."
    end

    redirect_to last_tab
  end

  def transition
    @card = @project.cards.find(params[:id])
    transition = @project.transitions.find(params[:transition_id])
    transition.execute_with_validation(@card, params[:user_entered_properties], params.delete(:comment))
    flash[:all_card_numbers] = params[:all_card_numbers]
    @tab_name = params[:tab]
    if transition.errors.any? || @card.errors.any?
      set_rollback_only
      flash.now[:error] = (transition.errors.full_messages + @card.errors.full_messages).uniq
      render(:update) do |page|
        page.refresh_flash
        page.replace 'toggle_hidden_properties_bar', :partial => 'toggle_hidden_properties_bar', :locals => { :card => @card }
      end
    else
      html_flash.now[:notice] = "#{transition.name.escape_html.bold} successfully applied to card #{card_number_link(@card)}"
      @transitions = @card.transitions
      render(:update) do |page|
        page.refresh_flash
        page['card_show_actions_without_back_link_top'].replace_html(:partial => 'card_show_actions_without_back_link', :locals => {:location => 'top'})
        page['card_show_actions_without_back_link_bottom'].replace_html(:partial => 'card_show_actions_without_back_link', :locals => {:location => 'bottom'})
        page['version-info'].replace_html :partial => 'shared/version_info', :locals => { :versionable => @card.reload, :show_latest_url => card_show_url(:number => @card.number) }
        page['show-properties-container'].replace :partial => 'show_properties_container',  :locals => {:card => @card}
        page['card_new_comment'].replace :partial => 'card_new_comment', :locals => {:card => @card, :allow_direct_comments => true}
        page.card_discussion.reload
        page.replace 'toggle_hidden_properties_bar', :partial => 'toggle_hidden_properties_bar', :locals => { :card => @card }
        page.card_history.reload
      end
    end
  end

  def transition_in_old_popup
    @card = @project.cards.find(params[:id])
    transition = @project.transitions.find(params[:transition_id])
    transition.execute_with_validation(@card, params[:user_entered_properties], params[:comment])
    if transition.errors.empty? && @card.errors.empty?
      html_flash.now[:notice] = "#{transition.name.escape_html.bold} successfully applied to card #{card_number_link(@card)}"
      @card.rerank(params[:rerank])
    else
      set_rollback_only
      flash.now[:error] = (transition.errors.full_messages + @card.errors.full_messages).uniq
    end
    cards_result_setup
    display_tree_setup
    refresh_list_page(:except => [:tabs])
  end

  def transition_in_popup
    @card = @project.cards.find(params[:id])
    transition = @project.transitions.find(params[:transition_id])
    transition.execute_with_validation(@card, params[:user_entered_properties], params[:comment])
    if transition.errors.empty? && @card.errors.empty?
      @card.rerank(params[:rerank])
      refresh = refresh_card_preview
      render(:update) do |page|
        if transition.accepts_user_input?
          page << "InputingContexts.pop();"
        end
        self.instance_exec(page, &refresh)
        page << reload_murmurs_in_popup
        page << reload_history_in_popup
      end
    else
      set_rollback_only
      render(:update) do |page|
        element = if transition.accepts_user_input?
          "#transition_button_container"
        else
          "#card-transitions-button"
        end
        page << "$j('#{element}').showApplyTransitionError(\"#{escape_and_format(@card.errors.full_messages.join(". "))}\")"
      end
    end
  end

  def update_property_on_lightbox
    prop_name = params[:property_name].blank? ? nil : params[:property_name].remove_html_tags
    @card = @project.cards.find_by_id(params[:card].to_i)
    if @card.nil?
      render(:update) do |page|
        page << "$j('input[name=\"properties[#{prop_name}]\"]').showSavePropertyErrorMessage('Card may have been destroyed by someone else.')"
      end
      return
    end
    prop_val = params[:property_value].blank? ? params[:property_value] : params[:property_value].remove_html_tags
    @card.update_properties({prop_name => prop_val}, :include_hidden => true)

    if @card.errors.empty? && @card.save
      render(:update, &refresh_card_preview)
    else
      set_rollback_only
      render(:update) do |page|
        page << "$j('input[name=\"properties[#{prop_name}]\"]').showSavePropertyErrorMessage(\"#{escape_and_format(@card.errors.full_messages.join(". "))}\")"
      end
    end
  end

  def require_popup_for_transition
    transition = @project.transitions.find(params[:transition_id])
    card = @project.cards.find(params[:id])
    render_transition_popup(:partial => 'transition_popup', :transition => transition, :card => card)
  end

  def require_popup_for_transition_in_popup
    transition = @project.transitions.find(params[:transition_id])
    @view = CardListView.find_or_construct(@project, params)
    card = @project.cards.find(params[:id])

    render_transition_popup(:partial => 'transition_popup_in_card_popup', :transition => transition, :card => card, :view => @view, :project => @project, :current_project_id => params[:current_project_id])
  end

  def require_comment_for_bulk_transition
    if params[:transition_id].blank?
      set_rollback_only
      flash[:error] = "Please select a transition."
      redirect_to last_tab
      return
    end
    transition = @project.transitions.find(params[:transition_id])
    card_selection = CardListView.find_or_construct(@project, params).card_selection
    render_in_lightbox 'transition_popup_in_bulk', :locals => {:transition => transition, :card_selection => card_selection, :selected_cards => params[:selected_cards] }
  end

  def add_comment
    @card = params[:card_id] ? @project.cards.find(params[:card_id]) : @project.cards.find_by_number(params[:number])
    if @card
      @card.comment = params.delete(:comment)
      return create_comment
    end
    handle_card_not_found
  end

  def refresh_comments
    card = @project.cards.find(params[:card_id])
    render(:update) do |page|
      page.card_discussion.reload
    end
  end

  def refresh_comments_partial(card)
    add_description_partial = render_to_string(partial: 'add_description_link', locals: {card: @card})
    render(:update) do |page|
      page['version-info'].replace_html partial: 'shared/version_info', locals: {versionable: card, show_latest_url: card_show_url(:number => card.number)}
      %w{top bottom}.each { |location| page["card-edit-link-#{location}"].replace partial: 'card_edit_link', locals: {card: card, location: location} }
      page.card_discussion.reload
      page.card_history.reload
      page.select('#add_description_link').each do |element|
        element.replace(add_description_partial)
      end
      page << mark_live_event_js(card)
    end
  end

  def refresh_properties
    @card = params[:card].is_a?(Hash) ? @project.cards.build(params[:card]) : @project.cards.find(params[:card])

    card_type = @project.card_types.find_by_name(params[:properties]["Type"])
    params[:properties].delete('Type')

    params[:properties].each_key do |type|
      params[:properties].delete(type) unless card_type.property_definitions_with_hidden.any?{ |pd| pd.name == type }
    end

    params[:properties].merge!({"Type" => card_type.name})

    @card.update_properties(params[:properties])
    setup_all_card_numbers
    @transitions = @card.transitions
    render(:update) do |page|
      page['card-type-properties-container'].replace :partial => 'card_type_and_properties_widget'
    end
  end

  def update_property
    @card = @project.cards.find_by_id(params[:card])
    if @card.blank?
      return card_does_not_exist("Card(id=#{params[:card]}) does not exist.")
    end

    properties = params[:properties]
    changed_property = params[:changed_property]
    if changed_property && properties && properties[changed_property]
      @card.update_properties({changed_property => properties[changed_property]}, :include_hidden => true)
    end
    respond_to do |format|
      format.html do
        setup_all_card_numbers
        if @card.errors.empty? && @card.save
          render_card_page(@card)
        else
          set_rollback_only
          flash.now[:error] = @card.errors.full_messages
          render_card_page(@card.reload)
        end
      end
      format.json do
        @card.errors.empty? && @card.save
        render :json => @card.errors.full_messages.map(&method(:escape_and_format))
      end
    end
  end

  def update_tags
    @card = @project.cards.find(params[:taggable_id])
    @card.tag_with(params[:tag_list]) if params[:tag_list]
    if @card.errors.empty? && @card.save
      render(:update) do |page|
        page['version-info'].replace_html :partial => 'shared/version_info', :locals => { :versionable => @card, :show_latest_url => card_show_url(:number => @card.number) }
        %w{top bottom}.each { |location| page["card-edit-link-#{location}"].replace :partial => 'card_edit_link', :locals => { :card => @card, :location => location } }
        page['add_description_link'].replace :partial => 'add_description_link', :locals => { :card => @card }
        page.card_history.reload
        page << mark_live_event_js(@card)
      end
    else
      set_rollback_only
      render(:update) do |page|
        flash[:error] = @card.errors.full_messages
        page.redirect_to :action => 'show', :number => @card.number
      end
    end
  end

  def reorder_tags
    return head(:unprocessable_entity) if params[:taggable_id].blank? || params[:new_order].blank?
    @card = @project.cards.find(params[:taggable_id])
    return head(:unprocessable_entity) unless (@card.tags.map(&:name) - params[:new_order]).size == 0

    @card.reorder_tags(params[:new_order])
    @card.versions.last.reorder_tags(params[:new_order])

    render :json => @card.attributes.slice('name', 'number')
  end

  def set_value_for
    number = params[:card_number].to_i
    if @card = @project.cards.find_by_number(number)
      AutoTransition::Controller.new(self, @card).apply
    else
      flash.now[:error] = if @project.card_versions.find_by_number(number)
                            "Card ##{number} has been deleted."
                          else
                            "Could not find card ##{number}."
                          end
      refresh_list_page(:except => [:tabs])
    end
  end

  def update_property_color
    @value = if params[:color_provider_type] == EnumerationValue.name
      @project.find_enumeration_value(params[:id])
    else
      @project.card_types.find(params[:id])
    end
    @value.nature_reorder_disabled = true
    @value.update_attributes(:color => params[:color_provider_color])
    cards_result_setup
    render(:update) do |page|
      page.replace 'color-legend-container', :partial => 'shared/color_legend'
      page.refresh_result_partial(@view)
      page << update_params_for_js(@view)
    end
  end

  def history
    card = @project.cards.find(params[:id])
    history = History.for_versioned(@project, card)
    render :partial => 'shared/events',
      :locals => {:include_object_name => false, :include_version_links => false, :show_initially => true, :history => history, :project => @project, :popup => false}
  end

  def popup_history
    card = @project.cards.find(params[:id])
    history = History.for_versioned(@project, card)
    render :partial => 'shared/events',
      :locals => {:include_object_name => false, :include_version_links => false, :show_initially => true, :history => history, :project => @project, :popup => true}
  end

  def remove_attachment
    @card = find_card_from_params
    file_name = params[:file_name]
    if @card.remove_attachment(file_name) && @card.save
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

  def double_print
    @view = CardListView.find_or_construct(@project, params)
    @view.fetch_descriptions = true
    if @view.nil?
      report_view_missing_and_redirect_to_last_card_view(params[:view])
      return
    end
    card_context.store_tab_state(@view, current_tab[:name], current_tree)
    @cards = @view.all_cards

    if defined?(PdfGenerator)
      public_dir_path = MingleSprocketsConfig.assets_path.gsub(/(\\|\/)assets(\\|\/)?$/, "")

      unless MingleSprocketsConfig.production_assets?
        public_dir_path.gsub!(/(\\|\/)public$/, '\1app\1assets')
      end

      headers["Content-Type"] = "application/pdf"
      headers["Content-Disposition"] = "filename=\"mingle_cards.pdf\";"
      protocol_prefix = "file://"
      protocol_prefix += "/" if public_dir_path.include?(":")
      public_url = protocol_prefix + public_dir_path

      html = default_view_helper.render(:partial => 'cards/double_print', :locals => {:url_base => public_url})
      render :text => Proc.new { |response, output|
        PdfGenerator::create_pdf(html, output)
      }, :layout => false
    else
      render :partial => 'cards/double_print'
    end
  end

  def add_children
    child_cards = @project.cards.find(:all, :conditions => ["#{Project.connection.quote_column_name('number')} IN (?)", params[:child_numbers].split(',')])
    parent_card = parent_card_from_params
    action = add_to_tree(parent_card, child_cards, params)
    card_context.add_to_current_list_navigation_card_numbers(child_cards.collect(&:number))
    render :update do |page|
      flash.now[:info] = action.warning_messages_for_hidden_nodes.join(MingleFormatting::MINGLE_LINE_BREAK_MARKER) if action.has_warning?
      page.refresh_no_cards_found
      if 'true'.ignore_case_equal?(params[:new_cards])
        action.children_added.each{|child_node| page.tree_view.unregister_draggable(child_node.number)}
        if parent_card == :root
          action.children_added_in_filter.each {|child| page.insert_html(:bottom, 'tree', :partial => 'tree_node', :locals => {:node => child})}
          page.add_to_root(action)
        end
      end
      view = CardListView.find_or_construct(@project, params)
      if parent_card == :root
        if action.has_warning?
          page.replace_html "tree_content", :partial => 'card_tree', :locals => {:display_tree => view.display_tree, :tab_name => params[:tab], :view => view}
          page << update_params_for_js(view)
        end
      else
        subtree = action.subtree
        page.replace_subtree(subtree)
        action.card_context.add_to_current_list_navigation_card_numbers(subtree.nodes.collect(&:number))
        page << update_params_for_js(view)
      end
      page.refresh_flash
    end
  rescue TreeConfiguration::InvalidChildException => e
    set_rollback_only
    show_errors(e.errors)
    render :update do |page|
      page.refresh_flash
      page.refresh_no_cards_found
      page.tree_view.redraw
    end
  end

  def remove_card_from_tree_on_card_view
    @tree_config = @project.tree_configurations.find(params[:tree])
    @card = @project.cards.find(params[:card_id])
    remove_card(@tree_config, @card, :with_children => params[:and_children] == 'true')
    setup_all_card_numbers
    @transitions = @card.transitions
    update_card_page(:flash, :action_bar_top, :action_bar_bottom, :version_info, :show_properties_container, :card_history)
  end

  def remove_card_from_tree
    @tree_config = @project.tree_configurations.find(params[:tree])
    @card = @project.cards.find(params[:card_id])
    card_collapsed = !('true'.ignore_case_equal?(params[:card_expanded]))
    remove_with_children = params[:and_children] == 'true'
    remove_collapsed_node_without_children = card_collapsed && !remove_with_children

    removed_cards = remove_card(@tree_config, @card, :with_children => remove_with_children)

    if params[:parent_number].to_i == 0 && remove_collapsed_node_without_children
      return forward_to_list
    end

    if remove_collapsed_node_without_children
      new_parent = @project.cards.find_by_number(params[:parent_number])
      subtree = CardListView.find_or_construct(@project, params).workspace.subtree(new_parent)
    end
    card_context.remove_from_current_list_navigation_card_numbers(removed_cards.collect(&:number))
    render :update do |page|
      page.refresh_no_cards_found
      if remove_collapsed_node_without_children
        page.replace_subtree(subtree)
      else
        page.tree_view.remove_node(@card.number, remove_with_children)
      end
      page.tree_view.register_all_draggable(removed_cards.collect(&:number))
      page.tree_view.reset_search_session
      page.refresh_flash
    end
  end

  def show_tree_cards_quick_add
    @tree_config = @project.tree_configurations.find(params[:tree])
    @parent_card = @project.cards.find_by_number(params[:parent_number].to_i)
    @parent_expanded = params[:parent_expanded]
    @card_types = @tree_config.card_types_after(@parent_card.card_type)
    @tab_name = params[:tab]
    @view_params = params
    render :update do |page|
      page.replace_html 'tree_cards_quick_add', :partial => 'tree_cards_quick_add'
      page.tree_view.show_quick_add(@parent_card.html_id + '_inner_element', 'tree_cards_quick_add')
    end
  end

  def show_tree_cards_quick_add_to_root
    @tree_config = @project.tree_configurations.find(params[:tree])
    @card_types = @tree_config.all_card_types
    @tab_name = params[:tab]
    @view_params = params
    render :update do |page|
      page.replace_html 'tree_cards_quick_add', :partial => 'tree_cards_quick_add'
      page.tree_view.show_quick_add("node_0_inner_element", 'tree_cards_quick_add')
    end
  end

  def show_tree_cards_quick_add_on_card_show_page
    @tree_config = @project.tree_configurations.find(params[:tree])
    @parent_card = @project.cards.find_by_number(params[:parent_number].to_i)
    @card_types = @tree_config.card_types_after(@parent_card.card_type)
    @tab_name = params[:tab]
    @from_card_show = true
    render :update do |page|
      page.replace_html 'tree_cards_quick_add', :partial => 'tree_cards_quick_add'
      page.card_view.show_quick_add("show-add-children-link-#{@tree_config.id}", 'tree_cards_quick_add')
    end
  end

  def tree_cards_quick_add_to_root
    @tab_name = params[:tab]
    parent_card = :root
    child_cards, errors_on_card_create = new_cards_from_params
    if child_cards.empty? && errors_on_card_create.empty?
      render :update do |page|
        page.select('#tree_cards_quick_add_cancel_button').first.onclick
      end
      return
    end

    if errors_on_card_create.any?
      handle_tree_quick_add_error(errors_on_card_create)
      return
    end
    action = add_to_tree(:root, child_cards, params)
    flash.now[:notice] = "#{'cards'.enumerate(child_cards.size)} #{'was'.plural(child_cards.size)} created successfully."
    add_monitoring_event("create_card", {'project_name' => @project.name})
    render :update do |page|
      flash.now[:info] = action.warning_messages_for_hidden_nodes.join("</br>") if action.has_warning?
      page.refresh_no_cards_found
      page.refresh_flash

      action.children_added_in_filter.each {|child| page.insert_html(:bottom, 'tree', :partial => 'tree_node', :locals => {:node => child})}
      page.tree_view.addToRoot(action.children_added_in_filter) if action.has_child_in_filter?
      page['tree_cards_quick_add'].hide
    end
  end

  def tree_cards_quick_add
    @tab_name = params[:tab]
    parent_card = parent_card_from_params
    child_cards, errors_on_card_create = new_cards_from_params
    if child_cards.empty? && errors_on_card_create.empty?
      render :update do |page|
        page.select('#tree_cards_quick_add_cancel_button').first.onclick
      end
      return
    end

    if errors_on_card_create.any?
      handle_tree_quick_add_error(errors_on_card_create)
      return
    end

    action = add_to_tree(parent_card, child_cards, params)
    subtree = action.subtree
    card_context.add_to_current_list_navigation_card_numbers(subtree.nodes.collect(&:number))

    flash.now[:notice] = "#{'cards'.enumerate(child_cards.size)} #{'was'.plural(child_cards.size)} created successfully."
    add_monitoring_event("create_card", {'project_name' => @project.name})

    if params[:from_card_show]
      render :update do |page|
        page.refresh_flash
        page['tree_cards_quick_add'].hide
        page['show-properties-container'].replace :partial => 'show_properties_container', :locals => {:card => parent_card}
      end
    else
      render :update do |page|
        flash.now[:info] = action.warning_messages_for_hidden_nodes.join("</br>") if action.has_warning?
        page.refresh_no_cards_found
        page.refresh_flash
        page.replace_subtree(subtree)
        page['tree_cards_quick_add'].hide
        page << update_params_for_js(CardListView.find_or_construct(@project, params))
      end
    end
  end

  def chart
    if (@card = @project.cards.find_by_id(params[:id]) || params[:preview])
      content = params[:preview] ? session[:renderable_preview_content] : @card.content
      generated_chart = Chart.extract_and_generate(content, params[:type], params[:position].to_i, :content_provider => @card, :dont_use_cache => params[:preview])
      send_data(generated_chart, :type => "image/png",:disposition => "inline")
    else
      card_does_not_exist("Could not find card by id #{params[:id]}")
    end
  end

  def chart_data
    @card = @project.cards.find_by_id(params[:id])
    @card = @card.find_version(params[:version].to_i) if params[:version]
    content = params[:preview] ? session[:renderable_preview_content] : @card.content
    generated_chart = Chart.extract_and_generate(content, params[:type], params[:position].to_i, :content_provider => @card, :dont_use_cache => params[:preview], :preview => params[:preview])
    render :json => generated_chart
  end

  def async_macro_data
    @card = @project.cards.find_by_id(params[:id])
    @card = @card.find_version(params[:version].to_i) if params[:version]
    content = params[:preview] ? session[:renderable_preview_content] : @card.content
    generated_chart = Macro.get(params[:type]).extract_and_generate(content, params[:type], params[:position].to_i, :content_provider => @card, :dont_use_cache => params[:preview], :preview => params[:preview], :view_helper => default_view_helper)
    render :text => generated_chart, :status => 200
  end

  def chart_as_text
    @card = @project.cards.find_by_id(params[:id])
    content = params[:preview] ? session[:renderable_preview_content] : @card.content
    chart = Chart.extract(content, params[:type], params[:position].to_i, :content_provider => @card, :dont_use_cache => params[:preview], :preview => params[:preview])
    text_chart = chart.generate_as_text

    render :update do |page|
      page.replace_html 'chart-data', text_chart
    end
  end

  def add_attachment
    respond_to do |format|
      format.xml do
        @card = @project.cards.find_by_number(params[:number])
        attachments = @card.attach_files(params[:file])
        if @card.save && @card.errors.empty?
          file_name = FileColumn::sanitize_filename(attachments.first.original_filename.downcase)
          head :created, :location => @card.attachments.detect{|at| at.file_name.downcase == file_name}.url
        end
      end
    end
  end

  def execute_mql
    if params[:mql].blank?
      respond_xml_or_json_error(['Parameter mql is required'])
      return
    end

    query = CardQuery.parse(params[:mql])
    mql_validations = CardQuery::MQLFilterValidations.new(query).execute
    if mql_validations.any?
      respond_xml_or_json_error(mql_validations)
    else
      respond_to do |format|
        format.json do
          if params[:callback]
            response.headers["Content-Type"] = "application/javascript"
          end
          render :json => query.values, :callback => params[:callback]
        end
        format.xml { render :xml => query.values_as_xml(:api_version => params[:api_version]) }
      end
    end
  rescue CardQuery::DomainException => e
    Kernel.log_error(e, "execute_mql failed.", :severity => Logger::WARN)
    respond_xml_or_json_error([e.message])
  end

  def can_be_cached
    respond_to do |format|
      format.xml { render :xml => {:results => CardQuery.parse(params[:mql]).can_be_cached? }.to_xml }
    end
  end

  def format_number_to_project_precision
    return unless params[:format] == 'xml'
    respond_to do |format|
      format.xml { render :xml => {:result => @project.to_num(params[:number])}.to_xml }
    end
  rescue StandardError => e
    handle_error(e)
  end

  def format_string_to_date_format
    respond_to do |format|
      format.xml { render :xml => {:result => @project.format_date(Date.parse_with_hint(params[:date], @project.date_format))}.to_xml }
    end
  rescue StandardError => e
    handle_error(e)
  end

  def toggle_hidden_properties
    session[:show_hidden_properties] = params['toggle_hidden_properties'] == 'true'
    render :nothing => true
  end

  def card_name
    card_number = params[:number]
    name = @project.connection.select_value(SqlHelper::sanitize_sql("select name from #{@project.connection.safe_table_name(Card.table_name)} where #{@project.connection.quote_column_name 'number'} = ?", card_number))
    if name
      render :json => {:project => @project.identifier, :name => name, :number => card_number}.to_json
    else
      render :text => "(no such card)", :status => :not_found
    end
  end

  TAB_UPDATE_ACTIONS = %w(index list grid tree hierarchy expand_hierarchy_node collapse_hierarchy_node expand_tree_node collapse_tree_node)
  def tab_update_action?
    TAB_UPDATE_ACTIONS.include?(action_name)
  end

  private

  def do_copy(copier)
    new_card = copier.copy_to_target_project
    flash.now[:notice] = render_to_string(:partial => "copy_success", :locals => {:new_card => new_card})
    render(:update) do |page|
      page.inputing_contexts.pop
      page.refresh_flash
    end
  end

  def refresh_card_preview
    @view = CardListView.find_or_construct(@project, params)
    lambda do |page|
      page.replace_if_exists 'card-type-droplist', :partial => 'cards/card_type_editor', :locals => { :card => @card }
      page << refresh_card_popup_color(@card, @view)
      page << refresh_transitions_count(@card)
      page.replace_if_exists 'card-transitions-button', :partial => 'card_transitions_button', :locals => {:card => @card}
      page.replace_if_exists 'card-description', :partial => 'card_content', :locals => {:card => @card, :empty_description_text => "(no description)", :popup => true }
      page.replace_if_exists 'checklist-container', :partial => 'checklists', :locals => { :card => @card }
      page.replace_if_exists 'card-properties', :partial => "card_properties", :locals => {:card => @card, :properties_expanded => params[:properties_expanded] == 'true' }
      if !params[:current_project_id] || @project.identifier == params[:current_project_id]
        page.replace_if_exists 'color-legend-container', :partial => 'shared/color_legend'
        page.replace_if_exists 'filters-panel', :partial => @view.style.filter_tabs(@view), :locals => { :view => @view }
        if @view.grid?
          page << mark_live_event_js(@card)
          page.refresh_result_partial(@view)
          page << update_params_for_js(@view)
        end
      end
    end
  end

  def convert_content_to_html_if_necessary(card)
    card.convert_redcloth_to_html! if card.redcloth
  end

  def update_associations(card)
    (params['plan_objectives'] || {}).all? do |plan_id, objective_ids|
      if @plan = Plan.find(plan_id)
        begin
          objectives = @plan.program.objectives.planned.find_all_by_id(objective_ids.split(',').map(&:to_i))
          @plan.assign_card_to_objectives(@project, card, objectives)
          true
        rescue => e
          log_error(e)
          false
        end
      end
    end.tap do |success|
      card.errors.add_to_base("Update associated Plan Objectives failed") unless success
    end
  end

  def add_to_tree(parent_card, child_cards, params)
    tree_config = @project.tree_configurations.find(params[:tree])
    action = AddChildrenAction.new(@project, tree_config, params, card_context)
    action.execute(parent_card, child_cards)
    action
  end

  def handle_error(err)
    logger.error err.message
    respond_to do |format|
      format.xml { render :xml => err.xml_message, :status => 500  }
    end
  end

  def show_latest_version_notice_message_if_needed(coming_from_version)
    if coming_from_version && coming_from_version.to_i < @card.version
      message = "This card has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, #{card_number_link(@card, :link_text => 'go back', :version => coming_from_version)} to the previous card view or view the #{card_number_link(@card, :link_text => 'latest version')}."
      html_flash.now[:info] = message
    end
  end

  def notify_bulk_number_of_cards_udpated(cards_updated_size)
    flash.now[:notice] = "#{'cards'.enumerate(cards_updated_size)} updated."
  end

  def report_view_missing_and_redirect_to_last_card_view(view_param)
    flash[:error] = escape_and_format("#{view_param[:name].bold} is not a favorite")
    redirect_to last_tab
  end

  def remove_card(tree_config, card, options = {})
    if options[:with_children]
      tree_config.remove_card_and_its_children(card, options)
    else
      tree_config.remove_card(card)
    end
  end

  def add_periods_when_necessary(messages)
    messages.collect { |msg| msg =~ /(.*[.])\s*\z/ ? "#{$1} " : "#{msg}. " }
  end

  def lose_last_tab_info
    card_context.clear_last_tab_params_on_tab_change(current_tab[:name]) if @project
  end

  def default_view_helper
    view = ActionView::Base.new(File.join(Rails.root, "/app/views"), {:cards => @cards, :project => @project}, self)
    view.extend(ApplicationHelper)
    view.extend(CardsHelper)
    view
  end

  def selected_card_ids
    selected_card_ids = []
    params.each do |param_name, value|
      if param_name =~ /^(checkbox_)(\d*)$/
        selected_card_ids[$2.to_i] = value
      end
    end
    selected_card_ids.delete_if{|id| id.nil?}
  end

  def find_and_update_card
    @card = find_card_from_params
    update_card
  end

  def update_card(include_hidden = true)
    return unless @card

    if params[:card]
      @card.name = params[:card][:name] if params[:card].has_key?(:name)
      if params[:card].has_key?(:description)
        @card.description = process_content_from_ui(params[:card][:description])
        @card.editor_content_processing = !api_request?
      end
      @card.card_type_name = params[:card][:card_type_name] if params[:card][:card_type_name]
    end
    @card.tag_with(params[:tagged_with]) if params[:tagged_with]

    card_properties = if params[:properties]
      params[:properties]
    elsif params[:card]
      @api_delegate.card_properties
    end || {}

    @card.update_properties(card_properties, :include_hidden => include_hidden)

    @card.comment = params[:comment]

    if @card.errors.empty? && @card.valid?
      if params[:deleted_attachments]
        params[:deleted_attachments].keys.each do |file_name|
          @card.remove_attachment(file_name) if params[:deleted_attachments][file_name] == 'true'
        end
      end
      @card.attach_files(*params[:attachments].values) if params[:attachments]
    end
    @card.ensure_attachings(*params[:pending_attachments]) if params[:pending_attachments]
    @card
  end

  def render_on_error(error_message, render_action)
    on_error(error_message)
    render :action => render_action
  end

  def on_error(error_message)
    set_rollback_only
    flash.now[:error] = error_message
  end

  def setup_all_card_numbers
    card_in_current_context = (card_context.current_list_navigation_card_numbers || []).include?(@card.number)
    if card_in_current_context
      @all_card_numbers = card_context.current_list_navigation_card_numbers
      current_index = @all_card_numbers.index(@card.number)
      @previous = @all_card_numbers[(current_index - 1) % @all_card_numbers.size]
      @next = @all_card_numbers[(current_index + 1) % @all_card_numbers.size]
      @index = current_index + 1
      @total = @all_card_numbers.size
    else
      # navigated directly to this card, don't display prev/next navigation
      @all_card_numbers = nil
      card_context.clear_current_list_navigation_card_numbers
    end
  end

  def properties_are_empty(transition)
    empty_enumerated_properties = transition.require_user_to_enter_property_definitions_in_smart_order.select do |property_definition|
      property_definition.respond_to?(:enumeration_values) && !property_definition.support_inline_creating? && property_definition.enumeration_values.empty?
    end

    if empty_enumerated_properties.any?
      set_rollback_only
      they_it_string = empty_enumerated_properties.size > 1 ? 'they are' : 'it is'
      flash.now[:error] = "The transition #{transition.name.bold} requires that the #{'property'.plural(empty_enumerated_properties.size)} #{empty_enumerated_properties.collect{ |prop_def| prop_def.name.bold }.to_sentence } be set, but #{they_it_string} empty. Please contact a project administrator."
      render(:update) do |page|
        page.refresh_flash
      end
      return true
    end
    false
  end

  def render_card_page(card)
    @card = card
    @transitions = @card.transitions
    update_card_page(:flash, :action_bar_top, :action_bar_bottom, :version_info, :show, :card_history)
  end

  def update_card_page(*widgets, &block)
    render :update do |page|
      page['flash'].replace :partial => 'layouts/flash' if widgets.include?(:flash)
      page['action-bar-top'].replace(:partial => 'card_show_actions', :locals => {:location => 'top'}) if widgets.include?(:action_bar_top)
      page['action-bar-bottom'].replace(:partial => 'card_show_actions', :locals => {:location => 'bottom'}) if widgets.include?(:action_bar_bottom)
      page['version-info'].replace_html :partial => 'shared/version_info', :locals => { :versionable => @card.reload, :show_latest_url => card_show_url(:number => @card.number) } if widgets.include?(:version_info)
      page['show-properties-container'].replace :partial => 'show_properties_container', :locals => {:card => @card} if widgets.include?(:show_properties_container)
      page['renderable-contents'].replace_html :partial => 'show', :locals => {:card => @card} if widgets.include?(:show)
      page << "$j(\".dropzone[data-attachable-id='#{@card.id}']\").length && MingleUI.attachable.initDropzone($j(\".dropzone[data-attachable-id='#{@card.id}']\").get(0))"
      page.card_history.reload if widgets.include?(:card_history)
    end
  end

  def new_cards_from_params
    errors_on_card_create = []
    child_cards = []
    card_type = @project.card_types.find(params[:card_type])
    params[:card_names].each_with_index do |card_name, index|
      next if card_name.blank?
      child_card = @project.cards.build(:card_type_name => card_type.name, :name => card_name)
      child_card.set_defaults

      if child_card.errors.empty? && child_card.valid?
        child_cards << child_card
      else
        errors_on_card_create << OpenStruct.new(:index => index, :name => card_name, :messages => child_card.errors.full_messages)
      end
    end
    return child_cards, errors_on_card_create
  end

  def render_card_popup_json(cards)
    popup_data = cards.inject({}) do |result, card|
      result[card.number] = render_to_string(:partial => 'card_popup_data', :locals => {:card => card})
      result
    end
    # direct render text to bypass prototype's eval json performance issue
    render :text => popup_data.to_json
  end

  def render_transition_popup(options = {})
    return if properties_are_empty(options[:transition])
    lightbox_opts = options.delete(:lightbox_opts)
    config = {:locals => options}
    config.update(:lightbox_opts => lightbox_opts) if lightbox_opts
    render_in_lightbox options[:partial], config
  end

  def card_does_not_exist(msg)
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_to :action => 'list'
      end
      format.xml do
        render :nothing => true, :status => :not_found
      end
      format.js do
        render :nothing => true, :status => :not_found
      end
      format.json do
        render :nothing => true, :status => :not_found
      end
    end
  end

  def should_not_update_old_card_version
    respond_to do |format|
      format.xml do
        render :xml => 'Should not update old card version', :status => 403
      end
    end
  end

  def update_old_version_in_rest
    params[:format] == 'xml' && params[:version] && params[:version].to_i < @card.version
  end

  def find_card_from_params
    if params[:id]
      @project.cards.find_by_id(params[:id])
    elsif params[:number]
      @project.cards.find_by_number(params[:number].to_i)
    end
  end

  def bulk_tagging(&operation)
    @view = CardListView.find_or_construct(@project, params)
    card_selection = @view.card_selection
    if CardViewLimits::allow_bulk_update?(card_selection.count)
      if yield(card_selection)
        notify_bulk_number_of_cards_udpated(card_selection.count)
      else
        set_rollback_only
        flash.now[:error] = card_selection.errors if card_selection.errors.any?
      end
    else
      flash.now[:error] = "Bulk update is limited to #{CardViewLimits::MAX_CARDS_TO_BULK_UPDATE} cards. Try refining your filter."
    end

    @tags_common_to_all = card_selection.tags_common_to_all
    @tags_common_to_some = card_selection.tags_common_to_some
    @view.clear_cached_results_for(:cards)
    @view.reset_paging
    @project.tags.reload

    @cards, @title = card_context.setup(@view, current_tab[:name], params[:favorite_id])

    refresh_list_page(:except => [:tabs])
  end

  # TODO: need figure out a better way to remove mingle formatting in the json
  def respond_xml_or_json_error(messages)
    error = ActiveRecord::Errors.new('')
    messages.each do |message|
      error.add_to_base(message)
    end
    respond_to do |format|
      format.xml { render :xml => error.to_xml, :status => 422  }
      format.json { render :json => remove_mingle_formatting(error.to_json), :status => 422 }
    end
  end

  def toggle_node_setup
    @view = CardListView.find_or_construct(@project, params)
    return unless display_tree_setup
    subtree = @view.workspace.subtree(@tree.find_card_by_number(params[:number].to_i))
    card_context.store_tab_state(@view, current_tab[:name], current_tree)
    subtree
  end

  def handle_tree_quick_add_error(errors_on_card_create)
    set_rollback_only
    errors = errors_on_card_create.inject([]) do |result, error|
      card_name = error.name.size > 50 ? error.name.truncate_with_ellipses(50) : error.name
      if error.messages.size > 1
        result << "#{card_name}: <ul>#{error.messages.collect(&:as_li).join}</ul>"
      else
        result << "#{card_name}: #{error.messages.first}"
      end
    end
    errors << "No cards have been created."
    html_flash.now[:error] = errors.map(&:escape_html).join("<br/>")
    render :update do |page|
      page.refresh_flash
      page.errors.refresh('.card-name-input', errors_on_card_create.collect(&:index))
    end
  end

  def parent_card_from_params
    @project.cards.find_by_number(params[:parent_number].to_i) || :root
  end

  def already_deleted
    flash[:error] = "The card you attempted to delete no longer exists."
    render :update do |page|
      page.redirect_to :action => 'list'
    end
  end

  def forward_to_list
    self.action_name = 'list'
    list
  end

  def user_preference(visibility_preference)
    User.current.display_preference(session).read_preference(visibility_preference)
  end

  def render_transition_forms?
    request.referer.nil? || !(URI.parse(request.referer).path =~ /\/cards\/(grid|list|hierarchy)$/)
  end

  def create_comment
    if @card.save
      respond_to do |format|
        format.html do
          add_monitoring_event('create_card_murmur_in_app', {'project_name' => @project.name})
          refresh_comments_partial(@card)
        end
        format.xml do
          render_model_xml @card.origined_murmurs.last
        end
      end
    else
      respond_to do |format|
        format.html do
          set_rollback_only
          render(:update) do |page|
            flash.now[:error] = @card.errors.full_messages
            page['flash'].replace :partial => 'layouts/flash'
          end
        end
        format.xml do
          render :xml => @card.errors.to_xml, :status => 422
        end
      end
    end
  end

  def handle_card_not_found
    respond_to do |format|
      format.html do
        set_rollback_only
        render(:update) do |page|
          flash.now[:error] = 'Card not found'
          page['flash'].replace :partial => 'layouts/flash'
        end
      end
      format.xml do
        render :xml => 'Card not found', :status => :not_found
      end
    end
  end

  def card_xml_options(params)
    %w(true t 1).include?(params[:include_transition_ids]) ? {:slack => true} : {}
  end
end
