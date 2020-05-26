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

module CardsHelper
  include FeedHelper, JsFilterHelper, CardsPlansHelper

  TRANSITION_HTML_ID_PREFIX = 'transition_popup'
  CARD_SHOW_MODE = 'show'
  CARD_EDIT_MODE = 'edit'

  EMPTY_MQL_FILTER_NOTICE_MESSAGE = 'Click here to input MQL'

  SELECT_PROPERTY = "(select property...)"

  def uri_encode_for_js(value)
    URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def sort_position(card, view)
    if view.grid_sort_by && (pd = view.sort_by_property_definition)
      return pd.sort_position(card[pd.column_name])

      view.groups.instance_variable_set("@grid_sort_by", nil)
    end
    formatted_rank(card)
  end

  def formatted_rank(card)
    card.rank.to_s("F")
  end

  def vertical_line
    content_tag 'div', nil, :class => 'vertical-line'
  end

  def transitions_require_popup_array
    js = "transitions_require_comment = new Array();"
    js << @project.transitions.find_all(&:require_comment).map { |transition| "transitions_require_comment.push(#{transition.name.to_json});" }.join
  end

  def transition_popup_field_name(prop_def)
    "user_entered_properties[#{prop_def.field_name}]"
  end

  def require_popup?(transition)
    transition.accepts_user_input?
  end

  def no_transition_on_property_value_error_message(lane)
    content_tag(:div, AutoTransition::View::Errors.no_transition_on_property_value(lane.title), :class => 'flash-content')
  end

  def rank_attribute(project, lane)
    if params = rank_url_params(project, lane)
      raw("rank_url='#{url_for(params)}'")
    end
  end

  def rank_url_params(project, lane)
    { :controller => 'cards', :action => 'set_value_for', :project_id => project.identifier } if @view.group_lanes.grid_sort_by.blank?
  end

  def rank_checkbox
    url_options = @view.to_params.merge(:grid_sort_by => '', :favorite_id => params[:favorite_id], :controller => "cards")
    url_options.delete(:rank_is_on)
    check_box_to_remote 'rank_is_on', !@view.rank_is_on?, @view.rank_is_on?,
    {
      :url => url_options,
      :method => 'get',
      :before => show_spinner('rank_loading_spinner')
    },
    :id => "rank_checkbox"
  end

  def hide_wip_limits_url
    url_options = @view.to_params.merge(:favorite_id => params[:favorite_id], :controller => 'cards')
    url_options.delete(:hide_wip_limits)
    url_options.merge!(:hide_wip_limits => 'true') if !@view.hide_wip_limits?
    url_for(url_options)
  end

  def set_value_for_attribute(project, lane)
    params = set_value_for_url_params(project, lane)
    raw("set_value_for_url='#{url_for(params)}'")
  end

  def set_value_for_url_params(project, lane)
    @view.to_params.merge(:action => 'set_value_for', :value => lane.value, :controller => "cards")
  end


  def links_to_remove_screen_furniture(view)
    link_to('<i class="fa fa-expand"></i> Maximize'.html_safe, view.link_params.merge(:maximized => true, :page => params[:page]), :class => 'maximize-view', :id => 'maximize-view') + link_to_restore_screen_furniture(view)
  end

  def link_to_restore_screen_furniture(view)
    link_to '<i class="fa fa-compress"></i> Restore view'.html_safe, view.to_params.except(:maximized).merge(:controller => 'cards', :action => 'list', :page => params['page']), :class => 'restore-view', :style => 'display: none'
  end

  def link_to_print
    link_to '<i class="fa fa-print"></i> Print'.html_safe, @view.to_params.merge(:action => 'double_print', :controller => 'cards'), {:method => :post, :class => 'print hide-on-maximized'}
  end

  def link_to_this_page
    page_params = @view.params_for_current_page.merge!(:controller => "cards")
    page_params[:favorite_id] = params[:favorite_id] if params[:favorite_id]
    ret = link_to '<i class="fa fa-link"></i> Update URL'.html_safe, page_params, :class => 'link', :id => 'link-to-this-page'
    ret << register_card_list_view_link('link-to-this-page', {})
    ret
  end

  def link_to_current_tab_with_filter_reset(view)
    url_for(view.reset_only_filters_to(@controller.current_tab[:name]).to_params)
  end

  def transition_trigger_link(transition, view, card)
    link_to_remote(h(transition.name),
      {:url => view.to_params.merge(:action => 'set_value_for',
        :selected_auto_transition_id => transition.id,
        :card_number => card.number,
        :rank_is_on => params[:rank_is_on],
        :rerank => params[:rerank]),
        :before => "InputingContexts.pop();"
      },
      {:class => 'transition', :id => "transition_#{transition.id}" })
  end

  def showing_list?
    @all_card_numbers and @all_card_numbers.length > 1
  end

  def last_tab
    @controller.last_tab
  end

  def grid_action_drop_list(drop_down_for, options)
    onchange = options[:onchange] || "$j('##{drop_down_for}_form').submit();"
    drop_options = js_options({
      :html_id_prefix   => "select_#{drop_down_for}",
      :select_options   => options[:select_options],
      :drop_link        => "select_#{drop_down_for}_drop_link",
      :initial_selected => options[:initial_selected],
      :onchange => "window.docLinkHandler.disableLinks();#{onchange}",
      :position => options[:position]
    })

    "new DropList(#{drop_options});".html_safe
  end

  def options_for_group_by(default_select_value, exclude_prop=nil)
    properties = @view.filters.properties_for_group_by
    properties.delete(exclude_prop)
    [[default_select_value, '']] + properties.collect(&grid_option)
  end

  def options_for_group_by_row(exclude_prop=nil)
    options_for_group_by "(select property...)", exclude_prop
  end

  def options_for_group_by_column(exclude_prop=nil)
    options_for_group_by "(select property...)", exclude_prop
  end

  def options_for_grid_sort_by
    [['Rank', '']] + @view.filters.properties_for_grid_sort_by.collect(&grid_option)
  end

  def options_for_color_by
    [[SELECT_PROPERTY, '']] + @view.filters.properties_for_colour_by.collect(&grid_option)
  end

  def grid_option
    lambda {|pd| [pd.name, pd.name.downcase, property_definition_tooltip(pd)] }
  end

  def options_for_aggregate_type
    AggregateType::TYPES.collect { |type| [type.display_name, type.identifier.downcase] }
  end

  def initially_selected_option_for_aggregate_property(property_definition)
    if property_definition
      [property_definition.name, property_definition.name.downcase]
    else
      [SELECT_PROPERTY, '']
    end
  end

  def card_aggregate_properties(card, view)
    aggregate_column_property = view.group_lanes.column_aggregate_by.property_definition
    aggregate_row_property = view.group_lanes.row_aggregate_by.property_definition
    result = {}
    if aggregate_column_property
      result[aggregate_column_property.name] = aggregate_column_property.value(card)
    end
    if aggregate_row_property
      result[aggregate_row_property.name] = aggregate_row_property.value(card)
    end
    view.filters.properties_for_aggregate_by.each do |property_def|
      result["wip.#{property_def.name.downcase}"] =  property_def.value(card)
    end
    result.to_json
  end

  def options_for_aggregate_property(current_view = nil)
    view = current_view || @view
    [[SELECT_PROPERTY, '']] + view.filters.properties_for_aggregate_by.collect(&grid_option)
  end

  def lane_html_options(lane)
    html_options = { :id => "toggle_lane_#{lane.html_id}" }
    html_options.merge!(:class => 'tick') if lane.visible
    html_options
  end

  def style_switch_panel(view)
    view.viewable_styles.inject("") do |result, style|
      if view.style == style
        result << %Q{<span class="selected_view" id="#{style}_view">#{style.to_s.humanize}</span>}
      else
        result << card_list_view_link_to(
              style.to_s.humanize,
              {:controller => 'cards', :action => style.to_s},
              :param_options => { :exclude => ['style'] },
              :title => "Switch to #{style} view",
              :id => "#{style}_view")
      end
      result
    end
  end

  def attach_to_card_history_loader(card)
    loading_function = remote_function(:method => :get, :url => {:controller => 'cards', :action => 'history', :id => card},
      :update => {:success =>'history-container'} ,
      :complete => 'CardHistory.loadComplete();');
    "CardHistory.attach(\"#{loading_function}\");"
  end

  def attach_to_card_discussion_loader(card)
    success_callback = 'var response = request.responseText;'+
        "$('card-murmurs').update(response);" +
        "var printContainer = $('comments-container-for-print');" +
        'printContainer && printContainer.update(response);' +
        'return false;'
    loading_function = remote_function(method: :get, url: {controller: 'cards', action: 'murmurs', number: card.number},
                                       success: success_callback,
                                       complete: 'CardDiscussion.loadComplete();')
    "CardDiscussion.attach(\"#{loading_function}\");"
  end

  def expand_hierarchy_node_function
    toggle_node_function('expand_hierarchy_node')
  end

  def collapse_hierarchy_node_function
    toggle_node_function('collapse_hierarchy_node')
  end

  def toggle_node_function(action)
    options = {:url => @view.to_params.except(:expands).merge(:action => action, :controller => 'cards'),
               :with => "Object.toQueryString({'expands': expandNodes, 'number': number})",
               :before => "$(spinnerId).show()",
               :complete => "$(spinnerId).hide()"}
    "function(expandNodes, number, spinnerId) { #{remote_function_with_return_request(options)} }"
  end

  def expand_tree_node_function
    toggle_node_function('expand_tree_node')
  end

  def collapse_tree_node_function
    toggle_node_function('collapse_tree_node')
  end

  def twisty_class(node)
    node.expanded? ? "expanded" : "collapsed"
  end

  def mql_filter_read_view_message
    mql_filters = @view.mql_filters.to_s
    mql_filters.blank? ? EMPTY_MQL_FILTER_NOTICE_MESSAGE : mql_filters
  end

  def spinner_id_from(node)
     "spinner_#{node.number}"
  end

  def card_types_droplist_options(card_types, drop_link, html_id_prefix = nil)
    js_options(:select_options => card_types.collect{ |card_type| [card_type.name, card_type.id.to_s] }, :drop_link => drop_link, :html_id_prefix => html_id_prefix)
  end

  def show_tree_cards_quick_add_action_url_options(node, tab_name, view_params)
    quick_add_params = if node.root?
      {:action => 'show_tree_cards_quick_add_to_root', :tree => node.tree_config, :tab => tab_name, :tree_style => params[:action]}
    else
      {:action => 'show_tree_cards_quick_add', :tree => node.tree_config, :parent_number => node.number, :tab => tab_name, :tree_style => params[:action]}
    end
    view_params.merge(quick_add_params)
  end

  def show_mode?(mode)
    mode == CardsHelper::CARD_SHOW_MODE
  end

  def show_add_children_link(html_id_prefix, card, tree_configuration, tab_name)
    return '' unless show_mode?(html_id_prefix)
    if card.can_have_children?(tree_configuration)
      link = link_to_remote image_tag('icon-add-child.gif', :alt => 'Add new Card', :size => '14x14', :class => 'card-tree-icon'),
            {
              :url => {:action => 'show_tree_cards_quick_add_on_card_show_page', :tree => tree_configuration, :parent_number => card.number, :tab => tab_name},
              :before => show_spinner("spinner-#{tree_configuration.id}"),
              :complete => hide_spinner("spinner-#{tree_configuration.id}")
            },
            :title => 'Create children for the tree',
            :class => 'add-new-node-button no-popup should-be-hidden-when-print',
            :id => "show-add-children-link-#{tree_configuration.id}"
      spinner_html = spinner(:id => "spinner-#{tree_configuration.id}")
      if link
        "#{link} #{spinner_html}"
      else
        ""
      end
    else
      ''
    end
  end

  def show_go_to_tree_link(html_id_prefix, tree_configuration)
    tree_name_text = tree_name_label(h(truncate(tree_configuration.name, :length => 40)))
    return content_tag(:node, tree_name_text, :title => tree_configuration.name) unless show_mode?(html_id_prefix)
    tree_parameters = {:tree_name => tree_configuration.name}
    link_to(tree_name_text, card_tree_path(tree_parameters), {:title => "View tree: #{tree_configuration.name}", :class => 'go-to-tree-link'})
  end

  def delete_from_tree_link(html_id_prefix, card, tree_configuration, tab_name, view_params)
    allow_remove_from_tree = tree_configuration.include_card?(card) && show_mode?(html_id_prefix)
    if allow_remove_from_tree
      link_to_function(image_tag('icon-remove-14.gif', :alt => 'Remove from tree', :size => '14x14', :class => 'card-tree-remove'),
                               remove_card_from_tree_on_card_view_action(card, tree_configuration, tab_name, view_params),
                               :title => "Remove from tree: #{tree_configuration.name}", :class => 'should-be-hidden-when-print',
                               :class => 'remove_node',
                               :id => "remove_from_tree_#{tree_configuration.id}") + spinner(:id => remove_from_tree_spinner_id(tree_configuration))
    end
  end

  def show_tree_belonging_information_and_actions(html_id_prefix, card, tree_configuration)
    "<div id='#{html_id_prefix}_tree_message_#{tree_configuration.html_id}' class='tree-info' style='display: inline; padding: 1em;'>(#{tree_belonging_message(tree_configuration, card)})</div>".html_safe
  end

  def remove_card_from_tree_on_card_view_action(card, tree_configuration, tab_name, view_params)
    function_options = {:action => 'remove_card_from_tree_on_card_view'}
    spinner_id = remove_from_tree_spinner_id(tree_configuration)
    before_and_complete_actions = {:before => show_spinner(spinner_id), :complete => hide_spinner(spinner_id)}
    remove_sub_tree_action = remove_sub_tree_action(card, tree_configuration, tab_name, view_params, before_and_complete_actions, function_options)
    remove_single_card_from_tree_action = remove_single_card_from_tree_action(card, tree_configuration, tab_name, view_params, before_and_complete_actions, function_options)
    %{RemoveFromTree.removeCardAction($('remove_from_tree_#{tree_configuration.id}'), #{card.has_children?(tree_configuration)}, function() {#{remove_single_card_from_tree_action}}, function(){#{remove_sub_tree_action}})}
  end

  def remove_sub_tree_action(card, tree_configuration, tab_name, view_params, before_and_complete_actions, function_options={})
    remote_function({:url => view_params.merge({:action => :remove_card_from_tree, :tree => tree_configuration.id, :card_id => card.id, :and_children => true, :tab => tab_name}.merge(function_options))}.merge(before_and_complete_actions))
  end

  def remove_single_card_from_tree_action(card, tree_configuration, tab_name, view_params, before_and_complete_actions, function_options={})
    remove_single_card_from_tree_action = remote_function({:url => view_params.merge({:action => :remove_card_from_tree, :tree => tree_configuration.id, :card_id => card.id, :tab => tab_name}.merge(function_options))}.merge(before_and_complete_actions))
  end

  def remove_from_tree_spinner_id(tree_configuration)
    "spinner-remove-from-tree-#{tree_configuration.id}"
  end

  def tree_belonging_message(tree_configuration, card)
    tree_configuration.include_card?(card) ? "This card belongs to this tree." : "This card is available to this tree."
  end

  def within_popups_holder(js)
    "(!#{@view.style.popups_holder} || #{@view.style.popups_holder}.#{js})"
  end

  def execute_transition_js(transition, card)
    require_popup?(transition) ?
      "TransitionExecutor.popup(#{transition.id}, #{card.id}, '#{card.project.identifier}')" :
      "TransitionExecutor.execute(#{transition.id}, #{card.id}, #{card.number}, '#{card.project.identifier}')"
  end

  def substitute_card_name(card)
    card.formatted_name_content(self)
  end

  def popup_description(card)
    card.formatted_content_summary(self, 200) || '(no description)'.italic
  end

  def formatted_card_popup_description(card)
    card.description.blank? ? '(no description)'.italic : card.formatted_content(self)
  end

  def tree_from_url_params
    @view.to_params.merge(:tree_id => @view.workspace.tree_configuration.id).reject{|key, val| key == :tree_name}
  end

  def cache_card_popup_data(card, &block)
    cache_to(Keys::CardPopupData.new, card, &block)
  end

  # TODO remove this method and also the related methods?
  def cache_tree_node(project, tree_config, card_node, &block)
    if card_node.root?
      yield
    else
      cache_to(TreeNodeCache, project, tree_config, card_node, &block)
    end
  end

  def tag_names
    params[:tagged_with] ? Tag.parse(params[:tagged_with]) : @card.tags.collect(&:name)
  end

  def group_by_transition_only_and_no_transition_using?
    group_by_transition_only? && !@project.transitions.any?{|transition| transition.uses_property_definition?(@view.group_lanes.lane_property_definition)}
  end

  def group_by_transition_only?
    @view.group_by_transition_only_property_definition?
  end

  def no_cards_for_project_message(project, options = {})
    link_to_create_first_card = link_to_add_card_with_defaults("Create the first card", :without_href => false, :id => 'create_the_first_card')
    link_to_import_cards      = link_to 'import existing cards', :controller => 'cards_import', :action => 'import'
    "There are no cards for #{h project.name}".tap do |message|
      message << " - #{link_to_create_first_card} now or #{link_to_import_cards}" if authorized?(:controller => 'cards', :action => 'new')
      message << "."
    end
  end

  def v_tree_column_class(root, index)
    is_first = index == 0
    is_last = index == root.children_size - 1
    if(is_first && is_last)
      'single-column'
    elsif(is_first)
      'first-column'
    elsif(is_last)
      'last-column'
    else
      ''
    end
  end

  def tree_belongings_warning(trees)
    "Belongs to #{enumerate(trees.size, 'tree')}: #{trees.bold.to_sentence}. Any child cards will remain in the #{'tree'.plural(trees.size)}.".as_li if trees.any?
  end

  def tree_relationship_usage_warning(usage_count, relationship_properties)
    relationship_usage_warning('tree', usage_count, relationship_properties)
  end

  def card_relationship_usage_warning(usage_count, relationship_properties)
    relationship_usage_warning('card', usage_count, relationship_properties)
  end

  def relationship_usage_warning(relationship_type, usage_count, relationship_properties)
    "Used as a #{relationship_type} relationship property value on #{enumerate(usage_count, 'card').bold}. #{relationship_type.capitalize} relationship #{'property'.plural(relationship_properties.size)}, #{relationship_properties.bold.to_sentence}, will be (not set) for all affected cards.".as_li if usage_count > 0
  end

  def card_type_to_property_definition_id_map
    @project.card_types.inject({}) do |result, card_type|
      result['cp' + card_type.name] = card_type.property_definitions.collect { |prop_def| "edit_" + prop_def.html_id.downcase + "_span" }
      result
    end
  end

  def card_type_options
    @project.card_types.collect { |card_type| [card_type.name, card_type.name]}
  end

  def workspace_link_params(view, tree_name)
    workspaced_params = view.to_workspace_params(tree_name)
    {:action => 'select_tree', :style => workspaced_params[:style], :tab => workspaced_params[:tab], :tree_name => workspaced_params[:tree_name] }
  end

  def show_twisty_for?(node)
    node.has_children? && !node.root?
  end

  def card_list_view_link_to(name, url_options = {}, html_options = nil)
    param_options = html_options.delete(:param_options)

    if ret = link_to(name, url_options, html_options)
      ret << register_card_list_view_link(html_options[:id], param_options || {})
    end
  end

  def register_card_list_view_link(html_id, param_options)
    register_params_aware_widget("new CardListViewLink(#{html_id.to_json}, #{param_options.to_json})")
  end

  def register_card_list_view_form(form_id, options = {})
    register_params_aware_widget "new CardListViewForm('#{form_id}', #{options.to_json})"
  end

  def register_xhr_refreshable_card_list_view_form(form_id, options={})
    widget = "new CardListViewForm('#{form_id}', #{options.to_json})"
    if request.xhr?
      register_xhr_refreshable_params_aware_widget(widget)
    else
      register_params_aware_widget(widget)
    end
  end

  def register_xhr_refreshable_params_aware_widget(widget)
    xhr_refreshable_params_aware_widgets << widget
    return nil # to prevent acident render out the javascript
  end

  def xhr_refreshable_params_aware_widgets
    @xhr_refreshable_params_aware_widgets ||= []
  end

  def register_params_aware_widget(widget)
    javascript_with_rescue "ParamsController.register(#{widget})"
  end

  def update_params_for_js(view)
    js = xhr_refreshable_params_aware_widgets.map do |widget|
      "ParamsController.register(#{widget});"
    end.join
    params = view.to_js_params.merge(view.name.blank? ? {} : {'name' => view.name})
    js << "ParamsController.update(#{params.to_json})"
  end

  def tree_filter_parameters_to_exclude(tree_config)
    tree_config.all_card_types.collect do |card_type|
      "tf_#{card_type.name.downcase}".to_sym
    end
  end

  def refresh_result_partial(view)
    page << current_scroll_state
    page[:card_results].replace_html :partial => view.style.results_partial
  end

  def refresh_no_cards_found
    page.replace 'no_cards_found', :partial => 'cards/no_cards_found'
  end

  def replace_subtree(subtree)
    page.replace "sub_tree_#{subtree.root.html_id}", :partial => 'sub_tree', :locals => {:node => subtree.root}
    page.tree_view.get_tree.replaceSubtree(subtree.root)
  end

  def add_to_root(add_child_action)
    page.tree_view.addToRoot(add_child_action.children_added_in_filter) if add_child_action.has_child_in_filter?
  end

  def comments_and_murmurs_tab_title
    'Murmurs'
  end

  def add_comment_button_name
    'Murmur'
  end

  def comment_added_upon_save
    'murmured upon save'
  end

  def comment_in_params
    params[:comment] && params[:comment][:content]
  end

  def cta_link_enabled?(view)
    view.has_completed_cards?
  end

  def cta_url(view)
    "#{MingleConfiguration.cycle_time_server_url}/#{MingleConfiguration.app_namespace}/projects/#{view.project.identifier}/cta_link?#{cta_params(view).to_query}"
  end

  def cta_params(view, view_helper = self)
    project = view.project
    url_opts = MingleConfiguration.api_url_as_url_options
    feeds_url = project.resource_link.xml_href(view_helper, 'v2', url_opts)

    card_type = view.card_types.first
    card_type_url = card_type.resource_link.xml_href(view_helper, 'v2', url_opts)

    property_definition = view.group_lanes.lane_property_definition
    property_url = property_definition.resource_link.xml_href(view_helper, 'v2', url_opts)
    value_lanes = view.visible_property_value_lanes

    params = {
      :cards_ready => cta_link_enabled?(view),
      :source_uri => feeds_url,
      :process_definition => {
        :card_type_uri => card_type_url,
        :property_uri => property_url,
        :stages => property_definition.values.map(&:value)
      }
    }
    params.merge!(:ignore_weekend_by_tz_offset => project.time_zone_obj.utc_offset * 1000) if project.exclude_weekends_in_cta
    params.merge!(:start_value => value_lanes.first.title,
                  :end_value => value_lanes.last.title) if value_lanes.any?
    params.merge!(:admin => User.current.admin? || User.current.project_admin?)
    params.merge!(:last_completed_in => MingleConfiguration.cycle_time_last_completed_in) if MingleConfiguration.cycle_time_last_completed_in
    params
  end

  def card_number_link(card, options = {})
    project    = options.delete(:project) || Project.current
    link_text  = options.delete(:link_text) || content_tag(:span, "##{card.number}", :id => 'card_number')
    url_params = { :action => 'show', :number => card.number, :project_id => project.identifier }.merge(:only_path => true).merge(options)
    link_to(link_text, url_for(url_params))
  end

  def export_to_excel_link(number_of_cards)
    id = 'show_export_options_link'
    shared_class = 'export-cards'
    if CardViewLimits.allow_export?(number_of_cards)
      link_to_remote('Export cards', {
                       :url => {:controller => 'cards', :action => 'show_export_options'},
                       :with => "Form.serialize('excel_export_view_state_params')"
                     }, {:id => id, :class => "#{shared_class} "})
    else
      tag = content_tag :p, "Export cards", :id => id, :class => "disabled #{shared_class}"
      js = javascript_with_rescue("Tooltip($j('##{id}'), 'Exporting is limited to #{CardViewLimits::MAX_CARDS_TO_EXPORT} cards. Try refining your filter.', {gravity: 'e'})")
      "#{tag}#{js}".html_safe
    end
  end

  def bulk_edit_properties_link(number_of_cards)
    html_opts = {:id => 'bulk-set-properties-button', :class => 'tab-expand', :accessing => ':bulk_set_properties_panel'}
    link_to_function('Edit properties', html_opts)
  end

  def bulk_tagging_link(number_of_cards)
    html_opts = {:id => 'bulk-tag-button', :class => 'tab-expand', :accessing => ':bulk_tagging_panel'}
    link_to_function('Tag', html_opts)
  end

  def tooltip(selector, message, position="autoWE")
    position = position.to_s
    gravity = %w(autoNS autoWE).include?(position) ? "jQuery.fn.tipsy.#{position}" : position.inspect

    javascript_tag(%Q[
      Tooltip($j(#{selector.inspect}), #{message.inspect}, {fade: true, gravity: #{gravity}});
    ])
  end

  def can_reorder_lane?(lane)
    lane.can_reorder? && authorized?(:controller => :cards, :action => 'reorder_lanes')
  end

  def can_edit_header?(axis = nil)
    return axis.can_reorder? && authorized?(:controller => :property_definitions, :action => 'edit') unless axis.nil?
    authorized?(:controller => :property_definitions, :action => 'edit')
  end

  def can_add_lane?(view)
    view.groups.supports_direct_manipulation?(:lane) && view.groups.visibles(:lane).any?
  end

  def can_hide_any?(view)
    view.groups.visibles(:all).any?(&:can_hide?)
  end

  def authorized_to_delete_attachments
    authorized_for?(@project, :controller => 'cards', :action => 'remove_attachment')
  end

  def create_card_div_collection_cache(view, users_key, dependencies_key)
    collection = view.cards.map { |c| [c, view, users_key, dependencies_key] }
    CollectionFragmentCache.new(Keys::CardDivCache.new, collection, @controller.cache_store)
  end

  def character_limit_for_popup_properties
    90
  end
end
