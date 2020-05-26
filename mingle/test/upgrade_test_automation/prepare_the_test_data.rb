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

require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_env_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_assertions.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_helper.rb')
include UpgradeTestAssertions
include UpgradeTestHelper

class PrepareTestData < ActiveSupport::TestCase
  PROJECT_IDENTIFIER = "project_pg_3_0"
  
  def setup
    @browser = selenium_session
    @user = @browser
    @browser.open('/')
  end
  
  def teardown
    self.class.close_selenium_sessions
  end
  
  def get_property_ids
    log_in_upgraded_instance_as_admin
    @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
    @property_id_of_a_hidden_property = @browser.get_attribute(css_locator("input", 3)+"@id").gsub(/\w*-/, '')
    @property_id_of_a_locked_property = @browser.get_attribute(css_locator("input", 5)+"@id").gsub(/\w*-/, '')
    @property_id_of_a_transition_only_property = @browser.get_attribute(css_locator("input", 8)+"@id").gsub(/\w*-/, '')
    @property_id_of_comment_property =  @browser.get_attribute(css_locator("input", 10)+"@id").gsub(/\w*-/, '')
    @property_id_of_double_size_property = @browser.get_attribute(css_locator("input", 12)+"@id").gsub(/\w*-/, '')
    @property_id_of_owner_property = @browser.get_attribute(css_locator("input", 13)+"@id").gsub(/\w*-/, '')
    @property_id_of_priority_property = @browser.get_attribute(css_locator("input", 15)+"@id").gsub(/\w*-/, '')
    @property_id_of_related_card_property = @browser.get_attribute(css_locator("input", 18)+"@id").gsub(/\w*-/, '')
    @property_id_of_release_number_property = @browser.get_attribute(css_locator("input", 20)+"@id").gsub(/\w*-/, '')
    @property_id_of_size_property = @browser.get_attribute(css_locator("input", 23)+"@id").gsub(/\w*-/, '')
    @property_id_of_start_date_property = @browser.get_attribute(css_locator("input", 25)+"@id").gsub(/\w*-/, '')
  end 

   def test_01_create_new_users
     log_in_upgraded_instance_as_admin
     @browser.open ("/users/list")
     
     @browser.click_and_wait("link=New user")
     @browser.type("user_login", "Obama")
     @browser.type("user_name", "mingle_obama")
     @browser.type("user_password", "o")
     @browser.type("user_password_confirmation", "o")
     @browser.click_and_wait("link=Create this profile")
     
     @browser.click_and_wait("link=New user")
     @browser.type("user_login", "Hilton")
     @browser.type("user_name", "mingle_hilton")
     @browser.type("user_password", "h")
     @browser.type("user_password_confirmation", "h")
     @browser.click_and_wait("link=Create this profile")
     
     @browser.click_and_wait("link=New user")
     @browser.type("user_login", "Bush")
     @browser.type("user_name", "mingle_bush")
     @browser.type("user_password", "b")
     @browser.type("user_password_confirmation", "b")
     @browser.click_and_wait("link=Create this profile")
     
     @browser.click_and_wait("link=New user")
     @browser.type("user_login", "Tracy")
     @browser.type("user_name", "mingle_tracy")
     @browser.type("user_password", "t")
     @browser.type("user_password_confirmation", "t")
     @browser.click_and_wait("link=Create this profile")
  end
  
    
  def test_02_create_new_project
     p "--------------------------------------------------------------------"
     p "     create one brand new project and add all users into team list  "
     p "--------------------------------------------------------------------"
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("link=New project")
     @browser.type("project_name","#{PROJECT_IDENTIFIER}")
     @browser.click_and_wait("create_project")
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/team/list")
     @browser.click("link=Enable enroll all users as team members")
     # @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input[type=submit]")[0]})}
     @browser.click_and_wait(%{dom=this.browserbot.getCurrentWindow().$$("input[type=submit]")[0]})
   end



   def test_03_create_new_card_types
     p "--------------------------------------------------------------------"
     p "                     create new card types                          "
     p "--------------------------------------------------------------------"
     log_in_upgraded_instance_as_admin
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/card_types/list")
     @browser.click_and_wait("link=Create new card type")
     @browser.type("card_type_name","Release")
     @browser.type("card-type-color", "#000000")
     @browser.click_and_wait("link=Create type")
     
     @browser.click_and_wait("link=Create new card type")
     @browser.type("card_type_name","Iteration")
     @browser.type("card-type-color", "#ff8800")
     @browser.click_and_wait("link=Create type")
     
     @browser.click_and_wait("link=Create new card type")
     @browser.type("card_type_name","Story")
     @browser.type("card-type-color", "#09ff00")
     @browser.click_and_wait("link=Create type")
     
     @browser.click_and_wait("link=Create new card type")
     @browser.type("card_type_name","Defect")
     @browser.type("card-type-color", "#ff00a2")
     @browser.click_and_wait("link=Create type")
   end
   
   
   def test_04_create_new_properties
     log_in_upgraded_instance_as_admin
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "priority")
     @browser.click("definition_type_text_list")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "comment")
     @browser.click("definition_type_any_text")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "release_number")
     @browser.click("definition_type_number_list")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "size")
     @browser.click("definition_type_any_number")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "owner")
     @browser.click("definition_type_user")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "start_date")
     @browser.click("definition_type_date")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "double size")
     @browser.click("definition_type_formula")
     @browser.type("property_definition_formula", "size*2")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "related_card")
     @browser.click("definition_type_card_relationship")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "a_locked_property")
     @browser.click("definition_type_number_list")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "a_hidden_property")
     @browser.click("definition_type_any_text")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.click_and_wait("link=Create new card property")
     @browser.type("property_definition_name", "a_transition_only_property")
     @browser.click("definition_type_any_text")
     @browser.click_and_wait("link=Create property")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[3]})}
     @browser.click_and_wait("confirm_hide")
     @browser.assert_text_present("Property a_hidden_property is now hidden.")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[6]})}
     @browser.assert_text_present("Property a_locked_property is now locked")
     
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[9]})}
     @browser.assert_text_present("Property a_transition_only_property can now only be changed through a transition.")
   end
  
  
  def test_05_set_property_values
    get_property_ids
    @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions")
    @browser.click_and_wait("enumeration-values-#{@property_id_of_priority_property}")
    @browser.type("enumeration_value_input_box", "high")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "medium")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "low")
    @browser.click_and_wait("submit-quick-add")
    @browser.click_and_wait("link=Up")
    
    @browser.click_and_wait("enumeration-values-#{@property_id_of_release_number_property}")
    @browser.type("enumeration_value_input_box", "3.0")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "2.3.1")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "2.3")
    @browser.click_and_wait("submit-quick-add")  
    @browser.type("enumeration_value_input_box", "2.2")
    @browser.click_and_wait("submit-quick-add")  
    @browser.type("enumeration_value_input_box", "2.1")
    @browser.click_and_wait("submit-quick-add")
    @browser.click_and_wait("link=Up")
    
    @browser.click_and_wait("enumeration-values-#{@property_id_of_a_locked_property}")
    @browser.type("enumeration_value_input_box", "10")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "15")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "20")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "25")
    @browser.click_and_wait("submit-quick-add")
    @browser.type("enumeration_value_input_box", "30")
    @browser.click_and_wait("submit-quick-add")
 end
 
 def test_06_edit_the_card_defaults
   get_property_ids
   #Release tyep default
   @browser.open ("/projects/#{PROJECT_IDENTIFIER}/card_types/list")
   release_type_defaults_link = (%{dom=this.browserbot.getCurrentWindow().$$(".standard-link-spacing a")[10]})
   @browser.click_and_wait(release_type_defaults_link)
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_option_high")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_comment_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_comment_property}_editor", "release hard")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_comment_property}_editor"
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_option_3.0")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_size_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_size_property}_editor", "10")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_size_property}_editor"
   
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_drop_link")
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_option_mingle_bush")
   
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_drop_link")
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_option_(today)")
   
   # @browser.click("edit_cardrelationshippropertydefinition_#{@property_id_of_related_card_property}_drop_link")
   #    @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$(".select-option")[1]})}
   #    @browser.with_ajax_wait{@browser.click}
      
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_option_10")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor", "hidden release!")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor"
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_label")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor", "release_tra")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor"
   
     
   @browser.click_and_wait("link=Save defaults")
   
   #Card type defaults
   card_type_defaults_link = (%{dom=this.browserbot.getCurrentWindow().$$(".standard-link-spacing a")[1]})
   @browser.click_and_wait(card_type_defaults_link)
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_option_high")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_comment_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_comment_property}_editor", "Plain Card")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_comment_property}_editor"
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_option_2.1")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_size_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_size_property}_editor", "15")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_size_property}_editor"
   
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_drop_link")
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_option_mingle_obama")
   
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_drop_link")
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_option_(today)")

   # @browser.click("edit_cardrelationshippropertydefinition_#{@property_id_of_related_card_property}_drop_link")
   #    @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$(".select-option")[1]})}
   #    @browser.with_ajax_wait{@browser.click}
      
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_option_15")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor", "hidden Card!")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor"
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_label")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor", "card_tra")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor"
   
   @browser.click_and_wait("link=Save defaults")
   
   #Defect type
   defect_type_defaults_link = (%{dom=this.browserbot.getCurrentWindow().$$(".standard-link-spacing a")[4]})
   @browser.click_and_wait(defect_type_defaults_link)
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_option_medium")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_comment_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_comment_property}_editor", "terrible defect")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_comment_property}_editor"
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_option_2.2")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_size_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_size_property}_editor", "20")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_size_property}_editor"
   
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_drop_link")
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_option_mingle_hilton")
   
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_drop_link")
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_option_(today)")

   # @browser.click("edit_cardrelationshippropertydefinition_#{@property_id_of_related_card_property}_drop_link")
   #    @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$(".select-option")[1]})}
   #    @browser.with_ajax_wait{@browser.click}
      
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_option_20")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor", "hidden Defect!")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor"
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_label")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor", "defect_tra")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor"
   
   @browser.click_and_wait("link=Save defaults")
   
   #Iteration type
   iteration_type_defaults_link = (%{dom=this.browserbot.getCurrentWindow().$$(".standard-link-spacing a")[7]})
   @browser.click_and_wait(iteration_type_defaults_link)
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_option_low")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_comment_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_comment_property}_editor", "smooth iteration")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_comment_property}_editor"
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_option_2.2")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_size_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_size_property}_editor", "25")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_size_property}_editor"
   
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_drop_link")
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_option_mingle_tracy")
   
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_drop_link")
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_option_(today)")

   # @browser.click("edit_cardrelationshippropertydefinition_#{@property_id_of_related_card_property}_drop_link")
   #    @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$(".select-option")[1]})}
   #    @browser.with_ajax_wait{@browser.click}
      
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_option_25")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor", "hidden Iteration!")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor"
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_label")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor", "Iteration_tra")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor"
   
   @browser.click_and_wait("link=Save defaults")
   
   
   #Story type
   iteration_type_defaults_link = (%{dom=this.browserbot.getCurrentWindow().$$(".standard-link-spacing a")[13]})
   @browser.click_and_wait(iteration_type_defaults_link)
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_priority_property}_option_high")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_comment_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_comment_property}_editor", "exciting stroy")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_comment_property}_editor"
   
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_release_number_property}_option_2.1")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_size_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_size_property}_editor", "30")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_size_property}_editor"
   
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_drop_link")
   @browser.click("edit_userpropertydefinition_#{@property_id_of_owner_property}_option_(current user)")
   
   
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_drop_link")
   @browser.click("edit_datepropertydefinition_#{@property_id_of_start_date_property}_option_(today)")

   # @browser.click("edit_cardrelationshippropertydefinition_#{@property_id_of_related_card_property}_drop_link")
   #    @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$(".select-option")[1]})}
   #    @browser.with_ajax_wait{@browser.click}
      
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_drop_link")
   @browser.click("edit_enumeratedpropertydefinition_#{@property_id_of_a_locked_property}_option_30")
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_edit_link")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor", "hidden Story!")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_hidden_property}_editor"
   
   @browser.click("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_label")
   @browser.type("edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor", "Story_tra")
   @browser.press_enter "edit_textpropertydefinition_#{@property_id_of_a_transition_only_property}_editor"
   
   @browser.click_and_wait("link=Save defaults")
 end
 
 def test_07_add_cards
   log_in_upgraded_instance_as_admin
   @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards/list")
   
   @browser.select('quick-add-card-type-name', 'Release')
   (1..5).each do |number|
      @browser.type("card_name", "Rlease_#{number}")
      @browser.click("submit-quick-add")
      @browser.wait_for_all_ajax_finished
    end
    
  @browser.select('quick-add-card-type-name', 'Iteration')
  (1..5).each do |number|
     @browser.type("card_name", "Iteration_#{number}")
     @browser.click("submit-quick-add")
     @browser.wait_for_all_ajax_finished
   end
     
   @browser.select('quick-add-card-type-name', 'Defect')
   (1..5).each do |number|
      @browser.type("card_name", "Defect_#{number}")
      @browser.click("submit-quick-add")
      @browser.wait_for_all_ajax_finished
    end
  
    @browser.select('quick-add-card-type-name', 'Story')
    (1..5).each do |number|
       @browser.type("card_name", "Story_#{number}")
       @browser.click("submit-quick-add")
       @browser.wait_for_all_ajax_finished
     end
     
     
    @browser.select('quick-add-card-type-name', 'Card')
    (1..5).each do |number|
       @browser.type("card_name", "Card_#{number}")
       @browser.click("submit-quick-add")
       @browser.wait_for_all_ajax_finished
     end
 end 
 
 def test_08_create_a_new_R_I_S_D_tree
   log_in_upgraded_instance_as_admin
   @browser.open ("/projects/#{PROJECT_IDENTIFIER}/card_trees/list")
   @browser.click_and_wait("link=Create new card tree")
   @browser.type("tree_name", "R_I_S_D tree")

   @browser.click(class_locator('select-type', 0))
   @browser.wait_for_element_visible("type_node_0_container_drop_down")
   @browser.click("type_node_0_container_option_Release")
   @browser.wait_for_element_not_visible("type_node_0_container_drop_down")
   
   @browser.click("#{class_locator('select-type', 1)}")
   @browser.wait_for_element_visible("type_node_1_container_drop_down")
   @browser.click("type_node_1_container_option_Iteration")
   @browser.wait_for_element_not_visible("type_node_1_container_drop_down")

   @browser.click("#{class_locator('add-button', 1)}")
   @browser.click("#{class_locator('add-button', 2)}")


   @browser.click("#{class_locator('select-type', 2)}")
   @browser.wait_for_element_visible("type_node_2_container_drop_down")
   @browser.click("type_node_2_container_option_Story")
   @browser.wait_for_element_not_visible("type_node_2_container_drop_down")
   
   @browser.click("#{class_locator('select-type', 3)}")
   @browser.wait_for_element_visible("type_node_3_container_drop_down")
   @browser.click("type_node_3_container_option_Defect")
   @browser.wait_for_element_not_visible("type_node_3_container_drop_down")
   
   @browser.click_and_wait("link=Save")
 end
 
 private
 
 def css_locator(css, index=0)
   %{dom=this.browserbot.getCurrentWindow().$$(#{css.to_json})[#{index}]}
 end
 
 def class_locator(classname, index=0)
   %{dom=this.browserbot.getCurrentWindow().$$('.#{classname}')[#{index}]}
 end
 
end
