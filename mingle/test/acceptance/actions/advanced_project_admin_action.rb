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

module AdvancedProjectAdminAction

  def navigate_to_advanced_project_administration_page_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open("/projects/#{project}/admin/advanced")
  end

  def check_project_health_state
    @browser.click_and_wait(AdvancedProjectAdminPageId::PROJECT_HEALTH_STATE_BUTTON)
  end
  
  def rebuild_the_Murmurs_card_links
    @project.rebuild_card_murmur_links_as_admin
    run_background_jobs_for_murmur_card_links
  end
  
  def rebuild_the_murmurs_and_card_links_from_admin_page
    navigate_to_advanced_project_administration_page_for(@project)
    @browser.click_and_wait(AdvancedProjectAdminPageId::REBUILD_MURMUR_CARD_LINKS_BUTTON)
  end
  
  def run_background_jobs_for_murmur_card_links
    CardMurmurLinkProcessor.run_once
    FullTextSearch.run_once
  end
end
