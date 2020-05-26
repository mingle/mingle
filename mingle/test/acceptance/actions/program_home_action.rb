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

module ProgramHomeAction
  def create_new_program(program_name)
    @browser.open "/programs"
    @browser.click create_new_program_link_id(program_name)
    @browser.click ProgramHomePageId::PROGRAM_NAME_ID
    @browser.type ProgramHomePageId::PROGRAM_NAME_ID, program_name
    press_enter_on(program_name)
  end
  
  def press_enter_on(program_name)
    @browser.get_eval("this.browserbot.getCurrentWindow().$j('#rename_program_#{program_name.gsub(" ", "_")}_form').submit()")
    @browser.wait_for_all_ajax_finished
  end

  def click_backlog_link_on_program_for(program_name)
    @browser.click_and_wait program_backlog_link_id_for(program_name)
  end

  def click_browser_back
    @browser.get_eval("this.browserbot.getCurrentWindow().window.history.go(-1)")
    @browser.wait_for_page_to_load
  end
end
