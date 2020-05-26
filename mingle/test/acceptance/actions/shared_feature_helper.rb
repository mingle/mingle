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

module SharedFeatureHelper

  def card_number_and_name(card)
    "##{card.number} #{card.name}"
  end

  def click_edit_link_and_wait_for_page_load
    @browser.click_and_wait(SharedFeatureHelperPageId::EDIT_LINK)
  end

  def click_cancel_link
    @browser.click_and_wait SharedFeatureHelperPageId::CANCEL_LINK
  end

  def click_link(link_text)
    @browser.click_and_wait(click_link_text(link_text))
  end

  def click_cancel_using_js
   @browser.get_eval "this.browserbot.getCurrentWindow().$$('.cancel')[0].click()"
    @browser.wait_for_page_to_load
  end

  def click_link_with_ajax_wait(link_text)
    @browser.with_ajax_wait do
      link_selector = click_link_text(link_text)
      @browser.wait_for_element_present(link_selector)
      @browser.click(link_selector)
    end
  end

  def click_save_link
    @browser.click_and_wait SharedFeatureHelperPageId::SAVE_LINK
  end

  def with_ajax_wait(&block)
    @browser.with_ajax_wait(&block)
  end

  def click_save_settings_link
    @browser.click_and_wait SharedFeatureHelperPageId::SAVE_SETTINGS_LINK
  end

  def click_save_permanently_link
    @browser.click_and_wait SharedFeatureHelperPageId::SAVE_PERMANENTLY_LINK
  end

  def click_delete_link
    @browser.click_and_wait(SharedFeatureHelperPageId::DELETE_LINK)
  end

  def click_continue_to_delete
    @browser.click_and_wait(SharedFeatureHelperPageId::CONTINUE_TO_DELETE_LINK)
  end

  def click_continue_to_delete_link
   @browser.click_and_wait(SharedFeatureHelperPageId::CONTINUE_TO_DELETE_LINK)
  end

  def click_continue_to_delete_on_confirmation_popup
    @browser.click_and_wait(SharedFeatureHelperPageId::CONTINUE_TO_DELETE_LINK)
  end

  def click_on_continue_to_delete_link
    @browser.click_and_wait(SharedFeatureHelperPageId::CONTINUE_TO_DELETE_LINK)
  end

  def click_continue_to_update
    @browser.click_and_wait(SharedFeatureHelperPageId::CONTINUE_TO_UPDATE_LINK)
  end

  def click_link_to_this_page
    @browser.click_and_wait(SharedFeatureHelperPageId::LINK_TO_THIS_PAGE)
    @browser.wait_for_all_ajax_finished
  end

  def click_up_link
    up_link_text = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('up-link-hover-text').innerHTML")
    @browser.click_and_wait(click_up_link_text(up_link_text))
  end

  def click_up
    @browser.click_and_wait(SharedFeatureHelperPageId::CLICK_UP_LINK)
  end

  def click_on_reset_filter_link
    @browser.click_and_wait(SharedFeatureHelperPageId::RESET_FILTER_LINK)
  end

  def click_to_hide_too_many_macros_warning
    @browser.with_ajax_wait do
      @browser.click(css_locator("div#too_many_macros_warning a[onclick]"))
    end
  end

  def contextual_help_visible
    @browser.is_visible("id=contextual_help_container")
  end

  def show_contextual_help
    unless contextual_help_visible
      with_ajax_wait { @browser.click(SharedFeatureHelperPageId::SHOW_HELP_LINK) }
      @browser.wait_for_text_present("Hide help")
    end
  end

  def hide_contextual_help
    if contextual_help_visible
      with_ajax_wait { @browser.click(SharedFeatureHelperPageId::HIDE_HELP_LINK) }
      @browser.wait_for_text_present("Show help")
    end

  end

  def is_a_special?(value)
    value.blank? || value =~ /^\(.*\)$/
  end

end
