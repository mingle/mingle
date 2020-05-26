# -*- coding: utf-8 -*-

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

# Tags: cards
class CardWysiwygTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  TEAM_MEMBER_PROPERTY = 'user'
  SIZE = 'size'
  STATUS = 'status'
  ITERATION = 'iteration'
  LONG_LINK ='http://localhost:3000/projects/testing/cards/grid?color_by=Type&filters%5B%5D=%5BType%5D%5Bis%5D%5BStory%5D&filters%5B%5D=%5BIteration%5D%5Bis%5D%5B%28Current+Iteration%29%5D&group_by%5Blane%5D=Status&lanes=New%2CIn+Dev%2CTesting%2CDone&tab=Card+Wall'

  def setup
     destroy_all_records(:destroy_users => false, :destroy_projects => true)
      @mingle_admin = users(:admin)
      @project_admin = users(:proj_admin)
      @project_member = users(:project_member)
      @read_only_user = users(:read_only_user)
      @browser = selenium_session
      @project = create_project(:prefix => 'card_wysiwyg_test', :users => [@project_member, users(:longbob)], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
      login_as_admin_user
      open_project(@project)
      # navigate_to_card_list_for(@project)
  end

  def test_content_does_not_double_escape_special_characters
    create_card_for_edit(@project, "new card", :wait => true)
    enter_text_in_editor "[[Modèles métiers]]"
    save_card
    @browser.assert_text_not_present "&egrave;"
    @browser.assert_text_not_present "&eacute;"
  end

  def test_white_spaces_are_respected
    create_card_for_edit(@project, "new card", :wait => true)
    enter_text_in_editor("      this         is a test")
    save_card
    @browser.assert_text_present("      this         is a test")
  end

  # this test works only on firefox
  def test_upload_image_is_inline_and_attached_to_card_when_saved
    if using_firefox?
      card = create_card_for_edit(@project, "new card", :wait => true)
      attachment_1 = "#{File.expand_path(Rails.root)}/test/data/lion.jpg"
      assert File.exist?(attachment_1)
      attach_image(attachment_1)
      assert_mingle_image_tag_present_on_page_edit
      save_card
      assert_mingle_image_tag_present_on_page_show
      @browser.wait_for_element_present("//a[@class='remove-attachment-link']")
      assert_attachment_present('lion.jpg')
      assert_history_for(:card, card.number).version(2).shows(:attachment_added => attachment_1)
    end
  end

  def test_card_keywords_render_as_links_and_are_case_insensitive
    navigate_to_card_keywords_for(@project)
    type_project_card_keywords('#,card,story,bug')
    click_update_keywords_link
    create_card_for_edit(@project, "card1", :wait => true)
    enter_text_in_editor("this is card 1 and story1 BUG 1, test 1, #1")
    save_card
    assert_link_to_card_present(@project, 1)
    should_see_link_in_renderable_content("card 1", "story1", "BUG 1", "#1")
    should_not_see_link_in_renderable_content("test 1")
  end

  def test_attachment_links_inline
    if using_firefox?
      card1 = create_card_for_edit(@project, "card1", :wait => false)
      attachment_1 = "#{File.expand_path(Rails.root)}/test/data/lion.jpg"

      assert File.exist?(attachment_1)
      attach_image(attachment_1)
      assert_mingle_image_tag_present_on_page_edit
      save_card
      @browser.wait_for_element_present("//a[@class='remove-attachment-link']")
      navigate_to_card_list_for(@project)
      create_card_for_edit(@project, "card2", :wait => false)
      enter_text_in_editor("[[##{card1.number}/lion.jpg]]")
      save_card
      @browser.assert_element_present("link=##{card1.number}/lion.jpg")
    end
  end

  def test_sourcearea_button_present
    create_card_for_edit(@project, "card1", :wait => true)
    @browser.assert_element_present("link=Source")
  end

  def test_page_links_inline
    create_new_wiki_page(@project, "Wiki", "wiki contents")
    navigate_to_card_list_for(@project)
    create_card_for_edit(@project, "card")
    enter_text_in_editor("existing wiki [[Wiki]] and there is no wiki page by name [[new wiki]]")
    save_card
    @browser.assert_element_present("link=Wiki")
    @browser.assert_element_present("link=new wiki")
    @browser.assert_element_present("//a[@class='non-existent-wiki-page-link']")
  end

  def test_cross_project_link
    project_2 = create_project(:prefix => "another project")
    project_2_card = project_2.cards.create!(:name => "card on project2", :card_type_name => "Card")
    expected_cross_project_link = "#{project_2.identifier}/##{project_2_card.number}"

    open_project(@project)
    @project.with_active_project do |project|
      @browser.open("/projects/#{@project.identifier}/cards/new")
      type_card_name("card on project1")
      enter_text_in_editor(expected_cross_project_link)
      save_card
      navigate_to_card_list_for(project)
      open_card(project, project.cards.find_by_name('card on project1'))
    end

    @browser.assert_element_present("link=#{expected_cross_project_link}")
    @browser.click_and_wait("link=#{expected_cross_project_link}")
    assert_card_name_in_show("card on project2")
  end
  #bug 999
  def test_link_in_description_should_be_confined_within_the_descriptor_box
    create_card_for_edit(@project, "new card", :wait => true)
    enter_text_in_editor LONG_LINK
    save_card
    @browser.assert_element_style_property_value(".card-content-container a", "word-wrap", "break-word");

  end

end
