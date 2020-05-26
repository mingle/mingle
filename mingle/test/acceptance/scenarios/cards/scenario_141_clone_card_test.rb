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

#Tags: cards, clone_card

class Scenario141CloneCardTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  RELATION_PROPERTY = 'relationship property'
  AGGREGATE_PROPERTY = 'aggregate property'
  FORMULAR_PROPERTY = 'planning size'
  CARD_TYPE_PROPERTY = 'iteration'
  USER_PROPERTY = 'owner'
  MANAGED_TEXT_PROPERTY = 'managed text'

  STORY = 'story'
  CARD = 'Card'
  COUNT = 'Count'

  REALATON  = 'cs Tree'
  SIZE = 'size'

  COMMENT = "I want to copy this card"
  DESCRIPTION = 'card description'
  TAG = ['copy card']
  NOTSET = '(not set)'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    @browser = selenium_session
    login_as_admin_user

    @project1 = create_project(:prefix => 'project1', :users => [users(:project_member)])
    @project2 = create_project(:prefix => 'project2', :admins => [users(:project_member)])
    setup_card_type(@project1, 'Story')
    setup_card_type(@project2, 'STORY')
    @project = create_project(:prefix => 'scenario_141', :admins => [users(:proj_admin)], :users => [users(:project_member), users(:longbob)], :read_only_users => [users(:read_only_user)])
    setup_card_type(@project, 'story')
    @card = create_card!(:name => 'test story', :type => 'story')
    @card1 = create_card!(:name => 'test card',:type => 'Card')
  end

  #bug 7199
  def test_project_memeber_should_not_be_able_to_copy_property_value_which_doesnot_exist_in_target_project_and_the_property_is_locked
    two_projects_has_same_managed_text_property([@project, @project1], MANAGED_TEXT_PROPERTY)
    create_enumeration_value_for(@project, MANAGED_TEXT_PROPERTY, "some")
    lock_property(@project1, MANAGED_TEXT_PROPERTY)
    @project.activate
    open_card(@project, @card1)
    set_properties_on_card_show(MANAGED_TEXT_PROPERTY => "some")
    login_as_project_member
    open_card(@project, @card1)
    choose_a_project_and_continue_to_copy_card(@project1)
    assert_info_box_light_message("Property value for #{MANAGED_TEXT_PROPERTY} will not be copied because the requisite value does not exist in #{@project1.name} and the property is locked.", :id => "confirm-copy-div")
  end

  def test_relationship_property_should_not_be_copied
    login_as_admin_user
    open_a_card_in_tree(@project,@card,RELATION_PROPERTY,AGGREGATE_PROPERTY)
    choose_a_project_and_continue_to_copy_card(@project1)
    should_see_warning_message_the_relationship_property_will_not_be_copied(RELATION_PROPERTY)
  end

  def test_aggregate_property_should_not_be_copied
    login_as_admin_user
    open_a_card_in_tree(@project,@card1,RELATION_PROPERTY,AGGREGATE_PROPERTY)
    choose_a_project_and_continue_to_copy_card(@project1)
    should_see_warning_message_the_aggregate_will_not_be_copied(AGGREGATE_PROPERTY)
  end



  def test_admin_full_read_only_user_can_clone_card
    Outline(<<-Examples) do | user_name      |
      | admin          |
      | proj_admin     |
      | member         |
      | read_only_user |
      Examples
      login_as user_name
      open_card(@project,@card)
      should_see_clone_card_link
    end
  end

  def test_light_user_can_not_clone_card

    light_user = create_user!(:name => 'light', :login => 'light', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD)
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(light_user)
    add_readonly_member_to_team_for(@project,light_user)
    login_as(light_user.login)
    open_card(@project,@card)
    should_not_see_clone_card_link

  end

  def test_anonymous_user_can_not_clone_card
      enable_anonymous_access_for_project(@project)
      open_card(@project,@card)
      should_not_see_clone_card_link

  end

  private
  def two_projects_has_same_managed_text_property(projects, managed_text_property_name, values=[])
     projects.each do |project|
       project.activate
       @card_type = Project.find_by_identifier(project.identifier).card_types.find_by_name(CARD) unless CARD.respond_to?(:name)
       property = create_managed_text_list_property(managed_text_property_name, values)
       add_properties_for_card_type(@card_type,[property])
     end
   end

   def open_a_card_in_tree(project,card,relationship_property_name,aggregate_property_name)
     @story_type = Project.find_by_identifier(project.identifier).card_types.find_by_name(STORY) unless STORY.respond_to?(:name)
     @card_type = Project.find_by_identifier(project.identifier).card_types.find_by_name(CARD) unless CARD.respond_to?(:name)
     @tree = setup_tree(project, 'test tree', :types => [@card_type,@story_type],:relationship_names => [relationship_property_name])
     create_aggregate_property_for(project, aggregate_property_name, @tree, @card_type, :scope => @story_type.name,:aggregation_type => COUNT)
     add_card_to_tree(@tree, card)
     open_card(project,card.number)
   end


end
