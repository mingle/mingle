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

# Tags: cards, linking
class Scenario162LinkingSubsitutionOnCardCommentTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access

  EXTERNAL_LINK = "http://www.google.com"
  EMAIL_LINK = "bob@email.com"
  CARD_NUMBER = "1"
  PAGE_NAME = "new page"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_proj_admin_user
    @project = create_project(:prefix => 'scenario_162', :admins => [users(:proj_admin)], :users => [users(:project_member)])
    @attachment = 'attachment.jpg'
    @card = create_card!(:name => 'sample card', :attachments => [@attachment])
    @another_project = create_project(:prefix => 'scenario_162', :admins => [users(:proj_admin)], :users => [users(:project_member)])   
  end

  def test_external_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment(EXTERNAL_LINK)
    assert_url_shown_as_link_on_comment(EXTERNAL_LINK) 

    add_comment(EMAIL_LINK)
    assert_url_shown_as_link_on_comment("mailto:#{EMAIL_LINK}")   
  end

  def test_internal_card_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment("##{CARD_NUMBER}")
    assert_url_shown_as_link_on_comment("/projects/#{@project.identifier}/cards/#{CARD_NUMBER}")    
  end

  def test_internal_wiki_link_be_shown_as_link_on_comment
    create_new_wiki_page(@project, PAGE_NAME, 'bla bla')
    open_card(@project, 1)
    add_comment("[[#{PAGE_NAME}]]")
    assert_url_shown_as_link_on_comment("/projects/#{@project.identifier}/wiki/#{PAGE_NAME.gsub(" ","_")}")    
  end

  def test_internal_new_wiki_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment("[[#{PAGE_NAME}]]")
    assert_url_shown_as_link_on_comment("/projects/#{@project.identifier}/wiki/#{PAGE_NAME.gsub(" ","_")}")    
    assert_link_with_a_red_cross_present_on_comment
  end

  def test_internal_attachment_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment("[[##{CARD_NUMBER}/#{@attachment}]]")
    @browser.assert_element_present(css_locator("#discussion div.comment a"))
  end

  def test_not_existing_attachment_link_be_show_as_error_link_on_comment
    open_card(@project, 1)
    add_comment("[[#{PAGE_NAME}/#{@attachment}]]")
    assert_red_error_link_present_on_comment
  end

  def test_cross_project_card_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment("#{@another_project.identifier}/##{CARD_NUMBER}")
    assert_url_shown_as_link_on_comment("/projects/#{@another_project.identifier}/cards/#{CARD_NUMBER}")        
  end

  def test_cross_project_wiki_link_be_shown_as_link_on_comment
    create_new_wiki_page(@project, PAGE_NAME, 'bla bla')
    open_card(@project, 1)
    add_comment("[[#{@another_project.identifier}/#{PAGE_NAME}]]")
    assert_url_shown_as_link_on_comment("/projects/#{@another_project.identifier}/wiki/#{PAGE_NAME.gsub(" ","_")}")    
  end

  def test_cross_project_attachment_link_be_shown_as_link_on_comment
    open_card(@project, 1)
    add_comment("[[#{@another_project.identifier}/##{CARD_NUMBER}/#{@attachment}]]")
    @browser.assert_element_present(css_locator("#discussion div.comment a"))
  end

end

