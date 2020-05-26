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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: cards, linking, cross_project
class Scenario136CrossProjectLinkingTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  PROJECTS_KEYWORD = 'first'
  PROJECT_FULL_MEMBERS_KEYWORD = 'fullmember'
  PROJECT_READ_ONLY_KEYWORD = 'readonly'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_proj_admin_user
    @project = create_project(:prefix => 'scenario_136', :admins => [users(:proj_admin)], :users => [users(:project_member)])
    @project.update_attributes(:card_keywords => "#, #{PROJECTS_KEYWORD}")           
    @project_full_member = create_project(:prefix => 'full_member', :admins => [users(:proj_admin)], :users => [users(:project_member)])
    @project_full_member.update_attributes(:card_keywords => "#, #{PROJECT_FULL_MEMBERS_KEYWORD}")  
    @project_read_only = create_project(:prefix => 'read_only', :admins => [users(:proj_admin)], :read_only_users => [users(:project_member)])
    @project_read_only.update_attributes(:card_keywords => "#, #{PROJECT_READ_ONLY_KEYWORD}")       
    @project_not_member = create_project(:prefix => 'not_member', :admins => [users(:proj_admin)])         
  end

  #bug 8674
  def test_should_not_get_confused_by_urls_which_accidentally_look_like_cross_project_links
    @project.with_active_project do
      link_text = "http://foo.bar/#{@project_full_member.identifier}/tab/build/sf02/build/1/rails"
      card = @project.cards.create!(
      :name => 'card with a link', 
      :card_type_name => 'card', 
      :description => link_text)
      open_card(@project, card)
      assert_link_present link_text
    end
  end

  # bug 7074
  def test_card_link_between_two_inline_images_should_be_generated
    tartget_project = @project_full_member
    target_card = create_cards(tartget_project, 1)[0] 
    link_text = "* [[#{tartget_project.identifier}/non_existing_image1.png]]\\n* #{tartget_project.identifier}/#{PROJECT_FULL_MEMBERS_KEYWORD} #{target_card.number}\\n* [[#{tartget_project.identifier}/non_existing_image2.png]]"
    login_as_project_member
    open_project(@project.identifier)    
    edit_overview_page
    type_page_content(link_text)
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a",1))
    assert_card_location_in_card_show(tartget_project, target_card)     
  end


  # linking to card 
  def test_happy_path_for_linking_to_card
    tartget_project = @project_full_member
    target_card = create_cards(tartget_project, 1)[0]
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("#{tartget_project.identifier}/#{PROJECT_FULL_MEMBERS_KEYWORD} #{target_card.number}")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_card_location_in_card_show(tartget_project, target_card)
  end

  # unhappy path for linking to card
  def test_clicking_on_link_to_a_none_existing_card_should_give_error_message
    login_as_project_member
    target_project = @project_full_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("#{target_project.identifier}/#{PROJECT_FULL_MEMBERS_KEYWORD} 1000")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_error_message("Card 1000 does not exist.")
  end

  def test_linking_to_card_using_wrong_keyword_for_target_project_but_happens_apply_for_current_project
    login_as_project_member
    card_in_current_project = create_cards(@project, 1)[0]
    target_project = @project_full_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("#{target_project.identifier}/#{PROJECTS_KEYWORD} 1")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_card_location_in_card_show(@project, card_in_current_project)
  end

  def test_linking_to_card_when_card_keyword_does_not_exit
    login_as_project_member
    target_project = @project_full_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("#{target_project.identifier}/#{PROJECT_READ_ONLY_KEYWORD} 1")
    with_ajax_wait { click_save_link }
    @browser.assert_element_not_present(css_locator("div#page-content a"))
  end

  def test_linking_to_card_which_user_does_not_have_right_to_access_to
    login_as_project_member
    target_project = @project_not_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("#{target_project.identifier}/# 1")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_error_message("Either the resource you requested does not exist or you do not have access rights to that resource.")
  end

  def test_linking_to_card_should_be_case_insensitive_to_keywords
    login_as_project_member
    target_project = @project_full_member
    target_card = create_cards(target_project, 1)[0]
    open_project(@project.identifier)
    edit_overview_page
    keyword_in_capital = PROJECT_FULL_MEMBERS_KEYWORD.upcase
    type_page_content("#{target_project.identifier}/#{keyword_in_capital} 1")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_card_location_in_card_show(target_project, target_card)
  end

  # linking to page
  def test_happy_path_for_linking_to_page
    target_project = @project_full_member
    target_page_name = "existing page"
    create_new_wiki_page(target_project, target_page_name, 'bla bla')
    target_page_identifier = Page.find_by_name(target_page_name).identifier
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    @browser.assert_location("/projects/#{target_project.identifier}/wiki/#{target_page_identifier}")
    @browser.assert_element_not_present("page_form") 
  end

  # unhappy path for linking to page   
  def test_linking_to_non_existent_page
    tartget_project = @project_full_member
    target_page_identifier = "not_existing_page"
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{tartget_project.identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    @browser.assert_location("/projects/#{tartget_project.identifier}/wiki/#{target_page_identifier}") 
    @browser.assert_element_present("page_form")
  end

  def test_linking_read_only_user_to_non_exitent_page
    tartget_project = @project_read_only
    target_page_identifier = "not_existing_page"
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{tartget_project.identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_error_message("Read only team members do not have access rights to create pages")
  end

  def test_linking_to_page_user_does_not_have_right_to_read
    tartget_project = @project_not_member
    target_page_identifier = "not_existing_page"
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{tartget_project.identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    assert_error_message("Either the resource you requested does not exist or you do not have access rights to that resource.")
  end

  def test_linking_to_page_when_the_project_does_not_exit
    tartget_project_identifier = "non_existing_project"
    target_page_identifier = "not_existing_page"
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{tartget_project_identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(class_locator("error_link"))         
  end

  def test_cross_project_card_link_should_work_on_commet
    tartget_project = @project_full_member
    target_card = create_cards(tartget_project, 1)[0] 
    card_to_be_commented = create_cards(@project, 1)[0] 
    open_card(@project, card_to_be_commented.number)
    add_comment("#{tartget_project.identifier}/# #{target_card.number}")
    @browser.click_and_wait(css_locator("div#discussion a"))
    assert_card_location_in_card_show(tartget_project, target_card)
  end

  def test_happy_path_for_linking_to_card_attachment
    target_project = @project_full_member
    target_project.activate
    target_attachment = "1.jpg"
    target_card = create_card!(:name => 'sample card', :attachments => [target_attachment])
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/# #{target_card.number}/#{target_attachment}]]")
    with_ajax_wait { with_ajax_wait { click_save_link } }
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))
  end

  def test_happy_path_for_linking_to_page_attachment
    target_project = @project_full_member
    target_page_name = "page with attachment"
    target_attachment = 'attachment.jpg'
    attachment = Attachment.create!(:file => sample_attachment(target_attachment), :project => target_project)    
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    attach_file_on_page(target_page, target_attachment)
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/# #{target_page.identifier}/#{target_attachment}]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))
  end

  def test_linking_to_page_attachment_when_wrong_attachment_name
    target_project = @project_full_member
    target_page_name = "page without attachment"
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/# #{target_page.identifier}/not_existing_attachment.jpg]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(class_locator("error_link"))      
  end

  def test_linking_to_card_attachment_when_wrong_project_id
    target_project = @project_full_member
    target_page_name = "page with attachment"
    target_attachment = 'attachment.jpg'
    attachment = Attachment.create!(:file => sample_attachment(target_attachment), :project => target_project)    
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    attach_file_on_page(target_page, target_attachment)
    open_project(@project)
    edit_overview_page
    type_page_content("[[wrong_project_identifier/# #{target_page.identifier}/#{target_attachment}]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))    
  end

  def test_linking_to_page_attachment_when_wrong_page_name
    target_project = @project_full_member
    target_page_name = "page with attachment"
    target_attachment = 'attachment.jpg'
    attachment = Attachment.create!(:file => sample_attachment(target_attachment), :project => target_project)    
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    attach_file_on_page(target_page, target_attachment)
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/wrong_page_name/#{target_attachment}]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))
  end

  # case sensitive
  def test_linking_to_page_should_be_case_insensitive_to_page_name
    tartget_project = @project_full_member
    target_page_name = "existing page"
    create_new_wiki_page(tartget_project, target_page_name, 'bla bla')
    target_page_identifier = Page.find_by_name(target_page_name).identifier.upcase    
    login_as_project_member
    open_project(@project.identifier)
    edit_overview_page
    type_page_content("[[#{tartget_project.identifier}/#{target_page_identifier}]]")
    with_ajax_wait { click_save_link }
    @browser.click_and_wait(css_locator("div#page-content a"))
    @browser.assert_location("/projects/#{tartget_project.identifier}/wiki/#{target_page_identifier}")
    @browser.assert_element_not_present("page_form")
  end

  def test_linking_to_page_attachment_should_be_case_insensitive_to_page_name
    target_project = @project_full_member
    target_page_name = "page without attachment"
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier}/# #{target_page.identifier.upcase }/not_existing_attachment.jpg]]")
    with_ajax_wait { click_save_link }
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))
  end

  #bug #8066 project identifier is case sensitive in cross project linking
  def test_project_identifier_should_not_be_case_sensitive_when_link_to_a_page_attachment
    target_project = @project_full_member
    target_page_name = "page with attachment"
    target_attachment = 'attachment.jpg'
    attachment = Attachment.create!(:file => sample_attachment(target_attachment), :project => target_project)    
    create_new_wiki_page(target_project, target_page_name, "content")
    target_page = target_project.pages.find_by_name(target_page_name)
    attach_file_on_page(target_page, target_attachment)
    open_project(@project)
    edit_overview_page
    type_page_content("[[#{target_project.identifier.upcase}/#{target_page.identifier}/#{target_attachment}]]")
    with_ajax_wait { click_save_link } 
    @browser.assert_element_present(css_locator("div#page-content a"))
    @browser.assert_element_not_present(class_locator("non-existent-wiki-page-link"))
  end  
end
