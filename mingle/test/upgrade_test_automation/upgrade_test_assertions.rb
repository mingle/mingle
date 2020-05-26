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

module UpgradeTestAssertions

  # def assert_tag_one_card_in_card_list_view(project_name, tag_name, card_number)
  #   p "click the project name #{project_name} and go into this project "
  #   @browser.click("link=#{project_name}")
  #   
  #   p "wait a moment until the project overview page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   p "click the 'all' link and open the card list"
  #   @browser.click("tab_all_link")
  #   
  #   p "wait for the card list page loaded"
  #   @browser.wait_for_page_to_load
  #   # @browser.click %{dom=this.browserbot.getCurrentWindow().$$(a[href='/projects/finance_mysql_2_2/cards/list?order=desc&sort=number&style=list&tab=All'])[0]}
  # 
  #   p "wait untile the '#' displayed on the page"
  #   @browser.wait_for_element_visible('link=#')
  #   
  #   p "clicking on the '#' symbol for re-ordering all the card by number"
  #   @browser.click('link=#')
  #   
  #   p "wait until the re-ordering completed"
  #   @browser.wait_for_page_to_load
  #   
  #   p "click on the #{card_number}th card for opening the card view"
  #   @browser.click("card-number-#{card_number}")
  #   
  #   p "wait until the card view paged loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   p "clicking on the 'edit tags' link"
  #   @browser.click('link=Edit tags')
  #   
  #   p "wait until the input box displayed"
  #   @browser.wait_for_all_ajax_finished
  #   
  #   p "input #{tag_name} in the input box"
  #   @browser.type('input_tag_list', tag_name)
  #   
  #   p "click and save the new tag"
  #   @browser.click(%{dom=selenium.browserbot.getCurrentWindow().$$('.input-type-button.add-tag-button')[0]})
  #   
  #   p "wait until the saving completed"
  #   @browser.wait_for_all_ajax_finished
  #   
  #   p "verfiy the tag name #{tag_name} already added for this card"
  #   assert_tag_name_present_in_tag_list(tag_name)
  # end
  
  
  # def assert_can_bulk_all_cards_in_card_list_view(project_name, tag_name)
  #   p "click the project name #{project_name} and go into this project "
  #   @browser.click("link=#{project_name}")
  #   
  #   # p "wait a moment until the project overview page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   p "click the 'all' link and open the card list"
  #   @browser.click("tab_all_link")
  #   
  #   # p "wait for the card list page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   # p "wait untile the '#' displayed on the page"
  #   @browser.wait_for_element_visible('link=#')
  #   
  #   p "clicking on the '#' symbol for re-ordering all the card by number"
  #   @browser.click('link=#')
  #   
  #   # p "wait until the re-ordering completed"
  #   @browser.wait_for_page_to_load
  #   
  #   p "select all cards in current card list view"
  #   @browser.click('select_all')
  #   
  #   # p "wait until all the cards get selected"
  #   @browser.wait_for_all_ajax_finished
  #   
  #   p "click on the bug-tag button"
  #   @browser.click('bulk-tag-button')
  #   
  #   # p "wait until the input box displayed"
  #   @browser.wait_for_all_ajax_finished
  #   
  #   p "input the new tag in the input box"
  #   @browser.type('bulk_tags', tag_name)
  #   
  #   p "click the submit button"
  #   @browser.click('submit_bulk_tags')
  #   
  #   # p "wait until it saved"
  #   @browser.wait_for_all_ajax_finished
  #   
  #   p "verify there is an successful message"
  #   @browser.assert_text_present('cards updated')
  #   
  #   p "clicking on card 10 and open this card"    
  #   @browser.click('card-number-10')
  #   
  #   # p "wait until the card view page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   p "verfiy the tag name #{tag_name} already added for this card"
  #   assert_tag_name_present_in_tag_list(tag_name)
  # end 
  
  # def assert_tag_name_present_in_tag_list(tag_name)
  #   current_tag_name = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('tag_list').value;})
  #   raise SeleniumCommandError.new("#{tag_name} is not found in current page") unless current_tag_name.include?(tag_name)
  # end
  # 
  # def assert_can_modify_card_name_via_excel_import(project_name, card_number, new_card_name)
  #   p "click the project name #{project_name} and go into this project "
  #   @browser.click("link=#{project_name}")
  #   
  #   # p "wait a moment until the project overview page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   p "click the 'all' link and open the card list"
  #   @browser.click("tab_all_link")
  #   
  #   # p "wait for the card list page loaded"
  #   @browser.wait_for_page_to_load
  #   
  #   header_row = [['Number', 'Name']]
  #   card_data = [["#{card_number}", "#{new_card_name}"]]
  #   
  #   p "input the excel data and preview the data"
  #   preview_the_excel_import(excel_copy_string(header_row, card_data))
  #   sleep 150
  #   
  #   p "Confirm the preview and finish the import "
  #   import_excel_data_from_preview
  #   sleep 100
  #   
  #   p "clicking on the '#' symbol for re-ordering all the card by number"
  #   @browser.click('link=#')
  #   
  #   # p "wait until the re-ordering completed"
  #   @browser.wait_for_page_to_load
  #   
  #   p "open the #{card_number}th card from card list"
  #   @browser.click("card-number-#{card_number}")
  #   @browser.wait_for_page_to_load
  #   
  #   p "verify the new card name displayed in current card"
  #   assert_card_name_in_show(new_card_name)
  # end
  

  
    # 
    # @browser.type "user_login", name
    # @browser.type "user_password", password
    # @browser.click "name=commit"
    # 
    # 
  # def assert_text_in_locator(text, locator)
  #   actual_text = @browser.get_text(locator)
  #   raise SeleniumCommandError.new("cannot find #{text}") unless actual_text == text
  # end
  
end
