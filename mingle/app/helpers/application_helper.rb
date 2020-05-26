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

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include HelpDocHelper,
          AsynchRequestsHelper,
          TabsHelper,
          DropListOptionsHelper,
          UserDisplayPreferenceHelper,
          MacroSizeValidationHelper,
          LightboxHelper,
          UserAccess,
          QuickAddCardsHelper,
          AlsoViewingHelper,
          ProjectAdminActionsHelper,
          MetricsHelper,
          JavascriptBuffer,
          FootbarHelper,
          AttachmentsHelper,
          AWSHelper,
          InvitesHelper,
          TagsHelper

  def show_buy_button?
    MingleConfiguration.new_buy_process? &&
      !CurrentLicense.status.paid? &&
      !CurrentLicense.status.buying?
  end

  def show_downgrade_lightbox
    <<-JAVASCRIPT
InputingContexts.push(new LightboxInputingContext(null, {}));
InputingContexts.update(#{@downgrade_view.to_json});
JAVASCRIPT
  end

  def icon_url_for_model(model)
    url = URI.parse(url_for_file_column(model, "icon").to_s)

    if MingleConfiguration.public_icons?
      unless MingleConfiguration.asset_host.blank?
        asset_host = URI.parse(MingleConfiguration.asset_host)
        url.host = asset_host.host
        url.port = asset_host.port
        url.scheme = asset_host.scheme
      end
    end
    url.to_s
  end

  def project_admin_link_params
    if authorized?({ :controller => 'projects', :action => 'edit'})
      { :controller => 'projects', :action => 'edit', :project_id => @project.identifier }
    else
      { :controller => 'team', :action => 'list' }
    end
  end

  def team_list_search_option
    { :exclude_deactivated_users => true }
  end

  def header_pill_class(tab_name, current_tab_name)
    if tab_name == current_tab_name
      "header-menu-pill selected #{tab_name}"
    else
      "header-menu-pill #{tab_name}"
    end
  end

  def page_title_and_h1(title)
    @title = title
    "<h1>#{title}</h1>"
  end

  def page_title
    return @title + " - " + ice_resource_type if @title

    @title = if ["index", "list", 'grid', 'tree'].include?(@controller.action_name)
      "#{@controller.controller_name.pluralize.humanize}"
    else
      "#{@controller.action_name.humanize.split(' ').collect{|word| word.capitalize}.join(' ')} #{@controller.controller_name.singularize.capitalize}"
    end

    @title = (@project && !@project.new_record?) ? "#{@project.name} #{@title}" : @title
    "#{@title} - Mingle"
  end

  def mingle_will_paginate(collection = nil, options = {})
    content_tag :div, :class => 'pagination' do
      will_paginate(collection, options.merge(:next_label => 'Next', :previous_label => 'Previous', :container => false)) || '&nbsp;'.html_safe
    end
  end

  def project_selected?
    @project && @project.identifier && !@project.new_record?
  end

  def card_context
    @card_context ||= CardContext.new(@project, session["project-#{@project.id}"])
  end

  def rendering_login?
    @controller.is_a?(ProfileController) && @controller.action_name == 'login'
  end

  def ice_resource_type
    [HistoryController, SourceController].any? do |controller|
      return "Mingle #{@controller.controller_name.singularize.humanize}" if @controller.kind_of?(controller) and ['show', 'index'].include?(@controller.action_name)
    end

    [CardsController, PagesController].any? do |controller|
      return "Mingle #{@controller.controller_name.singularize.humanize}" if @controller.kind_of?(controller) and ['show'].include?(@controller.action_name)
    end
    "Mingle"
  end

  def display_tabs
    @controller.display_tabs
  end

  def ckeditor_text_area_tag(renderable, name, value, options={})
    renderable_type = renderable.class.name.underscore
    context_provider_info = {type: renderable.class.name, id: renderable.id, number: renderable.respond_to?(:number) ? renderable.number : nil}
    unless options.delete(:no_macros)
      options.merge!({
        :'data-ckeditor-mingle-macro-help-url' => link_to_help('MQL'),
        :'data-ckeditor-mingle-macro-data-render-url' => url_for(:controller => "macro_editor", :action => "render_macro", :type => renderable_type, :id => renderable.id),
        :'data-ckeditor-mingle-macro-data-editor-url' => url_for(:controller => "macro_editor", :action => "show", :content_provider => {:provider_type => renderable.class.name, :id => renderable.id}),
        :'data-ckeditor-mingle-macro-data-generate-url' => url_for(:controller => "macro_editor", :action => "generate"),
        :'data-ckeditor-mingle-macro-edit-params-url' => url_for(controller: :macro_editor, action: :chart_edit_params, content_provider: context_provider_info),
        :'data-project-identifier' => Project.current.identifier,
        :'data-macro-help-urls' => {'pie-chart' => link_to_help('pie-chart'),
                                    'ratio-bar-chart' => link_to_help('ratio-bar-chart'),
                                    'stacked-bar-chart' => link_to_help('stack-bar-chart'),
                                    'data-series-chart' => link_to_help('data-series-chart'),
                                    'cumulative-flow-graph' => link_to_help('cumulative-flow-graph'),
                                    'daily-history-chart' => link_to_help('daily-history-chart')}.to_json,
        :'data-content-provider' => context_provider_info.to_json,
        :'data-easy-charts-macro-editor-enabled-for' => MingleConfiguration.easy_charts_macro_editor_enabled_for
      })
    end

    unless options.delete(:no_attachments)
      options.merge!(attachments_data_attrs(renderable))
    end

    text_area_tag(name, value, options)
  end

  def show_image(image_name)
    image_name.blank? ? '' : image_tag(image_name)
  end

  def tab_class(tab)
    tab.current? ? 'current-menu-item' : 'menu-item'
  end

  def url_options_for_cards_tab(tab_name, tree_name)
    view_params = @controller.card_context.view_params_for(tab_name, tree_name)
    view_params.merge(:controller => 'cards', :project_id => @project.identifier)
  end

  def link_to_current_tab(tab_name, html_options = nil)
    link_to(tab_name, url_options_for_cards_tab(@controller.current_tab[:name], @controller.current_tree), html_options)
  end

  def link_to_last_viewed_set_of_cards(html_options = {})
    link_params = @controller.last_tab
    link_params.merge!('controller' => 'cards') unless link_params.key?('controller')
    if link_params['controller'] == @controller.controller_name
      link_name = @controller.current_tab[:name].escape_html
      truncated_link = @controller.current_tab[:name].truncate_with_ellipses(13).escape_html
      link_to("<span title='Up to #{link_name}' id='up-link-hover-text'>Up to #{truncated_link}</span>".html_safe, link_params, {:id => 'up', :class => 'up action-bar-separator', :for_readonly => true}.merge(html_options))
    else
      link_name = @controller.card_context.send(:last_tab_name) || "Last Tab"
      truncated_link = link_name.truncate_with_ellipses(13)
      link_to("<span title='Back to #{link_name.escape_html}' id='up-link-hover-text'>Back to #{truncated_link.escape_html}</span>".html_safe, link_params, {:id => 'up', :class => 'back action-bar-separator', :for_readonly => true}.merge(html_options))
    end
  end

  module FlashMessages
    def render_flash_messages
      result = []

      result << render_flash_message(content_tag('div', flash[:notice], {:id => 'notice', :class => 'flash-content'}, false), 'success-box') if flash[:notice]

      if flash[:error]
        message = if flash[:error].is_a?(Array)
          flash[:error].join("<br/>")
        else
          flash[:error]
        end.html_safe
        result << render_flash_message(content_tag('div', message, {:id => 'error', :class => 'flash-content'}, false), 'error-box')
      end

      result << render_flash_message(content_tag('div', flash[:downgrade_info], {:id => 'downgrade-info', :class => 'flash-content'}, false), 'info-box') if flash[:downgrade_info]
      result << render_flash_message(content_tag('div', flash[:license_error], {:id => 'info', :class => 'flash-content'}, false), 'info-box') if flash[:license_error]
      result << render_flash_message(content_tag('div', flash[:not_found], {:id => 'not_found', :class => 'flash-content'}, false), 'error-box') if flash[:not_found]
      result << render_flash_message(content_tag('div', flash[:info], {:id => 'info', :class => 'flash-content'}, false), 'info-box') if flash[:info]
      result << render_flash_message(content_tag('div', flash[:warning], {:id => 'warning', :class => 'flash-content'}, false), 'warning-box') if flash[:warning]

      if @project && @project.corrupt?
        message = controller.render_inline(@project.corruption_info.html_safe)
        result << render_flash_message(content_tag('div', message, {:id => 'project_corruption_info', :class => 'flash-content'}, false), 'error-box')
      end
      result.uniq.join("").html_safe
    end

    def render_flash_message(content, css_class, extra_properties = {})
      content_tag_string(:div, content, {:class => css_class}.merge(extra_properties), false)
    end

    def render_error_box(content, html_options={})
      html_options = html_options.merge(:class => 'flash-content')
      render_flash_message(content_tag('div', content, html_options, false), 'error-box')
    end
  end
  include FlashMessages

  def user_password_note_messages
    %{At least 5 characters including a number and a symbol character.} if Authenticator.strict_password_format?
  end

  def h_or_nbsp(property_value)
    if property_value.set?
      h(property_value.display_value_with_stale_state)
    else
      "&nbsp;"
    end
  end

  def hidden_view_tags(view, options = {})
    page = options[:include_page] ? view.page : nil
    hidden_view_params_tags(view.page, view.to_params, options)
  end

  def hidden_view_params_tags(page, params, options = {})
    params.delete(:action)
    options[:except].each{|p| params.delete(p)} if options[:except]
    params.merge!(:page => page) if options[:include_page] == true
    params.merge!(:rerank => options[:rerank])

    hidden_field_tags_from_params_hash(params)
  end

  def hidden_field_tags_from_params_hash(params_hash, outer_hash_name = nil)
    params_hash.collect do |name, value|
      field_name = outer_hash_name.nil? ? name : "#{outer_hash_name}[#{name}]"
      if value.is_a?(Hash)
        hidden_field_tags_from_params_hash(value, field_name)
      elsif value.is_a?(Array)
        fields_from_array(value, field_name)
      else
        hidden_field_tag(field_name, value)
      end
    end.flatten.join("\n")
  end

  def fields_from_array(values, field_name)
    values.collect{ |value| hidden_field_tag("#{field_name}[]", value, :id => nil) }
  end

  def sorter_th(view, column)
    sorter_th_with_title(view, column, column)
  end

  def sorter_th_with_title(view, column, title)
    span = content_tag('span', h(title), :class => "sortable_column #{view.column_header_html_class(column)}")
    link_url = link_to_remote(span, {:url => view.flip_sort_params(column).merge(:controller => 'cards'), :method => 'GET'}, { :class => 'column-header-link sortable_wrapper' })
    content_tag('th', link_url)
  end

  def timeago(time)
    raw(%{<abbr class="timeago" title="#{time.xmlschema}">#{Project.current.format_time(time)}</abbr>})
  end

  def replace_card_links(message)
    content = message.to_s #ensures we convert from ActiveSupport::Multibyte::Chars to string, because the former react badly to being gsub!(ed), #2179, #2055
    [Renderable::CrossProjectCardSubstitution, Renderable::CardSubstitution].each do |s|
      content = s.new(:project => @project, :view_helper => self).apply(content)
    end
    content
  end

  def controller_name
    @controller.controller_name if @controller.respond_to?(:controller_name)
  end

  def collapsible(header, initially_shown, options={}, &block)
    content = block_given? ? capture(&block) : render(:partial => options[:partial], :locals => options[:locals])
    escaped_header = header.gsub(/\W/,'-')
    outer_div_id = if options[:html] and options[:html][:id]
      options[:html][:id]
    else
      "collapsible-section-for-" << escaped_header
    end
    collapsible_style = (options[:style] || {})[:collapsible_style] || 'default'
    content_style = (options[:style] || {})[:collapsible_content_style] || 'collapsible_content_light'
    content_id = "collapsible-content-for-" << escaped_header
    header_id = "collapsible-header-for-" << escaped_header
    additional_class = (options[:html] && options[:html][:class]) || ''

    initially_shown = initially_shown_preference(options[:visibility_preference], initially_shown)
    remember_function = if options[:visibility_preference]
      remember_hide_call = remember_hide_call(options[:visibility_preference])
      remember_show_call = remember_show_call(options[:visibility_preference])
      %{
        if (Element.visible('#{content_id}')) {
          eval(#{remember_show_call})
        } else {
          eval(#{remember_hide_call})
        }
      }
    else
      ''
    end

    js_content = %Q{
$j("##{header_id}").click(function(e) {
  if ($j(this).hasClass("section-expand")) {
    $j(this).attr("class", "section-collapse");
    $j("##{content_id}").show();
  } else {
    $j(this).attr("class", "section-expand");
    $j("##{content_id}").hide();
  }
  #{remember_function}
  e.preventDefault();
  e.stopPropagation();
});
}
    result = <<-OUTPUT
        <div class="collapsible-section-#{collapsible_style} #{additional_class}" id='#{outer_div_id}'>
          <div class='collapsible-header-#{collapsible_style}'>
            #{render_help_link header}
            #{ spinner :id => 'spinner-for-' + escaped_header, :class => 'spinner-for-collapsible', :style => 'display: none;' }
            <h2>
              <a href='#' id='#{header_id}' class="section-#{initially_shown ? "collapse" : "expand"}">#{h header}</a>
            </h2>
            #{clear_float}
          </div>
          <div class='#{content_style}' id='#{content_id}' style="#{initially_shown ? '' : 'display:none'}">#{content}</div>
         #{javascript_with_rescue(js_content)}
        </div>
    OUTPUT
    result = result.html_safe
    if block_given?
      concat(result)
    else
      result
    end
  end

  def lazy_loading_collapsible(header, loading_url_options, options={})
    raise "html id must be supplied" unless options[:html] && options[:html][:id]
    outer_div_id = options[:html][:id]
    collapsible_style = (options[:style] || {})[:collapsible_style] || 'default'
    content_style = (options[:style] || {})[:collapsible_content_style] || 'collapsible_content_light'
    content_id = "#{outer_div_id}_collapsible_content"
    expand_header_id = "#{outer_div_id}_collapsible_expand_header"
    collapse_header_id = "#{outer_div_id}_collapsible_collapse_header"
    spinner_id = "#{outer_div_id}_collapsible_spinner"

    loader_name = "#{outer_div_id}_loader".camelize(:lower)
    load_complete_callback = "#{loader_name}.loadComplete();"
    loading_function = remote_function(:url => loading_url_options, :update => content_id, :complete => "#{load_complete_callback}")
    loader_declaration = javascript_with_rescue(%{#{loader_name} = new LazyLoadingCollapsible('#{options[:html][:id]}', \"#{loading_function}\");})

    %{
        #{loader_declaration}
        <div class="collapsible-section-#{collapsible_style}" id='#{outer_div_id}'>
          <div class='collapsible-header-#{collapsible_style}'>
            #{render_help_link header}
            #{spinner :id => spinner_id, :class => 'spinner-for-collapsible' }
            <h2>
              <a href='javascript:void(0)' onclick='#{loader_name}.collapse();' id='#{collapse_header_id}' class="section-collapse" style='display:none;'>#{header}</a>
              <a href='javascript:void(0)' onclick='#{loader_name}.expand();' id='#{expand_header_id}' class="section-expand">#{header}</a>
            </h2>
            #{clear_float}
          </div>
          <div class='#{content_style}' id='#{content_id}' style='display:none'></div>
        </div>
    }
  end

  def humanized_count(container, name)
    enumerate(container.send(name.to_sym).size, name)
  end

  def enumerate(amount, unit)
    if amount == 0
      return "no #{unit.pluralize}"
    elsif amount == 1
      return "1 #{unit.singularize}"
    else
      return "#{amount} #{unit.pluralize}"
    end
  end

  def new_value_dropdown_message(property_def)
    if property_def.is_a?(TextPropertyDefinition) || property_def.is_a?(DatePropertyDefinition)
      'Enter value...'
    elsif property_def.calculated?
      'Specify value...'
    else
      'New value...'
    end
  end

  def onchange_for_property_editor(property_definition, onchange, track_property_change_field_id)
    if onchange && track_property_change_field_id
      "$('#{track_property_change_field_id}').value = #{property_definition.name.to_json}; #{onchange};"
    elsif onchange
      "#{onchange};"
    else
      nil
    end
  end

  def tags_widget(tag_field_name, taggable)
    tag_opts = {:tag_field_name => tag_field_name, :project => @project, :taggable => taggable, :sortable => false, :"update_order_url" => ''}
    if taggable.instance_of?(Card)
      tag_opts.merge!({:sortable => true, :"update_order_url" => url_for(:action => 'reorder_tags', :controller => 'cards', :taggable_id => taggable.id)})
    end
    render :partial => 'tags/tags_widget', :locals => tag_opts
  end

  def spinner(options={})
    # Using img tag for performance turnning
    img_class = options[:class] || 'spinner'
    style = options[:style] || 'display:none'
    id = options[:id] || 'spinner'
    "<img src='#{image_path('spinner.gif')}' class='#{img_class}' style='#{style}' id='#{id}'/>".html_safe
  end

  def visible_spinner(options={})
    spinner({:style => ''}.merge(options))
  end

  def enable_links
    "window.docLinkHandler.enableLinks();"
  end

  def disable_links
    "window.docLinkHandler.disableLinks();"
  end

  def show_spinner(elementId=nil)
    elementId ?  "if($('#{elementId}')){$('#{elementId}').show()};" : "var link=this; if($(link.parentNode).down('.spinner')){$(link.parentNode).down('.spinner').show()};"
  end

  def hide_spinner(elementId=nil)
    elementId ? "if($('#{elementId}')){$('#{elementId}').hide()};" : "if(link && $(link.parentNode).down('.spinner')){$(link.parentNode).down('.spinner').hide()};"
  end

  def clear_float
    "<div class='clear-both'><!-- Clear floats --></div>"
  end

  def fix_word_break(str, length=10)
    str.gsub(/[^ ]{#{length}}/, '<wbr>\0</wbr>')
  end

  def prepend_protocol_with_host_and_port(url)
    return url if url =~ /^https?:\/\//
    File.join(MingleConfiguration.secure_prefered_site_url, url)
  end

  def color_block(color, options={})
    width = options.delete(:width) || 4
    content_tag :span, ("&nbsp;"*width).html_safe, options.merge(:class => 'color_block',:style => "background-color:#{color}")
  end

  def dependency_event_originator(dependency_version)
    event = dependency_version.event
    earliest_available_version = event.respond_to?(:earliest_available_version?) ? event.earliest_available_version? : dependency_version.first?
    return h("(#{earliest_available_version ? 'Created' : 'Modified'} by #{event.created_by.name} #{date_time_lapsed_in_words_for_project(dependency_version.updated_at, event.project)})")
  end

  def event_originator(version)
    event_type = version.event_type
    return h("(Copied by #{version.author.name} #{date_time_lapsed_in_words_for_project(version.updated_at, version.project)})") if event_type == :card_copy
    earliest_available_version = version.respond_to?(:earliest_available_version?) ? version.earliest_available_version? : version.first?
    event_type == :card_version ? event_text_for_card_version(earliest_available_version, version) :  event_text(earliest_available_version, version)
  end

  def event_text_for_card_version(earliest_available_version, version)
    if version.event.details != nil
    h("(#{earliest_available_version ? 'Created' : 'Modified' } by #{version.modified_by.name} #{date_time_lapsed_in_words_for_project(version.updated_at, version.project) } via #{version.event.details[:event_source]})") if version.event.details[:event_source] == 'slack'
    else
      event_text(earliest_available_version,version)
    end
  end

  def event_text(earliest_available_version, version)
    h("(#{earliest_available_version ? 'Created' : 'Modified' } by #{version.modified_by.name} #{date_time_lapsed_in_words_for_project(version.updated_at, version.project)})")
  end

  def date_time_lapsed_in_words_for_project(from_time, project=Project.current_or_nil)
    date_format = project.nil? ? nil : project.date_format
    time_zone = project.nil? ? nil : project.time_zone
    date_time_lapsed_in_words(from_time, date_format, time_zone)
  end

  def date_time_lapsed_in_words(from_time, date_format='%d %b %Y', time_zone='UTC')
    date_format = date_format || '%d %b %Y'
    time_zone = time_zone || 'UTC'
    from_time = from_time.in_time_zone(time_zone)
    time = "#{from_time.strftime("%H:%M %Z")}"
    if (Clock.now.in_time_zone(time_zone).yday - from_time.yday) == 0
      return "today at #{time}"
    elsif (Clock.now.in_time_zone(time_zone).yday - from_time.yday) == 1
      return "yesterday at #{time}"
    end
    "on #{from_time.strftime(date_format)} at #{time}"
  end

  def change_description(change)
    if CommentChange === change #because comment change is truncated, see #8645
      h(change.describe)
    else
      replace_card_links(h(change.describe))
    end
  end

  def supports_password_recovery?
    Authenticator.supports_password_recovery?
  end

  def supports_password_change?
    Authenticator.supports_password_change?
  end
  memoize :supports_password_change?

  def supports_login_update?
    Authenticator.supports_login_update? && !ProfileServer.configured?
  end

  def delayed_remote_call(options = {})
    delay = options[:delay] || 2
    "setTimeout(function() {#{remote_function({:method => :get}.merge(options))}}, #{delay * 1000})"
  end

  def delayed_call(options = {})
    delay = options[:delay] || 2
    "setTimeout(function() {#{options[:js]}}, #{delay * 1000})"
  end

  def synchronized_inputs(src_input, dest_input, text_filter=nil, propertyToChange=nil)
    javascript_with_rescue %Q{
      $j(#{src_input.to_json}).inputSynchronizer(#{dest_input.to_json}, #{text_filter || "null"}, #{propertyToChange.to_json});
    }
  end

  def repository_vocabulary
    @project.repository_vocabulary
  end

  def link_to_revisions(html_options = {})
    link_to(repository_vocabulary['revision'].titleize.pluralize, {:controller => 'history', :action => 'index', :filter_types => {:revisions => 'Revision'},
      :page => '1', :period => 'all_history'}, html_options)
  end

  def styled_box(html_options={}, &block)
    inner_html = capture(&block)
    #todo need clean
    inner_html_contents = inner_html.to_s.gsub(/<a[^>]*>help<\/a>/i, '').gsub(/<a[^>]*>show help<\/a>/i, '').gsub(/<div class='clear-both'><\!-- Clear floats --><\/div>/, '').gsub(/<\/?span[^>]*>/, '').gsub(/<img[^>]*class="spinner"[^>]*>/, '')
    return if inner_html_contents.strip.blank?

    concat(content_tag_string(:div, inner_html, html_options))
  end


  def remaining_time_for_mingle_eol
    result = ""
    remaining_months = remaining_days = 0
    today = DateTime.now.utc
    end_date = DateTime.new(2019,7,31).utc
    if end_date.year != today.year
      remaining_months = end_date.month + (12 - today.month)
    else
      remaining_months = end_date.month - today.month
    end
    remaining_days = today.end_of_month.day - today.day
    result  = "#{remaining_months} #{'month'.plural(remaining_months)}" if remaining_months > 0
    result  += "#{ remaining_months > 0 ? " and " : '' }#{remaining_days} #{'day'.plural(remaining_days)}" if remaining_days > 0
    result
  end

  module StyledBox
    def action_bar(html_options={}, &block)
      html_options = {:class => 'action-bar'}.merge(html_options)
      styled_box(html_options, &block)
    end

    def info_box(html_options={}, &block)
      styled_box(html_options.concatenative_merge(:class => 'info-box'), &block)
    end

    def warning_box(html_options={}, &block)
      styled_box(html_options.concatenative_merge(:class => 'warning-box'), &block)
    end

    def error_box(html_options={}, &block)
      styled_box(html_options.concatenative_merge(:class => 'error-box'), &block)
    end

    def success_box(html_options={}, &block)
      styled_box(html_options.concatenative_merge(:class => 'success-box'), &block)
    end
  end
  include StyledBox

  def initial_value_for_drop_list(value, select_options)
    initial_value = if value.class == Array
      value
    else
      select_options.detect{|name_value_pair| !value.nil? && name_value_pair.last.to_s.downcase == value.to_s.downcase }
    end
    if initial_value
      initial_value
    else
      if select_options.empty?
        ['(empty)', '']
      elsif value.blank?
        select_options.first
      else
        [value, value]
      end
    end
  end

  def with_absolute_urls(&proc)
    controller.with_absolute_urls(&proc)
  end

  def defined_and_not_nil?(symbol)
    defined?(symbol) && !symbol.nil?
  end

  def property_definitions_for_filter(card_type_name=nil)
    @project.property_definitions_for_filter(card_type_name)
  end

  def disallow_sign_in?
    sign_in_url = url_for(:controller => 'profile', :action => 'login')
    about_page_url = url_for(:controller => 'about')
    [sign_in_url, about_page_url].include?(request.request_uri)
  end

  def recently_viewed_pages
    view_history = PageViewHistory.new(session[ApplicationController::SESSION_RECENTLY_ACCESSED_PAGES])
    view_history.recent_pages(@project.id)
  end

  def card_color_border_by_type(type, width=6)
    if color = type.color
      raw("style='border-left: solid #{width}px #{color}'")
    end
  end

  def card_color_border_by_card(card, width=6)
    if color = card.card_type.try(:color)
      raw("style='border-left: solid #{width}px #{color}'")
    end
  end

  def cycle_on_index(index, *values)
    values[index%values.size]
  end

  def cycle_on_multiple_indices(index, state, *values)
    state[index] ||= -1
    state[index] += 1
    values[state[index] % values.size]
  end

  def hierarchy_class(level)
    "card_name_level#{level % 6}"
  end

  def link_for_cancel
    params[:cancel_url] || url_for(:action => 'index')
  end

  def tree_relationships_map(options = {})
    html_id_postfix = options[:html_id_postfix]
    html_id_prefix = options[:html_id_prefix]
    restricted_by_card_type = options[:restricted_by_card_type]
    map = {}
    @project.tree_configurations.each do |tree_configuration|
      relationships = restricted_by_card_type ? tree_configuration.relationships_available_to(restricted_by_card_type) : tree_configuration.relationships
      relationships.unshift(TreeBelongingPropertyDefinition.new(tree_configuration)) if options[:include_tree_belongings]
      all_keys_in_tree = relationships.collect { |rel| key_id(html_id_prefix, rel, html_id_postfix) }
      relationships.each_with_index do |relationship, index|
        key = key_id(html_id_prefix, relationship, html_id_postfix)
        map[key] = {:index => index, :otherRelationshipsInTree => all_keys_in_tree - [key],
                    :valueField => value_field(relationship, tree_configuration, html_id_prefix, html_id_postfix)}
      end
    end
    map
  end

  def the_following_will_be_deleted(name, collection, options = {})
    the_following_will_be('deleted', name, collection, options)
  end

  def the_following_will_be_not_set(name, collection, options = {})
    the_following_will_be(PropertyValue::NOT_SET, name, collection, options)
  end

  def the_following_will_be(action, name, collection, options = {})
    "<li>The following #{pluralize(collection.size, name)} will be #{action}: #{h(collection.sorted_bold_sentence)}. #{options[:extra_text]}</li>" if collection.any?
  end

  def tree_name_label(tree_name)
    if tree_name.downcase =~ /tree\z/
      tree_name.bold
    else
      "#{tree_name.bold} tree"
    end
  end

  def cache_to(cacher, *args, &block)
    if CollectionFragmentCache === cacher
      cacher.fragment_for(output_buffer, *args, &block)
    else
      cache(cacher.path_for(*args), &block)
    end
  end

  def cache_to_except_xhr(cacher, *args, &block)
    if request.xhr?
      yield
    else
      cache_to(cacher, *args, &block)
    end
  end

  def header_actions_page_with_user_access
    if @project.mingle_admin_or_member_but_not_readonly?(User.current)
      special_header = @project.header_actions_page.formatted_content_as_snippet(self).html_safe if @project.header_actions_page
      content_tag('div', special_header, :id => 'hd-actions', :class => 'hide-on-maximized') if !special_header.blank?
    end
  end

  def readonly_or_anonymous?
    @project.readonly_member?(User.current) || anonymous?
  end

  def anonymous?
    User.current.anonymous?
  end

  def repository_revision_url(options={})
    send("#{@project.repository_vocabulary['revision']}_url", options)
  end

  def droplist_appended_actions(action_type,
                                context_provider, # prop definition or plv
                                parent_constrains_fields = [])
    card_selector_action(action_type, context_provider, parent_constrains_fields) || user_selector_action(action_type, context_provider)
  end

  def card_selector_action(action_type, card_selector_context_provider, parent_constrains_fields = [])
    card_selector = CardSelector::Factory.create_card_selector(card_selector_context_provider, action_type)
    return unless card_selector
    find_cards_function = remote_function(
      :url => {
        :controller => 'card_explorer',
        :action => 'show_card_selector',
        :project_id => @project.identifier,
        :card_selector => card_selector.attributes
      },
      :with => "ParentConstraintParams.collectFromFields(#{parent_constrains_fields.to_json})",
      :method => :get
    )
    ["new DropList.CallbackAction('select card ...', function(){#{find_cards_function}})"]
  end

  def user_selector_action(action_type, property_definition)
    return unless property_definition.is_a?(UserPropertyDefinition)
    more_count = property_definition.values.size - UserDisplayPreference::MAX_RECENT_USER_COUNT
    return if more_count <= 0
    f = remote_function(
      :url => {
        :controller => 'team',
        :action => 'show_user_selector',
        :project_id => @project.identifier,
        :property_definition_name => property_definition.name,
        :action_type => action_type
      },
      :method => :get
    )
    ["new DropList.CallbackAction('#{more_count} More...', function(){#{f}})"]
  end

  def users_data(users)
    users.map do |user|
      {
        :id => user.id.to_s,
        :login => user.login,
        :name => user.name,
        :icon => @template.user_icon_url(user),
        :color => Color.for(user.name),
      }
    end
  end

  def attributes_hidden_field(attributes_owner)
    namespace = attributes_owner.class.name.underscore
    attributes_owner.attributes.collect{|key, value| hidden_field_tag "#{namespace}[#{key}]", value }.join
  end

  def check_box_to_remote(name, value = "1", checked = false, options = {}, html_options={})
    html_options = (html_options || options.delete(:html)).merge(:accessing => options[:url])
    options = options.merge(:with => "Object.toQueryString({'#{name}': this.checked})")
    check_box_to_function(name, value, checked, remote_function(options), html_options)
  end

  def check_box_to_function(name, value = "1", checked = false, function = "", html_options={})
    html_options[:onclick] = function
    check_box_tag(name, value, checked, html_options)
  end

  def pagination_info(models, model_name)
    return if models.empty?

    current_page = models.current_page
    total_entries = models.total_entries
    end_offset = if current_page != models.total_pages
        current_page * models.per_page
      else
        total_entries
    end
    "Viewing #{models.offset + 1} - #{end_offset} of #{model_name.enumerate(total_entries)}"
  end

  def link_to_cancel(link_params)
    link_to 'Cancel', link_params, :class => 'cancel'
  end

  def safe_post_link_to(name, options = {}, html_options = nil)
    html_options ||= {}
    html_options.delete(:method)
    before_action = html_options.delete(:before)
    before_action = before_action + ";" if before_action.present? && !before_action.end_with?(";")
    onclick_action_js = "#{before_action}var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href; Element.disableLink(this); f.submit();return false;"
    link_to(name, options.merge(request_forgery_protection_token => form_authenticity_token), html_options.merge(:onclick => onclick_action_js))
  end

  def show_macro_editor_function(content_provider)
   %{function(macro_type){ #{remote_function(
         :url => {:controller => 'macro_editor', :action => 'show', :content_provider => MacroEditor::ContentProvider.to_params(content_provider)},
         :method => 'get',
         :with => "Object.toQueryString({'macro_type': macro_type})"
   )}}}
  end

  def image_url(path)
    full_path = image_path(path)
    prepend_protocol_with_host_and_port(full_path)
  end

  def user_icon_url(user = nil)
    image_url(user_icons.url_for(user))
  end

  def show_trial_feedback_form?
    return false if MingleConfiguration.new_buy_process?
    return false if anonymous? || !CurrentLicense.trial?
    return false unless User.current == User.first_admin
    !User.current.trial_feedback_shown?
  end

  def escape_and_format(s)
    MingleFormatting.replace_mingle_formatting(ERB::Util.h(s))
  end

  def refresh_card_popup_color(card, view)
    "if(InputingContexts.top()) { $j(InputingContexts.top().findElement('.lightbox_content')).data('color', '#{card_color(card, view) || card.card_type.color}'); }"
  end

  def refresh_dependency_popup_color(dependency)
    "if(InputingContexts.top()) { $j(InputingContexts.top().findElement('.lightbox_content')).removeClass('accpeted').removeClass('new').removeClass('resolved').addClass('#{dependency.status.downcase}'); }"
  end

  def refresh_transitions_count(card)
    "if(InputingContexts.top()) { $j(InputingContexts.top().findElement('.lightbox_content')).data('transitions-count', #{card.transitions.count}); }"
  end

  def mark_live_event_js(card)
    event = card.find_version(card.version).event
    destination = [event.source_type, event.action_description, card.number.to_s].join("::")
    "MingleUI.events.markAsViewed(#{event.id}, #{destination.to_json})"
  end

  def reload_murmurs_in_popup
    "$j(\"[data-panel-name='murmurs']\").trigger('lightbox-flyout:panel-show');"
  end

  def reload_history_in_popup
    "$j(\"[data-panel-name='history']\").trigger('lightbox-flyout:panel-show');"
  end

  def current_scroll_state
    "if(MingleUI) { MingleUI.scrollPosition = {top : $j(window).scrollTop(), left : $j(window).scrollLeft() }; }"
  end

  protected

  def remote_function_with_return_request(options)
    javascript_options = options_for_ajax(options)

    update = ''
    if options[:update] && options[:update].is_a?(Hash)
      update  = []
      update << "success:'#{options[:update][:success]}'" if options[:update][:success]
      update << "failure:'#{options[:update][:failure]}'" if options[:update][:failure]
      update  = '{' + update.join(',') + '}'
    elsif options[:update]
      update << "'#{options[:update]}'"
    end

    function = update.empty? ?
    "var request = new Ajax.Request(" :
      "var request = new Ajax.Updater(#{update}, "

    url_options = options[:url]
    url_options = url_options.merge(:escape => false) if url_options.is_a?(Hash)
    function << "'#{escape_javascript(url_for(url_options))}'"
    function << ", #{javascript_options})"

    function = "#{options[:before]}; #{function}" if options[:before]
    function = "#{function}; #{options[:after]}"  if options[:after]
    function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
    function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]
    function = "#{function}; return request;"
    return function
  end

  def refresh_partial(partial_name, options={})
    page.replace_html partial_name, options.merge(:partial => partial_name)
  end

  def js_options(ruby_options)
    ruby_options.inject({}) do |options, pair|
      options[pair.first.to_s.camelize(:lower)] = pair.last
      options
    end.to_json.html_safe
  end

  def refresh_flash
    page.replace 'flash', :partial => 'layouts/flash'
  end

  def refresh_tabs
    page['hd-nav'].replace :partial => 'layouts/tabs', :locals => {:include_sidebar_control => true}
  end

  def card_color_border(card, view, width=6)
    color = card_color(card, view)
    raw("style='border-left: solid #{width}px #{color}'") unless color.blank?
  end

  def card_color(card, view)
    card.color(view.color_by_property_definition) if view.color_by
  end

  def user_icons
    @user_icons ||= UserIcons.new(self)
  end

  def image_tag_for_user_icon(user, options = {})
    alt_text = if user.nil?
                 ''
               elsif user.icon.blank?
                 user.login
               else
                 File.basename(user.icon)
               end
    icon_url = user_icon_url(user)

    unless user.nil?
      options[:style] = merge_style(options[:style] || "", user.icon_image_options(icon_url)[:style] || "")
    end
    image_tag(icon_url, {:alt => alt_text}.merge(options))
  end

  def merge_style(*style_attrs)
    style_attrs.join('; ')
  end

  def empty_file_column_field(object, method, options={})
    result = ActionView::Helpers::InstanceTag.new(object.dup, method.to_s+"_temp", self, Null.new).to_input_field_tag("hidden", {})
    result << ActionView::Helpers::InstanceTag.new(object.dup, method, self, Null.new).to_input_field_tag("file", options)
  end

  def card_name_clippy(card)
    clippy("[#{@project.identifier}/##{card.number}] #{card.name}")
  end

  def clippy(text)
    icon = content_tag(:i, "", :class => "fa fa-clipboard")
    content_tag(:button, icon, :"data-clipboard-text" => text, :title => "Copy to clipboard", :class => "view-mode-only")
  end

  def html_line_breaks(to_break)
    to_break.gsub "\n", '<br/>'
  end

  def admin_actions
    admin_actions.collect do |group_name, group_actions|
      if @project.template?
        group_actions
      end
        group_html = group_actions.collect do |name, link|
          controller = link[:controller] || link[:url][:controller]
          action = link[:action] || link[:url][:action]
          style = admin_link_style(controller, action)
          authorized?(link) ? "<li #{style}>#{link[:url] ? link_to_remote(name, link) : link_to(name, link)}</li>" : nil
        end.join("\n")
        %{
          <li class='heading'>#{group_name}</li>
         #{group_html}
        }
    end.join("\n")
  end

  def user_notification_key
    [
      MingleConfiguration.user_notification_heading,
      MingleConfiguration.user_notification_avatar,
      MingleConfiguration.user_notification_body,
      MingleConfiguration.user_notification_url
    ]
  end

  def user_notification?
    # url is optional
    notification_configured = [MingleConfiguration.user_notification_heading, MingleConfiguration.user_notification_body].all? {|el| el.present?}
    notification_configured && !User.current.has_read_notification?(user_notification_key.join(":"))
  end

  def comment_name
    'Murmur'
  end

  def cards_base_url
    url_for(:controller => 'cards', :action => 'popup_show', :number => '0', :color_by => @view.is_a?(CardListView) ? (@view.color_by || 'type') : 'type')
  end

  def background_task_names
    YAML.load(File.read(File.join(MINGLE_CONFIG_DIR, 'periodical_tasks.yml'))).map do |name, task|
      processor = task['command'].split('.')[0]
      [processor, processor]
    end.sort_by do |opt|
      opt[0]
    end
  end

  private

  def key_id(html_id_prefix, relationship, html_id_postfix)
    "#{html_id_prefix}#{relationship.html_id}#{html_id_postfix}"
  end

  def value_field(relationship, tree_configuration, html_id_prefix, html_id_postfix)
    "#{html_id_prefix}#{relationship.html_id}#{html_id_postfix}_field"
  end

  def format_as_discussion_item(string)
    content = html_line_breaks(h(string))
    discussion_item_substitutions.each { |s| content = s.new(:project => @project || Project.current, :view_helper => self).apply(content) }
    # bug 1777
    content = content.gsub(/&#38;/, '%26')
    content = original_auto_link(content, :all, :target => '_blank')
  end

  def discussion_item_substitutions
    [
      Renderable::InlineLinkSubstitution,
      Renderable::AttachmentLinkSubstitution,
      Renderable::WikiLinkSubstitution,
      Renderable::CrossProjectCardSubstitution,
      Renderable::CardSubstitution,
      Renderable::AtUserSubstitution,
      Renderable::DependencySubstitution
    ]
  end

  def favorite_class(favorite)
    "#{favorite.favorited.style}-favorite"
  end

  def property_definition_tooltip(prop_def)
    truncate(prop_def.tooltip, :length => 500)
  end

  def truncate_words(content, length)
    content.split(/ /).map{|word| truncate(word, :length => length)}.join(" ")
  end

  def clean_template_markup_for_cruby
    if RUBY_PLATFORM !~ /java/
      "$('contextual_help').innerHTML = $('contextual_help').innerHTML.gsub(/(%7B%%20[^%]*%20%%7D)|(\\{%[^%]*%\\})/, '');"
    end
  end

  def concatenate_url(url, additional_path)
    additional_path = additional_path.gsub(/^\//, '')
    url.end_with?('/') ? (url + additional_path) : (url + '/' + additional_path)
  end

  def path_to_url(path)
    concatenate_url(root_url(:project_id => nil), path)
  end

  def link_to_with_long_url_handling(name, options = {}, html_options = nil, *parameters_for_method_reference)
    url = url_for(options)
    if url.length > 2083 #url limitation for IE
      html_options ||= {}
      html_options = html_options.merge(:_fhref => url)
    end
    link_to(name, options, html_options, parameters_for_method_reference)
  end

  def short_duration_in_words(seconds)
    minutes, remainder_seconds = seconds / 60, seconds % 60
    [[minutes, 'minutes'], [remainder_seconds, 'seconds']].reject { |magnitude, _| magnitude == 0 }.join(' ')
  end

  def self.html_safe(*method_names)
    method_names.each do |method_name|
      method_name.to_s =~ /(\w+)(\!|\?)*/
      eval <<-METHOD_DEFINITION
      def #{$1}_with_html_safe#{$2}(*args, &block)
        result = self.send("#{$1}_without_html_safe#{$2}", *args, &block)
        result.respond_to?(:html_safe) ? result.html_safe : result
      end
      METHOD_DEFINITION
      alias_method_chain method_name, :html_safe
    end
  end

  self.public_instance_methods.each do |m|
    next if m.to_s == 'display_tabs' || m.to_s == 'content_for_lightbox'
    html_safe(m)
  end

  def authorized_link(label, action, &block)
    yield link_to(label, action) if authorized?(action)
  end
  def admin_task_link(label, action)
    authorized_link(label, action) { |link| content_tag :li, link }
  end

  def landing_page
    enterprise_license = CurrentLicense.status.enterprise? rescue false
    return projects_path if anonymous?
    enterprise_license ? programs_path : projects_path
  end

  def can_show_my_work?(project)
    MingleConfiguration.my_work_menu? && !User.current.anonymous? && !project.ownership_properties.empty?
  end

  def js_mingle_configuration_toggles(*keys)
    toggles = keys.map do |k|
      "#{k.to_s.camelize(:lower)}: #{MingleConfiguration.send(:"#{k}?")}"
    end
    buffer_javascript %Q{
  $j.extend(MingleConfiguration, {
    #{toggles.join(",\n    ")}
  });
}
  end

  def trial_status_message
    CurrentLicense.status.trial_info
  end

  def projects_accepting_dependencies
    project = Project.current
    projects = [ [ project.name, project.id ] ]

    ProgramProject.find(:all, :conditions => { :project_id => project.id }).each do |pp|
      pp.program.program_projects.map do |pp|
        projects << [ pp.project.name, pp.project.id ] if pp.accepts_dependencies
      end
    end

    projects | Project.find(:all, :conditions => { :accepts_dependencies => true }).map { |p| [p.name, p.id] }
  end

  def unique_card_identifier(card)
    "#{@project.identifier}_#{card.number}"
  end

  def copyright_text
    "Copyright 2007-#{Time.now.year} ThoughtWorks, Inc."
  end
end
