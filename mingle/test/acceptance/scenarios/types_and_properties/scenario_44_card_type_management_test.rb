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

# Tags: scenario, properties, card-type, #2287
class Scenario44CardTypeManagementTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  BUGSTATUS = 'bug status'
  RELEASE = 'release'
  STORYSTATUS = 'story status'
  PRIORITY = 'priority'
  OWNER ='owner'
  DATE_PROPERTY = 'closed on'
  STORY = 'Story'

  NAME_ALREADY_TAKEN = 'Name has already been taken'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project_without_properties = create_project(:prefix => 'scenario_44', :users => [@non_admin_user], :admins => [@project_admin_user])
    @project = create_project(:prefix => 'scenario_44', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(BUGSTATUS => ['new', 'asigned', 'closed'], RELEASE => ['1.0', '1.1'], STORYSTATUS => ['in analysis', 'in dev', 'dev complete'], PRIORITY => ['high','low','medium'] )
    login_as_proj_admin_user
  end

  def test_can_create_card_types_with_various_characters_in_the_name
    variety_of_type_names = ['"double quotes"', 'ALLCAPS', 'Capitalized', 'CamelCase', 'moreCamelCase', 'has space', 'with, comma', 'with-hyphen',
                             'Release=new', 'with & symbol', 'Release #', 'foo / bar', 'SELECT * FROM card_types', '[square] brackets', '+ estimate']

    navigate_to_card_type_management_for(@project)
    variety_of_type_names.each do |name|
      create_card_type_for_project(@project, name, :properties => [BUGSTATUS, PRIORITY])
      assert_notice_message("Card Type #{name} was successfully created", :escape => true)
    end
  end

  def test_at_least_one_card_should_be_present_and_should_be_renamable_and_nonremovabel
    navigate_to_card_type_management_for(@project)
    assert_card_type_present_on_card_type_management_page("Card") #assert default card type'Card' present
    assert_card_type_can_be_edited(@project,'Card') #assert card type 'Card' can be edited
    assert_card_type_cannot_be_deleted(@project, 'Card')
  end

  def test_duplicate_card_type_name_not_allowed
    original_type_name = 'Bug'
    navigate_to_card_type_management_for(@project)
    create_card_type_for_project(@project, original_type_name)
    card = create_card!(:name => 'card of type', :type => original_type_name)

    create_card_type_for_project(@project, original_type_name)
    assert_error_message(NAME_ALREADY_TAKEN)
    create_card_type_for_project(@project, 'bug')
    assert_error_message(NAME_ALREADY_TAKEN)
    create_card_type_for_project(@project, 'bUG')
    assert_error_message(NAME_ALREADY_TAKEN)
    create_card_type_for_project(@project, 'BUG')
    assert_error_message(NAME_ALREADY_TAKEN)

    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {'Type' => original_type_name})
    assert_history_for(:card, card.number).version(1).does_not_show(:set_properties => {'Type' => original_type_name.downcase})
    assert_history_for(:card, card.number).version(1).does_not_show(:set_properties => {'Type' => original_type_name.upcase})
    assert_history_for(:card, card.number).version(1).does_not_show(:set_properties => {'Type' => 'bUG'})
    assert_history_for(:card, card.number).version(2).not_present
  end

  def test_card_type_cannot_be_blank
    navigate_to_card_type_management_for(@project)
    create_card_type_for_project(@project, '')
    assert_error_message("Name can't be blank")
  end

  def test_card_type_can_be_created_without_properties
    navigate_to_card_type_management_for(@project)
    create_card_type_for_project(@project, STORY, :properties => [])
    assert_card_type_present(@project, STORY)
    assert_notice_message("Card Type #{STORY} was successfully created")
    assert_text_present('0 properties, 0 cards, 0 card trees')
  end

  def test_card_type_cannot_be_deleted_when_associated_with_a_card
    edit_card_type_for_project(@project, 'Card', :new_card_type_name => 'Bug', :properties => [BUGSTATUS, RELEASE])
    create_card_type_for_project(@project, STORY, :properties => [STORYSTATUS, RELEASE])
    create_new_card(@project, :name => 'Bug1',:type => 'Bug', :'bug status' => 'asigned', :release => '1.0')
    create_new_card(@project, :name => 'Story1', :type => STORY, :'story status' => 'in dev', :release => '1.1')
    navigate_to_card_type_management_for(@project)
    assert_text_present('2 properties, 1 card')
    assert_card_type_cannot_be_deleted(@project, STORY)
    assert_card_type_cannot_be_deleted(@project, 'Bug')
  end

  def test_all_properties_available_for_card_type
    navigate_to_card_type_management_for(@project)
    open_create_new_card_type_page(@project)
    assert_all_properties_available_for_card_type(@project, :properties => [BUGSTATUS, RELEASE, STORYSTATUS, PRIORITY])
    create_property_definition_for(@project, OWNER)
    open_create_new_card_type_page(@project)
    assert_all_properties_available_for_card_type(@project, :properties => [BUGSTATUS, RELEASE, STORYSTATUS, PRIORITY, OWNER])
  end

  def test_card_type_remembers_its_properties
    edit_card_type_for_project(@project, 'Card', :new_card_type_name => 'Bug', :properties => [BUGSTATUS, RELEASE, PRIORITY])
    create_card_type_for_project(@project, STORY, :properties => [STORYSTATUS, RELEASE])
    open_edit_card_type_page(@project, 'Bug')
    assert_properties_selected_for_card_type(@project, BUGSTATUS, RELEASE, PRIORITY)
    open_edit_card_type_page(@project,STORY)
    assert_properties_selected_for_card_type(@project, STORYSTATUS, RELEASE)
  end

  def test_properties_are_ordered_when_in_create_card_type_screen
    project = @project.identifier if @project.respond_to? :identifier
    open_create_new_card_type_page(@project)
    bugstatus = Project.find_by_identifier(project).find_property_definition_or_nil(BUGSTATUS)
    priority = Project.find_by_identifier(project).find_property_definition_or_nil(PRIORITY)
    release = Project.find_by_identifier(project).find_property_definition_or_nil(RELEASE)
    storystatus = Project.find_by_identifier(project).find_property_definition_or_nil(STORYSTATUS)
    assert_ordered("card_type_property_row_#{bugstatus.id}", "card_type_property_row_#{priority.id}", "card_type_property_row_#{release.id}", "card_type_property_row_#{storystatus.id}")
  end

  # bug 2287
  def test_link_to_property_management_page_works_when_project_has_no_properties
    navigate_to_card_type_management_for(@project_without_properties)
    click_add_card_type_link
    @browser.click_and_wait("link=Return to card properties list")
    @browser.assert_text_present "There are currently no card properties to list."
    @browser.assert_location("/projects/#{@project_without_properties.identifier}/property_definitions")
  end

  # bug 2749
  def test_non_admin_project_team_member_cannot_create_card_type
    logout
    login_as(@non_admin_user.login, 'longtest')
    navigate_to_card_list_for(@project)
    new_card_type = 'TASK'
    card_name = 'shouldnt exist'
    card_number = '58'
    header_row = ['Number', 'Name', 'type']
    card_data = [[card_number, card_name, new_card_type]]
    preview(excel_copy_string(header_row, card_data), :failed => true)
    # need to figure out how to assert this error message
    # error_message = "Card type #{new_card_type} does not exist. Please change card types or contact your project administrator to create this card type."
    # preview(excel_copy_string(header_row, card_data), :failed => true, :error_message => error_message)
    navigate_to_card_type_management_for(@project)
    assert_card_type_not_present_on_card_type_management_page(new_card_type)
    open_card(@project, card_number)
    assert_error_message("Card #{card_number} does not exist.")
  end

  def test_non_admin_project_team_member_cannot_create_card_type2
    logout
    login_as("#{@non_admin_user.login}", 'longtest')
    navigate_to_card_type_management_for(@project)
    @browser.assert_element_not_present('link=Create new card type')
    @browser.open("/projects/#{@project.identifier}/card_types/new")
    assert_cannot_access_resource_error_message_present
  end

  #bug 2776
  def test_can_create_and_edit_card_type_when_project_has_no_properties
    type_without_properties_name = 'new card type'
    project_without_properties = create_project(:prefix => 'scenario_44_no_props', :users => [@non_admin_user], :admins => [@project_admin_user])
    open_create_new_card_type_page(project_without_properties)
    type_card_type_name(type_without_properties_name)
    click_create_card_type
    assert_notice_message("Card Type #{type_without_properties_name} was successfully created")

    new_name_for_type = 'updated name'
    open_edit_card_type_page(project_without_properties, type_without_properties_name)
    type_card_type_name(new_name_for_type)
    save_card_type
    assert_notice_message("Card Type #{new_name_for_type} was successfully updated")
  end

  # bug 2791
  def test_cannot_update_card_type_by_giving_it_name_of_another_existing_type_despite_case
    bug_type_name = 'Bug'
    story_type_name_upcased = STORY.upcase

    create_card_type_for_project(@project, STORY)
    create_card_type_for_project(@project, bug_type_name)

    bug_card = create_card!(:name => 'Bug card', :type => bug_type_name)
    story_card = create_card!(:name => 'story card', :type => STORY)

    open_edit_card_type_page(@project, bug_type_name)
    type_card_type_name(story_type_name_upcased)
    save_card_type
    assert_error_message(NAME_ALREADY_TAKEN)

    @browser.run_once_history_generation
    open_card(@project, bug_card.number)
    assert_history_for(:card, bug_card.number).version(1).shows(:set_properties => {'Type' => bug_type_name})
    assert_history_for(:card, bug_card.number).version(1).does_not_show(:set_properties => {'Type' => story_type_name_upcased})
    assert_history_for(:card, bug_card.number).version(2).not_present

    open_edit_card_type_page(@project, bug_type_name)
    type_card_type_name(STORY)
    save_card_type
    assert_error_message(NAME_ALREADY_TAKEN)
    open_card(@project, bug_card.number)
    assert_history_for(:card, bug_card.number).version(1).shows(:set_properties => {'Type' => bug_type_name})
    assert_history_for(:card, bug_card.number).version(1).does_not_show(:set_properties => {'Type' => STORY})
    assert_history_for(:card, bug_card.number).version(2).not_present
  end

  # bug 2792
  def test_duplicate_card_type_name_message_does_not_persist
    original_type_name = 'Bug'
    navigate_to_card_type_management_for(@project)
    create_card_type_for_project(@project, original_type_name)
    card = create_card!(:name => 'card of type', :type => original_type_name)

    create_card_type_for_project(@project, original_type_name)
    assert_error_message(NAME_ALREADY_TAKEN)
    click_all_tab
    assert_error_message_not_present
    @browser.assert_text_not_present(NAME_ALREADY_TAKEN)
  end

  # bug 2852
  def test_can_rename_card_type_that_is_associated_to_hidden_properties
    original_card_type_name = 'bug'
    new_card_type_name = 'defect'
    setup_date_property_definition(DATE_PROPERTY)
    setup_card_type(@project, original_card_type_name, :properties => [DATE_PROPERTY, BUGSTATUS])
    card = create_card!(:name => 'testing', :type => original_card_type_name)
    hide_property(@project, DATE_PROPERTY)
    edit_card_type_for_project(@project, original_card_type_name, :new_card_type_name => new_card_type_name)
    assert_notice_message("Card Type #{new_card_type_name} was successfully updated")
    open_card(@project, card.number)
    assert_card_type_set_on_card_show(new_card_type_name)
  end

  # bug 3351
  def test_can_remove_property_associations_from_card_type
    story_card_type = setup_card_type(@project, STORY, :properties => [STORYSTATUS, PRIORITY])
    open_edit_card_type_page(@project, story_card_type)
    uncheck_properties_required_for_card_type(@project, [STORYSTATUS])
    save_card_type
    @browser.assert_text_present("This update will remove property #{STORYSTATUS} from card type #{story_card_type.name}.")
    click_continue_to_update
    assert_notice_message("Card Type #{story_card_type.name} was successfully updated")
    open_edit_card_type_page(@project, story_card_type)
    uncheck_properties_required_for_card_type(@project, [PRIORITY])
    save_card_type
    @browser.assert_text_present("This update will remove property #{PRIORITY} from card type #{story_card_type.name}.")
    click_continue_to_update
    assert_notice_message("Card Type #{story_card_type.name} was successfully updated")
  end

  # bug 3367
  def test_can_remove_property_associations_from_card_type_in_template
    logout
    login_as_admin_user
    story_card_type = setup_card_type(@project, STORY, :properties => [STORYSTATUS, PRIORITY])
    @project.reload
    navigate_to_all_projects_page
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    open_edit_card_type_page(project_template, STORY)
    uncheck_properties_required_for_card_type(project_template, [STORYSTATUS])
    save_card_type
    @browser.assert_text_present("This update will remove property #{STORYSTATUS} from card type #{story_card_type.name}.")
    click_continue_to_update
    assert_notice_message("Card Type #{story_card_type.name} was successfully updated")
    open_edit_card_type_page(project_template, STORY)
    uncheck_properties_required_for_card_type(project_template, [PRIORITY])
    save_card_type
    @browser.assert_text_present("This update will remove property #{PRIORITY} from card type #{story_card_type.name}.")
    click_continue_to_update
    assert_notice_message("Card Type #{story_card_type.name} was successfully updated")
  end

  # bug 3235
  def test_notice_message_for_updating_card_types_escapes_html
    name_with_html_tags = "foo <b>BAR</b>"
    same_name_without_html_tags = "foo BAR"
    type_with_html_in_name = setup_card_type(@project, name_with_html_tags)
    open_edit_card_type_page(@project, type_with_html_in_name)
    type_card_type_name(name_with_html_tags)
    save_card_type
    assert_notice_message("Card Type #{name_with_html_tags} was successfully updated")
    assert_notice_message_does_not_match("Card Type #{same_name_without_html_tags} was successfully updated")
  end

  # bug 5337
  def test_exitsting_name_error_message_should_not_unselect_properties_when_creating_new_card_type
    duplicated_card_type = 'card'
    create_card_type_for_project(@project, duplicated_card_type, :properties => [STORYSTATUS, RELEASE])
    assert_error_message("Name has already been taken")
    assert_properties_selected_for_card_type(@project, STORYSTATUS, RELEASE)
    assert_properties_not_selected_for_card_type(@project, BUGSTATUS, PRIORITY)
  end

  # Bug 7624
  def test_should_be_able_to_cancel_deletion_of_card_type
    create_card_type_for_project(@project, RELEASE)
    get_the_delete_confirm_message_for_card_type(@project, RELEASE)
    click_cancle_deletion
    @browser.assert_location("/projects/#{@project.identifier}/card_types/list")
    assert_card_type_present_on_card_type_management_page(RELEASE)
  end

  # Story 12754 -quick add on funky tray
  def test_should_be_able_to_quick_add_card_on_project_admin_page
    navigate_to_card_type_management_for(@project)
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card")
    @browser.wait_for_element_visible("notice")
    card = find_card_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created.", :escape => true)
  end
end
