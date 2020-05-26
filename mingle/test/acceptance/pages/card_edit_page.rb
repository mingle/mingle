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

module CardEditPage

  NOT_SET = '(not set)'

  def stale_aggregate_prop_id(property_name, context = nil)
    droplist_part_id(property_name, 'stale', context)
  end

  def disabled_link_id(property_name, context = nil)
    droplist_part_id(property_name, 'disabled_link', context)
  end

  def editlist_lightbox_editor_id(property_name, context=nil)
    droplist_part_id(property_name, 'sets_editor', context)
  end

  def editlist_lightbox_link_id(property_name, context = nil)
    droplist_part_id(property_name, 'sets_edit_link', context)
  end

  def lightbox_droplist_link_id(property_name, context = nil)
    droplist_part_id(property_name, 'sets_drop_link', context)
  end

  def droplist_lightbox_option_id(property_name, value, context= nil)
    droplist_part_id(property_name, "sets_option_#{value}", context)
  end

  def droplist_lightbox_dropdown_id(property_name, context= nil)
    droplist_part_id(property_name, "sets_drop_down", context)
  end

  def lightbox_requires_droplist_link_id(property_name, context = nil)
    droplist_part_id(property_name, 'requires_drop_link', context)
  end

  def droplist_requires_lightbox_option_id(property_name, value, context= nil)
    droplist_part_id(property_name, "requires_option_#{value}", context)
  end

  def droplist_requires_lightbox_dropdown_id(property_name, context= nil)
    droplist_part_id(property_name, "requires_drop_down", context)
  end

  def droplist_add_value_action_id(property_name, context=nil)
    droplist_part_id(property_name, 'action_adding_value', context)
  end

  def droplist_inline_editor_id(property_name, context=nil)
    droplist_part_id(property_name, 'inline_editor', context)
  end

  def assert_card_or_page_content_in_edit(description)
    wait_for_wysiwyg_editor_ready
    @browser.wait_for_element_visible CardEditPageId::RENDERABLE_CONTENTS
    @browser.assert_element_matches(CardEditPageId::RENDERABLE_CONTENTS, /#{description}/)
  end

  def assert_comment_in_card_edit_page(comment)
    @browser.assert_element_matches(CardEditPageId::CARD_COMMENT_ID_ON_EDIT, /#{comment}/)
  end

  def assert_version_info_on_card_edit(message)
    @browser.assert_element_matches(css_locator('.version-info'), /#{message}/)
  end

  def assert_properties_set_on_card_edit(properties)
    properties.each { |name, value| assert_property_set_on_card_edit(name, value) }
  end

  def assert_card_name_in_edit(name)
    @browser.assert_value(CardEditPageId::CARD_NAME, name)
  end

  def assert_creating_new_card
    @browser.assert_title "#{@project.name} New Card - Mingle"
  end

  def assert_edit_property_set(name, value)
    if(@browser.is_visible(droplist_link_id(name, "edit")))
      @browser.assert_text(droplist_link_id(name, "edit"), value)
    else
      raise "element #{droplist_link_id(name, "edit")} not visible"
    end
  end

  def assert_properties_not_set_on_card_edit(*properties)
    properties.each { |name| assert_property_not_set_on_card_edit(name)  }
  end

  def assert_property_not_set_on_card_edit(property)
    assert_property_set_on_card_edit(property, NOT_SET)
  end

  def assert_property_not_present_on_card_edit(property)
    @browser.assert_element_not_present_or_visible(property_editor_property_name_id(property, "edit"))
  end

  def assert_property_is_visible_on_card_edit(property)
    @browser.assert_visible(property_editor_panel_id(property, "edit"))
  end

  def assert_murmur_this_comment_is_checked_on_card_edit
    @browser.assert_checked(CardEditPageId::MURMUR_THIS_COMMENT_CHECKBOX)
  end

  def assert_values_present_in_property_drop_down_on_card_edit(property, values)
    assert_values_present_in_property_drop_down(property, values, "edit")
  end

  def assert_values_not_present_in_property_drop_down_on_card_edit(property, values)
    assert_values_not_present_in_property_drop_down(property, values, "edit")
  end

  def assert_mingle_image_tag_present_on_page_edit
    @browser.wait_for_element_present(CardEditPageId::RENDERABLE_CONTENTS)
    @browser.assert_element_present("//img[@class='mingle-image']")
  end

  def assert_mingle_image_tag_present_on_page_show
    @browser.wait_for_element_present(CardEditPageId::RENDERABLE_CONTENTS)
    @browser.assert_element_present("//img[@class='mingle-image']")
  end

  def assert_property_tooltip_on_card_edit(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    assert_equal property.tooltip, get_property_tooltip(property, 'edit')
  end

  def assert_editor_toolbar_present
    wait_for_wysiwyg_editor_ready
    @browser.wait_for_element_visible class_locator("cke_toolbox")
    @browser.wait_for_element_present(CardEditPageId::RENDERABLE_CONTENTS)
  end

  def assert_text_present_for_macro(id, text)
    @browser.assert_text_present_in(id, text)
  end

  def verify_error_message_on_wysiwyg_editor(expected_message)
    @browser.wait_for_element_present(class_locator('cke_dialog_ui_html'))
    message = @browser.get_eval("this.browserbot.getCurrentWindow().$$('.cke_dialog_ui_html')[0].innerHTML.unescapeHTML()")
    assert_include_ignoring_spaces(message, expected_message)
  end


end
