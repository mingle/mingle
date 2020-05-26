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

module TagMgmtAndUsagePage

  def assert_edit_tags_link_not_present
    @browser.assert_element_not_present(tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).open_edit_link_locator)
  end
  
  def assert_no_tags_set_text_present_in_tag_editor
    @browser.assert_element_matches(tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, /(no tags set)/)
  end
  
  def assert_tag_not_present_in_tag_editor(tag)
    @browser.assert_element_does_not_match(tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, /#{tag}/)
  end

  def assert_tag_present_on_tag_management_page(tag)
    @browser.assert_element_matches(TagMgmtAndUsagePageId::TAGS_ID, /#{tag}/)
  end
  
  def assert_tag_not_present_on_tag_management_page(tag)
    @browser.assert_element_does_not_match(TagMgmtAndUsagePageId::TAGS_ID, /#{tag}/)
  end
  
  def assert_in_tag_editor(tag)
    @browser.assert_text_present add_available_tag(tag)
  end
  
  def assert_not_in_tag_editor(tag)
    @browser.assert_text_not_present add_available_tag(tag)
  end
  
  def assert_tagged_with(*tag_names)
    @browser.click tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).open_edit_link_locator
    tag_names.each{|tag_name| assert @browser.is_element_present(delete_tag_id(tag_name))}
  end
  
  def assert_not_tagged_with(*tag_names)
    @browser.click tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).open_edit_link_locator
    tag_names.each{|tag_name| assert !@browser.is_element_present(delete_tag_id(tag_name))}
  end

  def assert_tag_in_widget(*tag_names)
    @browser.assert_text tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, tag_names.join(', ')
  end
  
  def assert_tag_in_quick_add_widget(*tag_names)
    @browser.assert_text tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, tag_names.join(', ')
  end
  
  def assert_tag_in_editor_on_card_edit(*tag_names)
    @browser.assert_text tags_editor(TagMgmtAndUsagePageId::TAGGED_WITH_ID).tag_list_locator, tag_names.join(', ')
  end
  
  def assert_tag_not_in_editor_on_card_edit(*tag_names)
    @browser.assert_not_text tags_editor(TagMgmtAndUsagePageId::TAGGED_WITH_ID).tag_list_locator, tag_names.join(', ')
  end

  def assert_tag_in_filter_widget(*tag_names)
    @browser.assert_text tags_editor(TagMgmtAndUsagePageId::FILTER_TAGS_ID).tag_list_locator, tag_names.join(', ')
  end  

  def assert_tag_not_in_widget(*tag_names)
    @browser.assert_not_text tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, tag_names.join(', ')
  end 
  
  def assert_tag_exists(tag)
    # TODO after html ids are switched to use tag ids, use the followin or something like it
    # @browser.assert_element_present("tag_row_#{tag.id}")
    @browser.assert_element_matches("//table[@id='#{TagMgmtAndUsagePageId::TAGS_ID}']", /#{tag}/)
  end
  
  def assert_tag_exists_on_quick_add(tag)
    @browser.assert_element_matches("//div[@id='#{TagMgmtAndUsagePageId::TAGS_ID}']",/#{tag}/)
  end
  
  def assert_tag_editor_not_present_on_quick_add
    @browser.assert_element_not_present(TagMgmtAndUsagePageId::TAG_LIST_TAG_EDITOR_CONTAINER)
  end
  
  def assert_tag_does_not_exist(tag)
    @browser.assert_element_does_not_match("//table[@id='#{TagMgmtAndUsagePageId::TAGS_ID}']//td", /^#{tag}$/)
  end
  
  def assert_value_present_in_tagging_panel(*values)
    values.each{|value| @browser.assert_element_matches(TagMgmtAndUsagePageId::BULK_TAGGING_PANEL, /#{value}/mi)}
  end
  
  def assert_value_not_present_in_tagging_panel(*values)
    values.each{|value| @browser.assert_element_does_not_match(TagMgmtAndUsagePageId::BULK_TAGGING_PANEL, /#{value}/mi)}
  end
  
  def assert_bulk_tag_button_enabled
    assert_equal 'false', @browser.get_eval("this.browserbot.getCurrentWindow().Element.hasClassName('bulk-tag-button', 'tab-disabled')")
  end

  def assert_bulk_tag_button_disabled
    assert_equal 'true', @browser.get_eval("this.browserbot.getCurrentWindow().Element.hasClassName('bulk-tag-button', 'tab-disabled')")
  end

  def assert_bulk_tagging_panel_visible
    @browser.assert_visible TagMgmtAndUsagePageId::BULK_TAGGING_PANEL
  end

  def assert_bulk_tagging_panel_not_visible
    @browser.assert_not_visible TagMgmtAndUsagePageId::BULK_TAGGING_PANEL
  end
  
  def assert_tag_present_in_tag_editor(tag)
     @browser.assert_element_matches(tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID).tag_list_locator, /#{tag}/)
   end
end
