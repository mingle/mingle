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

module PropertyEditorsAction

  def set_relationship_properties(context, properties)
    properties.each do |name, value|
      next set_properties_on_card_show(name => value) if is_a_special?(value)
      @browser.assert_visible droplist_link_id(name, context)
      @browser.click droplist_link_id(name, context)
      @browser.with_ajax_wait do
        @browser.click droplist_select_card_action(droplist_dropdown_id(name, context))
      end

      @browser.click(card_selector_result_locator(:filter, value.number))
      @browser.wait_for_all_ajax_finished if context == "show"
    end
  end

  def open_card_selector_for_property(property, context)
    @browser.click(property_value_widget(property))
    @browser.click(card_selector_drop_down_id(property, context))
  end

  def get_property_tooltip(property, context)
    locator = property_editor_tooltip_id(property, context)
    @browser.get_attribute("#{locator}@title")
  end

  def get_property_dropdown_options(property, context)
    dropdown = droplist_dropdown_id(property, context)
    @browser.click droplist_link_id(property, context) unless (@browser.is_element_present(dropdown) && @browser.is_visible(dropdown))
    opts = @browser.get_eval(%Q{
      var _j = selenium.page().getCurrentWindow().$j;
      _j("##{dropdown} .select-option").filter(":visible").map(function(i, el) { return _j(el).text(); });
    })
    opts.split(",")
  end

  def click_on_card_property(property, context)
    @browser.assert_visible droplist_link_id(property, context)
    @browser.click droplist_link_id(property, context)
  end

  def enter_search_value_for_property_editor_drop_down(property, keyword, context)
    @browser.type_in_property_search_filter(property_editor_drop_down_search_field_id(property, context), keyword)
  end

  def select_property_drop_down_value(property, value, context)
    @browser.with_ajax_wait do
      @browser.click(droplist_option_id(property, value, context))
    end
  end

  def assert_card_type_set_on_card_show(card_type)
    card_type = card_type.name if card_type.respond_to?(:name)
    @browser.assert_text(card_type_editor_id("show"), card_type)
  end
  alias_method :assert_card_type_set_on_card_edit, :assert_card_type_set_on_card_show

  def assert_property_set_on_card_show(property, value)
    if (property.to_s.downcase == "type")
      assert_card_type_set_on_card_show(value)
    else
      @browser.wait_for_all_ajax_finished
      value = value.number_and_name if value.respond_to?(:number_and_name)
      element_id = droplist_link_id(property, "show")
      @browser.wait_for_element_present("css=##{element_id}")
      @browser.assert_text(element_id, value)
    end
  end
  alias_method :assert_property_set_on_card_edit, :assert_property_set_on_card_show

  def assert_stale_value(property, value)
    @browser.assert_text(property_editor_id(property), value)
    assert_is_stale(property)
  end

  def assert_is_stale(property)
    locator = property_editor_id(property)
    classes = @browser.get_attribute("#{locator}@class").split(/\s+/)
    assert classes.include?("stale-calculation"), "element: #{locator} is not marked as stale"
  end

  def assert_is_not_stale(property)
    locator = property_editor_id(property)
    classes = @browser.get_attribute("#{locator}@class").split(/\s+/)
    assert !classes.include?("stale-calculation"), "element: #{locator} is marked as stale"
  end

  def assert_property_not_editable(property)
    assert_equal 'true', @browser.get_attribute("#{property_editor_id(property)}@data-read-only")
  end
  alias_method :assert_property_not_editable_on_card_show, :assert_property_not_editable
  alias_method :assert_property_not_editable_on_card_edit, :assert_property_not_editable

  def assert_values_present_in_property_drop_down(property, values, context)
    values = values.map(&:to_s)
    options = get_property_dropdown_options(property, context)
    raise "no values specified for assertion" if values.empty?
    diff = values - options
    assert diff.empty?, "the following values: #{diff.inspect} were not present in droplist options: #{options.inspect}"
  end

  def assert_values_not_present_in_property_drop_down(property, values, context)
    values = values.map(&:to_s)
    options = get_property_dropdown_options(property, context)
    raise "no values specified for assertion" if values.empty?
    diff = values - options
    assert_equal values, diff, "the following values: #{(values - diff).inspect} were present in droplist options: #{options.inspect}"
  end

  def assert_inline_enum_value_add_not_present_for(property, context)
    @browser.click droplist_link_id(property, context)
    @browser.assert_element_not_present(droplist_add_value_action_id(property, context))
  end

  def assert_inline_enum_value_add_present_for(property, context)
    @browser.click droplist_link_id(property, context)
    @browser.assert_element_present(droplist_add_value_action_id(property, context))
  end

end
