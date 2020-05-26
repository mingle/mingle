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

module SharedAssertions

  def assert_card_present(card)
    @browser.assert_text_present(card_model?(card) ? card.name : card[:name])
  end

  def card_model?(card)
    card.respond_to?(:name)
  end

  def assert_cards_present(*cards)
    cards.each do |card|
      assert_card_present(card)
    end
  end

  def assert_cards_not_present(*cards)
    cards.each do |card|
      @browser.assert_text_not_present(card.respond_to?(:name) ? card.name : card[:name])
    end
  end

  def should_see_link(*linked_texts)
    linked_texts.each do |linked_text|
      @browser.assert_element_present("link=#{linked_text}")
    end
  end

  def should_not_see_link(*linked_texts)
    linked_texts.each do |linked_text|
      @browser.assert_element_not_present("link=#{linked_text}")
    end
  end

  def should_see_link_in_renderable_content(*linked_texts)
    linked_texts.each do |text|
      locator = "//div[@id='card-description']//a[contains(string(),'#{text}')]"
      @browser.assert_element_present(locator)
    end
  end

  def should_not_see_link_in_renderable_content(*linked_texts)
    linked_texts.each do |text|
      locator = "//div[@id='card-description']//a[contains(string(),'#{text}')]"
      @browser.assert_element_not_present("link=#{text}")
    end
  end

  def assert_no_cards_matching_filter
    @browser.assert_text_present "There are no cards that match the current filter"
  end

  def assert_location_url(expected_url)
    @browser.assert_location(expected_url)
  end

  def assert_link_to_card_not_present(project, card_number)
    project = project.identifier if project.respond_to? :identifier
    assert_link_not_present "/projects/#{project}/cards/#{card_number}"
  end

  def assert_link_to_card_present(project, card_number)
    project = project.identifier if project.respond_to? :identifier
    assert_link_present "/projects/#{project}/cards/#{card_number}"
  end

  def assert_link_present(href)
    assert all_unique_hrefs.any?{|link| link.ends_with?(href) }, "there is no link on the page has address '#{href}'"
  end

  def assert_link_not_present(href)
    assert all_unique_hrefs.all?{|link| !link.ends_with?(href) }, "there is a link on the page has address '#{href}', which is not expected"
  end

  def assert_link_not_present_and_cannot_access_via_browser(url)
    assert_link_not_present(url)
    assert_cannot_access_via_browser(url)
  end

  def assert_cannot_access_via_browser(url)
    @browser.open(url)
    assert_cannot_access_resource_error_message_present
  end

  def at(location, things_to_find = {})
    @browser.assert_location location
    if things_to_find.key?(:find_error)
      @browser.assert_element_present SharedFeatureHelperPageId::ERROR
      @browser.assert_text_present things_to_find[:find_error]
      return
    end
    if things_to_find.key?(:find_notice)
      @browser.assert_element_present SharedFeatureHelperPageId::NOTICE
      @browser.assert_text_present things_to_find[:find_notice]
      return
    end

    raise SeleniumCommandError.new("Expected #{things_to_find.keys.join(', ')} does not find.")
  end



  def assert_element_has_css_class(element_id, class_name)
      css_class_name = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('#{element_id}').className")
      assert(css_class_name.split.include?(class_name))
  end



  def assert_element_doesnt_have_css_class(element_id, class_name)
    css_class_name = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('#{element_id}').className")
    assert(!css_class_name.split.include?(class_name))
  end

  def assert_ordered(*elements)
    elements.each_with_index do |element, index|
      @browser.assert_ordered(element, elements[index + 1]) unless element == elements.last
    end
  end

  def assert_enabled(element_id)
    assert_equal("false", @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('#{element_id}').disabled"))
  end

  def assert_disabled(element_id)
    assert_equal("true", @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('#{element_id}').disabled"))
  end

  def assert_up_link_text(text)
    @browser.assert_text(SharedFeatureHelperPageId::UP_LINK_HOVER_TEXT, text)
  end

  def assert_view_navigation_link_present(project, options={})
    option = options[:view] || 'list'
    assert_link_present("/projects/#{project.identifier}/cards/#{option}?tab=All")
  end

  def assert_link_to_this_page_link_present
    @browser.assert_element_present(class_locator('link', 0))
  end

  def assert_view_as_links_present_for(project, tree, options={})
    option = options[:view] || 'Hierarchy'
    # assert_link_present("/projects/#{project.identifier}/cards/#{option}?tree_name=#{CGI.escape(tree.name)}&tab=All")
    @browser.assert_element_present("#{option.downcase}_view")
  end

  def assert_html_link(target_html, locator)
     href = @browser.get_attribute("#{locator}@href")
     assert_equal(href.split("/").last, "#{target_html}")
  end

  def assert_text_present(text)
    @browser.assert_text_present(text)
  end

  def assert_raw_text_present(locator, text)
    @browser.assert_raw_text_present(locator, text)
  end

  def assert_text_not_present(text)
    @browser.assert_text_not_present(text)
  end

  def assert_not_visible(locator)
    @browser.assert_not_visible(locator)
  end

  def assert_comment_author_present(author_info)
    @browser.assert_text_present_in(class_locator(SharedFeatureHelperPageId::COMMENT_CREATED_BY), author_info)
  end

  def assert_comment_created_at(how_long_time_ago)
    @browser.assert_text_present_in(class_locator(SharedFeatureHelperPageId::COMMENT_CONTEXT), how_long_time_ago)
  end

  def assert_element_present(locator)
    assert @browser.is_element_present(locator)
  end

  def assert_element_not_present(locator)
    assert !@browser.is_element_present(locator)
  end

  def assert_current_url(url)
    @browser.assert_location(url)
  end

  def assert_comment_present(comment)
    @browser.assert_element_matches SharedFeatureHelperPageId::DISCUSSION_CONTAINER, /#{comment}/
  end

  def assert_comment_not_present(comment)
    @browser.assert_element_does_not_match SharedFeatureHelperPageId::DISCUSSION_CONTAINER, /#{comment}/
  end

  def assert_link_disabled(locator_string)
    @browser.assert_has_classname(css_locator(locator_string), 'disabled')
  end

  def assert_error_message(message, options = {})
    @browser.wait_for_element_present(SharedFeatureHelperPageId::ERROR)
    message = Regexp.escape(message) if options[:escape]
    if options[:ignore_space]
      @browser.assert_element_matches_ignore_space SharedFeatureHelperPageId::ERROR, message
    else
      @browser.assert_element_matches(SharedFeatureHelperPageId::ERROR, /#{message}/m, options)
    end
  end

  def assert_error_message_without_html_content(message)
    actual_message = get_error_message_without_html_content
    assert_equal_ignoring_spaces_and_return(message, actual_message)
  end

  def assert_error_message_without_html_content_includes(content)
    actual_message = get_error_message_without_html_content
    assert_include_ignoring_spaces(content, actual_message)
  end

  def get_error_message_without_html_content
    @browser.wait_for_element_present(SharedFeatureHelperPageId::ERROR)
    @browser.get_eval("this.browserbot.getCurrentWindow().$('error').innerHTML.unescapeHTML()")
  end

  def assert_error_message_does_not_contain(message)
    @browser.assert_element_does_not_match SharedFeatureHelperPageId::ERROR, /#{message}/
  end

  def assert_transition_only_tool_tip_present
    @browser.assert_element_present(SharedFeatureHelperPageId::TRANSITION_ONLY_TOOLTIP)
  end

  def assert_error_message_not_present
    @browser.assert_element_not_present(SharedFeatureHelperPageId::ERROR)
  end

  def assert_notice_message(message, options = {})
    message = Regexp.escape(message) if options[:escape]
    @browser.assert_element_matches SharedFeatureHelperPageId::FLASH, /#{message}/m
  end

  def assert_notice_message_does_not_match(message, options = {})
    message = Regexp.escape(message) if options[:escape]
    @browser.assert_element_does_not_match SharedFeatureHelperPageId::FLASH, /#{message}/m
  end

  def assert_info_message(expected_message, options={})
    expected_message = Regexp.escape(expected_message) if options[:escape]
    if options[:element_id]
      actual_message = @browser.get_text(options[:element_id])
    else
      actual_message = @browser.get_text(SharedFeatureHelperPageId::INFO)
    end
    assert_match /#{expected_message}/m, actual_message
  end

  def should_see_message(msg)
    @browser.assert_text_present(msg)
  end

  def assert_info_message_not_present
    @browser.assert_element_not_present(SharedFeatureHelperPageId::INFO)
  end

  def assert_question_box(message)
    @browser.assert_element_matches SharedFeatureHelperPageId::QUESTION_BOX, /#{message}/
  end

  def assert_cannot_access_resource_error_message_present
    assert_error_message('Either the resource you requested does not exist or you do not have access rights to that resource.')
  end

  def assert_warning_box_present
    @browser.assert_element_present(class_locator(SharedFeatureHelperPageId::WARNING_BOX))
    @browser.assert_element_matches(class_locator(SharedFeatureHelperPageId::WARNING_BOX), /CAUTION! This action is final and irrecoverable./)
  end

  def assert_warning_message(message)
    actual_message = @browser.get_eval("this.browserbot.getCurrentWindow().$('warning').innerHTML.unescapeHTML()") # commented as does not work well with multiple messages
    assert_equal(message.trim, actual_message.trim)
  end

  def assert_warning_message_matches(message, options={})
    message = Regexp.escape(message) if options[:escape]
    @browser.assert_element_matches SharedFeatureHelperPageId::WARNING, /#{message}/m
  end

  def assert_warning_message_not_present
    @browser.assert_element_not_present(SharedFeatureHelperPageId::WARNING)
  end

  def assert_info_box_light_present
    @browser.assert_element_present(class_locator(SharedFeatureHelperPageId::INFO_BOX))
  end

  def assert_info_box_light_message(expected_message, options ={})
    assert_message(SharedFeatureHelperPageId::INFO_BOX, expected_message, options)
  end

  def assert_warning_box_message(expected_message, options ={})
    assert_message(SharedFeatureHelperPageId::WARNING_BOX, expected_message, options)
  end

  def assert_message(type, expected_message, options={})
    expected_message = Regexp.escape(expected_message) if options[:escape]
    id_locator = options[:id] ? "##{options[:id]}" : ""
    if options[:include]
      actual_message = @browser.get_text(css_locator("#{id_locator} .#{type}"))
      assert_include(expected_message.strip_all, actual_message.strip_all)
    else
      @browser.assert_element_matches(css_locator("#{id_locator} .#{type}"), /#{actual_message}/m)
    end
  end

  def assert_info_box_light_message_not_present(message, options ={})
    message = Regexp.escape(message) if options[:escape]
    id_locator = options[:id] ? "##{options[:id]}" : ""
    @browser.assert_element_does_not_match(css_locator("#{id_locator} .info-box"), /#{message}/)
  end

  def assert_redirected_to_with_error(path, message_text)
    actual_location = @browser.get_location
    assert_equal(path, actual_location)
    assert_error_message(message_text)
  end

  def assert_property_has_transition_only_css_style(element_id)
    assert_element_has_css_class(element_id, SharedFeatureHelperPageId::TRANSITION_HIDDEN_PROTECTED)
  end

  def assert_property_not_editable_in(context, project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property, :with_hidden => true)
    property_type = property.attributes['type']
    if property_type == 'EnumeratedPropertyDefinition'
      @browser.assert_element_not_present("#{context}_enumeratedpropertydefinition_#{property.id}_drop_down")
      assert_property_has_transition_only_css_style("#{context}_enumeratedpropertydefinition_#{property.id}_drop_link")
    elsif property_type == 'UserPropertyDefinition'
      @browser.assert_element_not_present("#{context}_userpropertydefinition_#{property.id}_drop_down")
      assert_property_has_transition_only_css_style("#{context}_userpropertydefinition_#{property.id}_drop_link")
    elsif property_type == 'DatePropertyDefinition'
      @browser.assert_element_not_present("#{context}_datepropertydefinition_#{property.id}_drop_down")
      #@browser.assert_element_not_present("#{context}_datepropertydefinition_#{property.id}_calendar")
      assert_property_has_transition_only_css_style("#{context}_datepropertydefinition_#{property.id}_drop_link")
    elsif property_type == 'TextPropertyDefinition'
      @browser.click(editlist_link_id(property, context))
      @browser.assert_not_visible("#{context}_textpropertydefinition_#{property.id}_editor")
      assert_property_has_transition_only_css_style("#{context}_textpropertydefinition_#{property.id}_edit_link")
    elsif property_type == 'FormulaPropertyDefinition'
      @browser.click(editlist_link_id(property, context))
      @browser.assert_not_visible("#{context}_formulapropertydefinition_#{property.id}_editor")
      assert_property_has_transition_only_css_style("#{context}_formulapropertydefinition_#{property.id}_edit_link")
    elsif property_type == 'AggregatePropertyDefinition'
      @browser.click(editlist_link_id(property, context))
      @browser.assert_not_visible("#{context}_aggregatepropertydefinition_#{property.id}_editor")
      assert_property_has_transition_only_css_style("#{context}_aggregatepropertydefinition_#{property.id}_edit_link")
    elsif property_type == 'CardRelationshipPropertyDefinition'
      assert_property_has_transition_only_css_style("#{context}_cardrelationshippropertydefinition_#{property.id}_drop_link")
    elsif property_type == 'TreeRelationshipPropertyDefinition'
      @browser.assert_not_visible("#{context}_treerelationshippropertydefinition_#{property.id}_drop_link")
    else
      raise "Property type #{property_type} is not supported"
    end
  end

  def assert_property_not_editable_for_read_only_team_member_in(context, project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).reload.find_property_definition(property)
    property_type = property.attributes['type']
    if property_type == 'EnumeratedPropertyDefinition'
      @browser.assert_element_not_present("#{context}_enumeratedpropertydefinition_#{property.id}_drop_down")
    elsif property_type == 'UserPropertyDefinition'
      @browser.assert_element_not_present("#{context}_userpropertydefinition_#{property.id}_drop_down")
    elsif property_type == 'DatePropertyDefinition'
      @browser.assert_element_not_present("#{context}_datepropertydefinition_#{property.id}_drop_down")
    elsif property_type == 'TextPropertyDefinition'
      @browser.assert_element_not_present("#{context}_textpropertydefinition_#{property.id}_editor")
    elsif property_type == 'FormulaPropertyDefinition'
      @browser.assert_element_not_present("#{context}_formulapropertydefinition_#{property.id}_editor")
    elsif property_type == 'AggregatePropertyDefinition'
      @browser.assert_element_not_present("#{context}_aggregatepropertydefinition_#{property.id}_editor")
    elsif property_type == 'TreeRelationshipPropertyDefinition'
      @browser.click("#{context}_treerelationshippropertydefinition_#{property.id}_drop_link")
      @browser.assert_element_not_present(css_locator(".lightbox"))
    else
      raise "Property type #{property_type} is not supported"
    end
  end

  def assert_filter_set_on_card_selector(filter_order_number, properties)
    properties.each do |property, value|
      @browser.assert_text("card_explorer_filter_widget_cards_filter_#{filter_order_number}_properties_drop_link", property)
      @browser.assert_text("card_explorer_filter_widget_cards_filter_#{filter_order_number}_values_drop_link", value)
    end
  end

  def assert_contextual_help_is_visible
    assert_equal(true, contextual_help_visible)
  end

  def assert_contextual_help_is_invisible
    assert_equal(false, contextual_help_visible)
  end

  private
  def all_unique_hrefs
    @browser.get_eval("selenium.browserbot.getCurrentWindow().$$('a').invoke('readAttribute', 'href').uniq()").split(',')
  end

end
