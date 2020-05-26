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

module CardKeywordsAction
  def navigate_to_card_keywords_for(project)
    project = project.identifier if project.respond_to? :identifier
    navigate_to_project_admin_for(project)
    @browser.click_and_wait card_keywords_link
  end
  
  def type_project_card_keywords(keywords_string)
    @browser.type(CardKeywordsPageId::CARD_KEYWORD_INPUT_BOX, keywords_string)
  end
  
  def type_card_number_for_testing_pattern_matching(card_number)
    @browser.type(CardKeywordsPageId::CARD_NUMBER_TEXT_BOX, card_number)
  end
  
  def click_show_last_ten_matching_revisions_button
    @browser.with_ajax_wait do 
      @browser.click CardKeywordsPageId::TEST_BUTTON
    end
  end
  
  def click_update_keywords_link
    @browser.click_and_wait(update_keywords_link) 
  end
  
end
