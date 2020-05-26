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

module TemplateManagementAction
  
  def navigate_to_template_management_page
     @browser.open('/admin/templates')
   end
   
   def click_template_link(template_name)
      @browser.click_and_wait(template_name_link(template_name))
    end
   
   def open_project_template(project)
     @browser.click_and_wait(project_identifier_template_link(project))
   end
   
   def update_project_template_identifier(project,new_project_identifier)
      navigate_to_template_management_page
      open_project_template(project)
      @browser.click_and_wait TemplateManagementPageId::PROJECT_ADMIN_LINK
      type_project_identifier(new_project_identifier)
      click_save_link
    end
    
    def delete_template_permanently(project)
      @browser.click_and_wait(TemplateManagementPageId::DELETE_THIS_LINK)
      @browser.click_and_wait TemplateManagementPageId::CONTINUE_TO_DELETE_LINK
    end
    
    def agile_hybrid_template_identifier
      return Dir["../../templates/*.mingle"][0].gsub!("../../templates/", "").gsub!(".mingle", "").gsub!("(", "_").gsub!(")", "").gsub!(".", "_")
    end

    def scrum_template_identifier
      return Dir["../../templates/*.mingle"][1].gsub!("../../templates/", "").gsub!(".mingle", "").gsub!("(", "_").gsub!(")", "").gsub!(".", "_")
    end

    def story_tracker_template_identifier
      return Dir["../../templates/*.mingle"][2].gsub!("../../templates/", "").gsub!(".mingle", "").gsub!("(", "_").gsub!(")", "").gsub!(".", "_")
    end

    def xp_template_identifier
      return Dir["../../templates/*.mingle"][3].gsub!("../../templates/", "").gsub!(".mingle", "").gsub!("(", "_").gsub!(")", "").gsub!(".", "_")
    end

    def open_admin_page_of_a_template(template)
      case "#{template}"
       when TemplateManagementPageId::AGILE_HYBRID_TEMPLATE_ID
         template_identifier = agile_hybrid_template_identifier
       when TemplateManagementPageId::SCRUM_TEMPLATE_ID
         template_identifier = scrum_template_identifier
       when TemplateManagementPageId::STORY_TRACKER_TEMPLATE
         template_identifier = story_tracker_template_identifier
       when TemplateManagementPageId::XP_TEMPLATE
         template_identifier = xp_template_identifiers
       else
         raise "cannot find the template identifier for #{template}!"
     end
      @browser.open("/projects/#{template_identifier}")
      @browser.click_and_wait TemplateManagementPageId::PROJECT_ADMIN_LINK
    end
    
    
end
