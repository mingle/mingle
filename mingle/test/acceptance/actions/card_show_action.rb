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

module TransitionActionsForCard
  def click_on_complete_transition(options = {:ajaxwait => true})
    assert_enabled(CardShowPageId::COMPLETE_TRANSITION_BUTTON)
    begin
      if options[:ajaxwait]
        @browser.with_ajax_wait do
            @browser.click(CardShowPageId::COMPLETE_TRANSITION_BUTTON)
          end
        else
          @browser.click_and_wait(CardShowPageId::COMPLETE_TRANSITION_BUTTON)
        end
      end while @browser.is_element_present "transition_popup_div"
  end

  def set_value_to_property_in_lightbox_editor_on_transition_execute(properties)
    properties.each do |property, value|
      add_value_to_property_lightbox_editor('', property, value)
    end
  end

  def add_value_to_property_lightbox_editor(context, property, value)
    @browser.click lightbox_droplist_link_id(property, context)
    @browser.click droplist_lightbox_option_id(property, value)
  end

  def add_value_to_free_text_property_lightbox_editor(context, property, value)
    @browser.wait_for_element_present "css=#transition_popup_div"
    @browser.click editlist_lightbox_link_id(property, context)
    @browser.type editlist_lightbox_editor_id(property, context), value
    submit_property_inline(editlist_lightbox_editor_id(property, context),true)
  end

  def set_property_in_complete_transition_lightbox(project, *properties)
    set_sets_properties(project, *properties)
  end

  def add_comment_for_transition_to_complete_and_complete_the_transaction(value, options={:ajaxwait => true})
    @browser.type(CardShowPageId::TRANSITION_POPUP_COMMENT_BOX, value)
    @browser.key_up(CardShowPageId::TRANSITION_POPUP_COMMENT_BOX, value[value.size - 1].to_s)
    click_on_complete_transition(options)
  end

  def add_comment_for_transition_to_complete_text_area(value)
    @browser.type(CardShowPageId::TRANSITION_POPUP_COMMENT_BOX, value)
    @browser.key_up(CardShowPageId::TRANSITION_POPUP_COMMENT_BOX, value[value.size - 1].to_s)
  end

  def add_value_to_property_via_inline_editor_in_lightbox_editor_on_transition_complete(properties)
    properties.each do |property, value|
      if property.is_a?(String)
        property = Project.current.find_property_definition(property, :with_hidden => true)
      end
      add_value_to_property_on_transtion(property, value, 'sets', ajaxy = false)
    end
  end

  def add_value_to_free_text_property_lightbox_editor_on_transition_complete(properties)
    properties.each do |property, value|
      add_value_to_free_text_property_lightbox_editor('', property, value)
    end
  end

  def add_value_to_date_property_lightbox_editor_on_transition_complete(properties)
    add_value_to_property_via_inline_editor_in_lightbox_editor_on_transition_complete(properties)
  end

  def add_value_to_property_on_transtion(property, value, context, ajaxy = false)
    @browser.click transition_popup_property_drop_link_id(property,context)
    @browser.click transition_popup_property_add_value_id(property,context)
    @browser.type transition_popup_property_inline_editor_id(property,context), value
    # if ajaxy
    #      @browser.with_ajax_wait do
    #        @browser.press_enter transition_popup_property_inline_editor_id(property,context)
    #      end
    #    else
    #      @browser.press_enter transition_popup_property_inline_editor_id(property,context)
    #    end
    submit_property_inline(transition_popup_property_inline_editor_id(property,context),ajaxy)
  end

  def add_value_to_any_text_numeric_or_date_property_on_transtion(property, value, context, ajaxy = false)
    @browser.click transition_popup_anytext_or_number_or_date_property_drop_link_id(property,context)
    if value == '(not set)'
      @browser.with_ajax_wait do
        @browser.click transition_popup_anytext_or_number_or_date_property_option_notset_id(property,context)
      end
    else
      @browser.click transition_popup_anytext_or_number_or_date_property_add_value_id(property,context)
      @browser.type transition_popup_anytext_or_number_or_date_property_inline_editor_id(property,context), value
      submit_property_inline(transition_popup_anytext_or_number_or_date_property_inline_editor_id(property,context),ajaxy)
      # if ajaxy
      #         @browser.with_ajax_wait do
      #           @browser.press_enter transition_popup_anytext_or_number_or_date_property_inline_editor_id(property,context)
      #         end
      #       else
      #         @browser.press_enter transition_popup_anytext_or_number_or_date_property_inline_editor_id(property,context)
      #       end
    end

  end

  def open_card_selector_for_property_on_transition_popup(property)
    @browser.click(transition_popup_tree_relationship_sets_drop_link_id(property))
    @browser.click(transition_popup_tree_relationship_dropdown_value_id(property))
    @browser.wait_for_all_ajax_finished
  end

  def click_cancel_on_transiton_light_box_window
    @browser.click transition_cancel_link_id
  end

  def click_property_droplist_link_in_transition_lightbox(property_name)
    @browser.click lightbox_droplist_link_id(property_name, '')
  end

  def select_value_in_drop_down_for_property_in_transition_lightbox(property,value)
    @browser.click(droplist_lightbox_option_id(property,value))
  end

  def type_keyword_to_search_value_for_property_in_transition_lightbox(property, keyword)
    @browser.type_in_property_search_filter(transition_popup_dropdown_filter_id(property), keyword)
  end

  def check_on_murmur_this_transtion
    unless @browser.is_checked(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
      @browser.click(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
    end
  end

  def uncheck_murmur_this_transtion
    if @browser.is_checked(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
      @browser.click(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
    end
  end
end



module CardShowAction
  include TransitionActionsForCard

  def open_card_by_name(project, card_name)
    project = project.identifier if project.respond_to? :identifier
    card = Project.find_by_identifier(project).cards.find_by_name(card_name) unless card.respond_to?(:name)
    open_card(project, card)
  end

  def create_card(options ={})
    @card = create_card!({ :name => 'linc card' }.merge(options))
  end

  def update_card(options = {})
    options = options.inject({}) do |result, pair|
      result["cp_#{pair.first.to_s.underscore}".to_sym] = pair.last
      result
    end
    @card.update_attributes(options)
  end

  def navigate_to_card(project, card, tab="All")
    project = Project.find_by_identifier(project) unless project.respond_to?(:cards)
    project.activate
    card = project.cards.find_by_name(card) unless card.respond_to?(:number)
    @browser.open "/projects/#{project.identifier}/cards/#{card.number}?tab=#{tab}"
    @browser.wait_for_all_ajax_finished
  end

  def open_card(project, card)
    project = project.identifier if project.respond_to? :identifier
    card = card.number if card.respond_to? :number
    @browser.open "/projects/#{project}/cards/#{card}"
    @browser.wait_for_all_ajax_finished
  end

  def click_edit_link_on_card
      @browser.wait_for_element_visible CardShowPageId::EDIT_LINK_ID
      @browser.click_and_wait(CardShowPageId::EDIT_LINK_ID)
      wait_for_wysiwyg_editor_ready
      @browser.wait_for_element_visible "css=.cke_toolbox"
  end

  def add_new_value_to_property_on_card_show(project, property, value)
    add_new_value_to_property_on_card(project, property, value, 'show')
  end

  def set_card_type_on_card_show(card_type, options={})
    @browser.click(card_type_editor_id("show"))
    @browser.click(card_type_option_id(card_type, "show"))
    stop_at_confirmation = options[:stop_at_confirmation]
    if stop_at_confirmation != true
      @browser.with_ajax_wait do
        @browser.click(CardShowPageId::CONTINUE_BUTTON)
      end
    end
  end

  def set_properties_on_card_show(properties)
    properties.each do |name, value|
      @browser.assert_visible droplist_link_id(name, 'show')
      @browser.click droplist_link_id(name, 'show')
      value = NULL_VALUE if value.nil?
      @browser.with_ajax_wait do
        # todo #14979: spaces in id attributes are illegal pre-HTML-5, should refactor
        # set explicit css attribute locator type since option ids may have spaces
        @browser.click "id=#{droplist_option_id(name, value, "show")}"
      end
    end
  end

  def open_card_selector_for_property_on_card_show(property)
    open_card_selector_for_property(property, "show")
  end


  def set_property_value_on_card_show(project, property, value)
    type = project.all_property_definitions.find_by_name(property).type
    if type == CardShowPageId::CARD_RELATIONSHIP_PROPERTY_DEF_ID
      set_relationship_properties_on_card_show(:"#{property}" => value)
    elsif type == CardShowPageId::USER_PROPERTY_DEF_ID
      set_properties_on_card_show(:"#{property}" => value)
    else
      add_new_value_to_property_on_card_show(project, property, value)
    end
  end

  def click_card_delete_link
    @browser.click(card_delete_link_id)
    @browser.wait_for_element_visible(CardShowPageId::CONFIRM_DELETE_ID)
  end

  def add_new_value_to_property_on_card(project, property, value, context=nil, options={})
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    project.reload.with_active_project do |active_project|
      property = active_project.reload.find_property_definition(property, :with_hidden => true)
      property_type = property.attributes['type']
      if (options[:plv_exists] || property_type == 'EnumeratedPropertyDefinition' || property_type == 'DatePropertyDefinition')
        add_value_to_property_using_inline_editor(context, property, value, true)
      elsif (property_type == 'TextPropertyDefinition')
        add_value_to_date_or_free_text_property_using_inline_editor(context, property, value, true)
      else
        raise "Property type #{property_type} is not supported"
      end
    end
  end

  # Tree related helper on Card show/edit
  def set_relationship_properties_on_card_show(properties)
    set_relationship_properties("show", properties)
  end

  def click_property_on_card_show(property)
    click_on_card_property(property, "show")
  end

  def click_history_tab_on_card
    @browser.with_ajax_wait do
      @browser.click CardShowPageId::HISTORY_LINK_ID_ON_CARD
    end
  end

  def click_history_version_link_for(options)
    @browser.click(history_version_link_id(options))
    @browser.ruby_wait_for("card version page to load") do
      (@browser.get_location =~ /#{options[:card_number]}\?version=#{options[:version_number]}/) &&
      @browser.get_eval("selenium.browserbot.getCurrentWindow().document.readyState === 'complete'") == "true"
    end
  end

  def select_value_in_drop_down_for_property_on_card_show(property,value)
    @browser.with_ajax_wait do
      @browser.click(droplist_option_id(property,value,'show'))
    end
  end

  def type_keyword_to_search_value_for_property_on_card_show(property, keyword)
    @browser.type_in_property_search_filter(show_property_drop_down_search_text_field_id(property), keyword)
  end

  def delete_card(project, card)
    project = project.identifier if project.respond_to? :identifier
    card = Project.find_by_identifier(project).cards.find_by_name(card) unless card.respond_to?(:name)
    navigate_to_card_list_for(project)
    click_card_on_list card
    click_card_delete_link
    click_continue_to_delete_on_confirmation_popup
  end

  def delete_card_from_card_show
    assert_delete_link_present
    click_card_delete_link
    click_continue_to_delete_on_confirmation_popup
  end

  def type_comment_in_show_mode(comment)
    @browser.type CardShowPageId::CARD_COMMENT_BOX_ID, comment
  end

  def click_next_card_on_card_context
    @browser.click_and_wait(CardShowPageId::NEXT_LINK_ID)
  end

  def click_add_with_detail_button
    @browser.click_and_wait CardShowPageId::ADD_WITH_MORE_DETAILS_BUTTON_ID
    wait_for_wysiwyg_editor_ready
  end

  def add_comment(comment)
    @browser.click CardShowPageId::CARD_DISCUSSION_LINK
    @browser.wait_for_element_visible CardShowPageId::CARD_COMMENT_BOX_ID
    @browser.type CardShowPageId::CARD_COMMENT_BOX_ID, comment
    @browser.with_ajax_wait do
      @browser.click CardShowPageId::ADD_COMMENT_BUTTON_ID
    end
  end

  def uncheck_the_show_murmur_checkbox_on_this_card
    if(@browser.get_eval("this.browserbot.getCurrentWindow().$('show-murmurs-preference').checked") == 'true')
      @browser.click(CardShowPageId::SHOW_MURMUR_PREF_CHECKBOX_ID)
      @browser.wait_for_all_ajax_finished
    end
  end

  def check_on_the_show_murmur_checkbox_on_this_card
    if(@browser.get_eval("this.browserbot.getCurrentWindow().$('show-murmurs-preference').checked") == 'false')
      @browser.click(CardShowPageId::SHOW_MURMUR_PREF_CHECKBOX_ID)
      @browser.wait_for_all_ajax_finished
    end
  end

  def on_card_show_add_a_comment_that_is_also_a_murmur(comment)
    type_comment_in_show_mode(comment)
    on_card_show_check_on_murmur_this_comment
    @browser.with_ajax_wait do
      @browser.click CardShowPageId::ADD_COMMENT_BUTTON_ID
    end
  end

  def on_card_show_check_on_murmur_this_comment
    unless @browser.is_checked(CardShowPageId::MURMUR_THIS_CARD_CHECKBOX_ID)
      @browser.click CardShowPageId::MURMUR_THIS_CARD_CHECKBOX_ID
    end
  end

  def on_card_show_uncheck_murmur_this_comment
    if @browser.is_checked(CardShowPageId::MURMUR_THIS_CARD_CHECKBOX_ID)
      @browser.click CardShowPageId::MURMUR_THIS_CARD_CHECKBOX_ID
    end
  end

  def post_one_comment_and_murmur_it_on_card(card_number, comment)
    open_card(@project, card_number)
    on_card_show_add_a_comment_that_is_also_a_murmur(comment)
  end

  def click_transition_link_on_card(transition)
    @browser.with_ajax_wait do
      @browser.click(transition_link_id(transition))
    end
  end

  def click_transition_link_on_card_with_input_required(transition)
    @browser.with_ajax_wait do
      @browser.click(transition_link_id(transition))
    end
  end

  def confirm_card_type_change
    @browser.click_and_wait CardShowPageId::CONTINUE_BUTTON
  end

  def load_card_history
    @browser.run_once_history_generation
    if @browser.is_element_present(CardShowPageId::HISTORY_LINK_ID_ON_CARD) && (@browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('history-container').loaded") == 'null')
      @browser.with_ajax_wait do
        @browser.click(CardShowPageId::HISTORY_LINK_ID_ON_CARD)
      end
    else
      @browser.wait_for_all_ajax_finished
    end
    if @browser.is_element_present(CardShowPageId::REFRESH_LINK_ID_ON_CARD)
      @browser.with_ajax_wait do
        @browser.click(CardShowPageId::REFRESH_LINK_ID_ON_CARD)
      end
    end
  end

  def click_on_create_children_for(tree)
    @browser.with_ajax_wait do
      @browser.click(show_add_children_link(tree))
    end
    @browser.wait_for_element_visible(CardShowPageId::TREE_CARDS_QUICK_ADD_ID)
  end

  def click_remove_from_tree_and_wait_for_card_to_be_removed(tree)
    @browser.with_ajax_wait do
      click_remove_from_tree(tree)
    end
  end

  def click_remove_from_tree(tree)
    @browser.click(remove_from_tree_id(tree))
  end

  # search from card selection widget
  def search_through_card_selection_widget(search_string)
    @browser.click(CardShowPageId::SEARCH_LINK_ON_CARD)
    @browser.type(CardShowPageId::SEARCH_CARD_TEXT_BOX, search_string)
    @browser.with_ajax_wait do
      @browser.click(CardShowPageId::CARD_SELECTOR_SEARCH_COMMIT_BUTTON)
    end
  end

  #filter cards from card selection widget
  def filter_cards_through_card_selection_widget_by_card_type_name(card_type_name)
    @browser.with_ajax_wait do
      @browser.click(CardShowPageId::CARD_EXPLORER_FILTER_FIRST_CARD_TYPE_VALUE_DROP_LINK)
      @browser.click(card_explorer_filter_first_value_option_id(card_type_name))
    end
  end

  # Open card selection widget for one card property from a card show page
  def open_card_selection_widget_for_property_from_card_show_page(property_name)
    @browser.click droplist_link_id(property_name, 'show')
    @browser.with_ajax_wait do
      @browser.click droplist_select_card_action(droplist_dropdown_id(property_name, 'show'))
    end
  end

  def ensure_hidden_properties_visible
    unless @browser.is_checked(CardShowPageId::TOGGLE_HIDDEN_PROPERTIES_CHECKBOX)
      @browser.with_ajax_wait do
        @browser.click(CardShowPageId::TOGGLE_HIDDEN_PROPERTIES_CHECKBOX)
      end
    end
  end

  def cancel_to_change_card_type
    @browser.click_and_wait(CardShowPageId::CANCEL_BUTTON)
  end

  def continue_to_change_card_type
    @browser.with_ajax_wait do
      @browser.click(CardShowPageId::CONTINUE_BUTTON)
    end
  end

  def click_card_navigation_icon_for_readonly_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.click_and_wait card_navigation_icon_for_readonly_property_id(id)

  end

  def click_card_navigation_icon_for_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.click_and_wait card_navigation_icon_for_property_id(id)
  end

  def copy_card_to_project(project)
    click_copy_to_link
    click_select_project_link
    @browser.click(select_project_option_to_clone_card_id(project))
    with_ajax_wait { @browser.click(CardShowPageId::CONTINUE_TO_COPY_ID) }
    click_link_with_ajax_wait(CardShowPageId::CONFIRM_CONTINUE_TO_COPY_ID)
  end


  def click_continue_to_copy_link
    @browser.with_ajax_wait { @browser.click(CardShowPageId::CONFIRM_CONTINUE_TO_COPY_ID)}
  end

  def cancel_copying
    @browser.click CardShowPageId::CANCEL_COPY
  end

  def choose_a_project_and_continue_to_copy_card(project)
    click_copy_to_link
    choose_a_project_and_continue_to_see_warning_message(project)
  end

  def choose_a_project_and_continue_to_see_warning_message(project)
    @browser.with_ajax_wait { @browser.click(CardShowPageId::SELECT_PROJECT_ON_CLONE_CARD_DROP_LINK)}
    @browser.with_ajax_wait { @browser.click(select_project_option_to_clone_card_id(project))}
    @browser.with_ajax_wait { @browser.click(CardShowPageId::CONTINUE_TO_COPY_ID)}
  end


  def copy_card_to_project(project)
    choose_a_project_and_continue_to_copy_card(project)
    click_continue_to_copy_link
  end

  def click_copy_to_link
    @browser.with_ajax_wait { @browser.click(CardShowPageId::CLONE_CARD_LINK)}
  end

  def click_select_project_link
    @browser.with_ajax_wait { @browser.click(CardShowPageId::SELECT_PROJECT_ON_CLONE_CARD_DROP_LINK)}
  end

  def click_comment_tab_on_card
    @browser.with_ajax_wait do
      @browser.click CardEditPageId::COMMENT_TAB_ID
    end
  end

  def click_previous_link
    @browser.click_and_wait(CardShowPageId::PREVIOUS_LINK_ID)
  end

  def click_next_link
    @browser.click_and_wait(CardShowPageId::NEXT_LINK_ID)
  end

  def open_card_version(project, card_number, version_number)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/cards/#{card_number}?version=#{version_number}"
  end

  def add_value_to_property_using_inline_editor(context, property, value, ajaxy = true)
    if context == 'defaults' || context == 'bulk'
      @browser.click droplist_link_id(property, context)
    else
      @browser.click property_value_widget(property)
    end
    @browser.click droplist_add_value_action_id(property, context)
    editor = droplist_inline_editor_id(property, context)
    @browser.type editor, value
    submit_property_inline(editor, ajaxy)
  end

  def add_value_to_date_or_free_text_property_using_inline_editor(context, property, value, ajaxy = true)
    if context == 'defaults' || context == 'bulk'
      @browser.click editlist_link_id(property, context)
      editor = editlist_inline_editor_id(property, context, 'editor')
    else
      @browser.click property_value_widget(property)
      editor = editlist_inline_editor_id(property, context)
    end
    @browser.type editor, value
    submit_property_inline(editor,ajaxy)
  end

  def submit_property_inline(editor, ajaxy)
    if ajaxy
      @browser.with_ajax_wait do
        press_enter_using_js(editor)
      end
    else
      press_enter_using_js(editor)
    end
  end

  def press_enter_using_js(element)
    js = <<-JAVASCRIPT
      var $j = selenium.browserbot.getCurrentWindow().$j;
      var e = $j.Event('keypress');
      e.which = e.keyCode = 13;
      $j('##{element}').trigger(e);
    JAVASCRIPT
    @browser.get_eval js
  end

  def trigger_submit(form_selector)
    js = <<-JAVASCRIPT
    var $j = selenium.browserbot.getCurrentWindow().$j;
    $j(#{form_selector.inspect}).submit();
    JAVASCRIPT
    @browser.get_eval js
  end

  def submit_form(element)
    js = <<-JAVASCRIPT
    var $j = selenium.browserbot.getCurrentWindow().$j;
    $j('##{element} form').submit()
    JAVASCRIPT
    @browser.get_eval js
  end

  def add_value_to_date_or_free_text_property_using_droplist_inline_editor(context, property, value, ajaxy = true)
    @browser.click droplist_link_id(property, context)
    @browser.click droplist_add_value_action_id(property, context)
    @browser.type droplist_inline_editor_id(property, context), value
    editor = droplist_inline_editor_id(property, context)
    submit_property_inline(editor,ajaxy)
  end

  def need_popup_card_selector?(property_type, value)
    %w(TreeRelationshipPropertyDefinition CardRelationshipPropertyDefinition).include?(property_type) && !is_a_special?(value)
  end

  def waitForAggregateValuesToBeComputed(project, property,card)
    while(@browser.is_element_present(stale_aggregate_prop_id(property,"show")))
      open_card(project,card)
    end
  end

  def wait_for_element_notice
    @browser.wait_for_element_present('notice')
  end

  def wait_for_element_info
    @browser.wait_for_element_present('info')
  end


end
