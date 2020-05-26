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

# Tags: scenario, properties, cards, card-type, defaults_2
class Scenario61CardDefaultsUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  DEFECT = 'defect'
  STORY = 'story'
  RELEASE = 'release'

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  LOW = 'low'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  VALUE_FOR_FREE_TEXT_PROPERTY = 'some value for free text'
  BLANK = ''
  NOT_SET = '(not set)'
  CURRENT_USER = '(current user)'
  TODAY = '(today)'

  ADMIN_NAME_TRUNCATED = "admin@emai..."
  PROJ_ADMIN_NAME_TRUNCATED = "proj_admin..."
  PROJECT_MEMBER_NAME_TRUNCATED = "member@ema..."

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_61', :admins => [@project_admin], :users => [@admin, @project_member])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [HIGH, LOW])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    login_as_admin_user
    @project.time_zone = ActiveSupport::TimeZone.new("London").name
    @project.save!
  end

  def test_quick_add_card_with_only_type_set_in_property_filter_sets_type_defaults
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    default_description = "requirements & such"
    type_description_defaults(default_description)
    set_property_defaults(@project, STATUS => NEW, USER_PROPERTY => @admin.name, DATE_PROPERTY => TODAY)
    click_save_defaults
    card_number = add_card_via_quick_add('Story with defaults set', :type => STORY)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_card_or_page_content_in_edit(default_description)
    assert_properties_set_on_card_edit(STATUS => NEW, USER_PROPERTY => ADMIN_NAME_TRUNCATED, DATE_PROPERTY => today_in_project_format)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => NEW, USER_PROPERTY => @admin.name, DATE_PROPERTY => today_in_project_format})
    assert_history_for(:card, card_number).version(1).shows(:changed => 'Description')
  end

  def test_add_with_detail_creates_card_with_type_defaults
    description_default = 'steps to reproduce'
    setup_card_type(@project, DEFECT, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    type_description_defaults(description_default)
    set_property_defaults(@project, STATUS => NEW, USER_PROPERTY => @admin.name, DATE_PROPERTY => TODAY)
    click_save_defaults
    add_card_with_detail_via_quick_add('', :type => DEFECT)
    assert_card_or_page_content_in_edit(description_default)
    assert_properties_set_on_card_edit(STATUS => NEW, USER_PROPERTY => ADMIN_NAME_TRUNCATED, DATE_PROPERTY => today_in_project_format)
    type_card_name('foo')
    save_card
    navigate_to_history_for(@project)
    card_number = find_card_by_name('foo').number
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {:Type => DEFECT, STATUS => NEW, USER_PROPERTY => @admin.name, DATE_PROPERTY => today_in_project_format})
    assert_history_for(:card, card_number).version(1).shows(:changed => 'Description')
  end

  def test_any_team_member_can_create_card_if_default_sets_transition_only_property
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, FREE_TEXT_PROPERTY])
    make_property_transition_only_for(@project, STATUS)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, STATUS => NEW, USER_PROPERTY => @admin.name)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, VALUE_FOR_FREE_TEXT_PROPERTY)
    click_save_defaults
    logout

    login_as_project_member
    card_number = add_new_card('testing defaults with transition only', :type => STORY)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_property_not_editable_on_card_edit(STATUS)
    assert_property_not_editable_on_card_edit(USER_PROPERTY)
    assert_property_not_editable_on_card_edit(FREE_TEXT_PROPERTY)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => NEW, USER_PROPERTY => @admin.name, FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY})
  end

  def test_transition_only_properties_can_be_set_with_quick_add_card_creation_using_card_defaults
    setup_card_type(@project, DEFECT, :properties => [PRIORITY, USER_PROPERTY])
    make_property_transition_only_for(@project, PRIORITY)
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, PRIORITY => HIGH, USER_PROPERTY => @project_member.name)
    click_save_defaults
    make_property_transition_only_for(@project, USER_PROPERTY)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => DEFECT)

    card_number = add_card_via_quick_add('Defect w/ transition only properties set', :type => DEFECT)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {PRIORITY => HIGH})
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {USER_PROPERTY => @project_member.name})
  end

  def test_transition_only_properties_set_in_card_defaults_can_be_set_via_add_with_detail
    closed = 'CLOSED'
    setup_card_type(@project, DEFECT, :properties => [STATUS])
    make_property_transition_only_for(@project, STATUS)
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults_via_inline_value_add(@project, STATUS, closed)
    click_save_defaults
    make_property_transition_only_for(@project, USER_PROPERTY)
    add_card_with_detail_via_quick_add('Defect w/ transition only properties set', :type => DEFECT)
    save_card
    card_number = find_card_by_name('Defect w/ transition only properties set').number
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => closed})
  end

  def test_hiding_property_set_via_card_type_defaults_sets_property_on_card
    setup_card_type(@project, DEFECT, :properties => [FREE_TEXT_PROPERTY, STATUS])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, VALUE_FOR_FREE_TEXT_PROPERTY)
    click_save_defaults
    hide_property(@project, FREE_TEXT_PROPERTY)
    card_number = add_new_card('Defect w/ hidden property', :type => DEFECT)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY})
  end

  # bug 2859
  def test_hidden_property_on_card_default_can_be_set_via_add_with_detail
    setup_card_type(@project, DEFECT, :properties => [STATUS, USER_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, STATUS => NEW, USER_PROPERTY => @admin.name)
    click_save_defaults
    hide_property(@project, USER_PROPERTY)
    add_card_with_detail_via_quick_add('hidden property via add with detail', :type => DEFECT)
    save_card
    card_number = find_card_by_name('hidden property via add with detail').number
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {USER_PROPERTY => @admin.name})
  end

  def test_excel_import_with_type_only_creates_card_with_all_defaults_set
    card_number = 25
    description_default = "this should be the default description"
    setup_card_type(@project, DEFECT, :properties => [STATUS])
    open_edit_defaults_page_for(@project, DEFECT)
    type_description_defaults(description_default)
    set_property_defaults(@project, STATUS => NEW)
    click_save_defaults
    navigate_to_card_list_for(@project)
    header_row = ['number', 'name', 'type']
    card_data = [[card_number, 'testing card type defaults', DEFECT]]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_history_generation
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_card_or_page_content_in_edit(description_default)
    assert_properties_set_on_card_edit(STATUS => NEW)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => NEW})
    assert_history_for(:card, card_number).version(1).shows(:changed => 'Description')
  end

  def test_description_in_excel_import_overwrites_description_in_defaults
    card_number = 35
    description_default = "this is the default description"
    user_entered_description = 'this should override the default description'
    setup_card_type(@project, DEFECT, :properties => [STATUS])
    open_edit_defaults_page_for(@project, DEFECT)
    type_description_defaults(description_default)
    click_save_defaults
    navigate_to_card_list_for(@project)
    header_row = ['number', 'type', 'description']
    card_data = [[card_number, DEFECT, user_entered_description]]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_history_generation
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_card_or_page_content_in_edit(user_entered_description)
    assert_history_for(:card, card_number).version(1).shows(:changed => 'Description')
  end

  def test_excel_import_can_override_default_property_while_retaining_other_defaults
    card_number = 72
    setup_card_type(@project, DEFECT, :properties => [STATUS, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, VALUE_FOR_FREE_TEXT_PROPERTY)
    click_save_defaults
    navigate_to_card_list_for(@project)
    header_row = ['number', 'type', STATUS]
    card_data = [[card_number, DEFECT, OPEN]]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_history_generation
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => OPEN, FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY})
  end

  def test_update_existing_card_via_excel_import_does_not_set_card_defaults
    original_card_name = 'original name'
    original_card_description = 'original description'
    description_default = "this should be the default description"
    new_card_name = 'updated name'
    setup_card_type(@project, DEFECT, :properties => [PRIORITY])
    existing_defect_with_description = create_card!(:name => original_card_name, :type => DEFECT, :description => original_card_description)
    existing_defect_without_description = create_card!(:name => original_card_name, :type => DEFECT)

    open_edit_defaults_page_for(@project, DEFECT)
    type_description_defaults(description_default)
    set_property_defaults(@project, PRIORITY => HIGH)
    click_save_defaults
    navigate_to_card_list_for(@project)
    header_row = ['number', 'name', 'type']
    card_data = [
      [existing_defect_with_description.number, new_card_name, DEFECT],
      [existing_defect_without_description.number, new_card_name, DEFECT]
    ]
    import(excel_copy_string(header_row, card_data))

    @browser.run_once_history_generation
    open_card(@project, existing_defect_with_description.number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_card_or_page_content_in_edit(original_card_description)
    assert_properties_set_on_card_edit(PRIORITY => NOT_SET)
    assert_history_for(:card, existing_defect_with_description.number).version(2).shows(:changed => 'Name', :from => original_card_name, :to => new_card_name)
    assert_history_for(:card, existing_defect_with_description.number).version(2).does_not_show(:set_properties => {PRIORITY => HIGH})
    assert_history_for(:card, existing_defect_with_description.number).version(2).does_not_show(:changed => 'Description')
    open_card(@project, existing_defect_without_description.number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_card_or_page_content_in_edit(BLANK)
    assert_properties_set_on_card_edit(PRIORITY => NOT_SET)
    assert_history_for(:card, existing_defect_without_description.number).version(2).shows(:changed => 'Name', :from => original_card_name, :to => new_card_name)
    assert_history_for(:card, existing_defect_without_description.number).version(2).does_not_show(:set_properties => {PRIORITY => HIGH})
    assert_history_for(:card, existing_defect_without_description.number).version(2).does_not_show(:changed => 'Description')
  end

  def test_default_setting_user_property_sets_it_to_not_set_when_creating_project_from_template
    setup_card_type(@project, DEFECT, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, USER_PROPERTY => @admin.name)
    click_save_defaults
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)

    Project.find_by_identifier(new_project_name).with_active_project do |project_created_from_template|
      open_edit_defaults_page_for(project_created_from_template, DEFECT)
      assert_properties_set_on_card_defaults(project_created_from_template, USER_PROPERTY => '(not set)')
    end
  end

  def test_default_setting_date_property_sets_correctly_uses_new_project_date_format_when_creating_project_from_template
    setup_card_type(@project, DEFECT, :properties => [DATE_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    click_save_defaults
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier, :date_format => 'yyyy/mm/dd')
    Project.find_by_identifier(new_project_name).with_active_project do |project_created_from_template|
      open_edit_defaults_page_for(project_created_from_template, DEFECT)
      assert_properties_set_on_card_defaults(project_created_from_template, DATE_PROPERTY => TODAY)
    end
  end

  def test_card_defaults_are_maintained_when_creating_project_from_template
    setup_card_type(@project, DEFECT, :properties => [STATUS, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    description_default = 'steps to reproduce'
    type_description_defaults(description_default)
    set_property_defaults(@project, STATUS => NEW)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, VALUE_FOR_FREE_TEXT_PROPERTY)
    click_save_defaults
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate
    open_edit_defaults_page_for(project_created_from_template, DEFECT)
    assert_default_description(description_default)
    assert_properties_set_on_card_defaults(project_created_from_template, STATUS => NEW, FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY)
    card_number = add_new_card('testing defaults', :type => DEFECT)
    open_card(project_created_from_template, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_card_or_page_content_in_edit(description_default)
    assert_properties_set_on_card_edit(STATUS => NEW, FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => NEW, FREE_TEXT_PROPERTY => VALUE_FOR_FREE_TEXT_PROPERTY})
    assert_history_for(:card, card_number).version(1).shows(:changed => 'Description')
  end

  def test_user_property_set_to_current_user_survives_project_template_creation
    hidden_user_property = 'hidden owner'
    setup_user_definition(hidden_user_property)
    hide_property(@project, hidden_user_property)
    setup_card_type(@project, DEFECT, :properties => [USER_PROPERTY, hidden_user_property])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, USER_PROPERTY => CURRENT_USER, hidden_user_property => CURRENT_USER)
    click_save_defaults
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate
    open_edit_defaults_page_for(project_created_from_template, DEFECT)
    assert_properties_set_on_card_defaults(project_created_from_template, USER_PROPERTY => CURRENT_USER, hidden_user_property => CURRENT_USER)
    card_number = add_new_card('testing defaults', :type => DEFECT)
    open_card(project_created_from_template, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_property_not_present_on_card_edit(hidden_user_property)
    assert_card_type_set_on_card_edit(DEFECT)
    assert_properties_set_on_card_edit(USER_PROPERTY => ADMIN_NAME_TRUNCATED)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {USER_PROPERTY => @admin.name, hidden_user_property => @admin.name})
  end

  def test_date_property_set_to_today_survives_project_template_creation
    hidden_date_property = 'hidden date property'
    setup_date_property_definition(hidden_date_property)
    hide_property(@project, hidden_date_property)
    setup_card_type(@project, DEFECT, :properties => [DATE_PROPERTY, hidden_date_property])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, DATE_PROPERTY => TODAY, hidden_date_property => TODAY)
    click_save_defaults
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate
    project_created_from_template.time_zone = ActiveSupport::TimeZone.new("London").name
    project_created_from_template.save!
    open_edit_defaults_page_for(project_created_from_template, DEFECT)
    assert_properties_set_on_card_defaults(project_created_from_template, DATE_PROPERTY => TODAY, hidden_date_property => TODAY)
    card_number = add_new_card('testing defaults', :type => DEFECT)
    open_card(project_created_from_template, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(DEFECT)
    assert_property_not_present_on_card_edit(hidden_date_property)
    assert_card_type_set_on_card_edit(DEFECT)
    assert_properties_set_on_card_edit(DATE_PROPERTY => today_in_project_format)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {DATE_PROPERTY => today_in_project_format, hidden_date_property => today_in_project_format})
  end

  def test_current_user_sets_user_property_to_logged_in_user_via_quick_add
    login_as_proj_admin_user
    setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, USER_PROPERTY => CURRENT_USER)
    click_save_defaults

    card_number = add_card_via_quick_add('Story created by logged in project admin user', :type => STORY)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJ_ADMIN_NAME_TRUNCATED)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {USER_PROPERTY => @project_admin.name})

    login_as_project_member
    card_number = add_card_via_quick_add('Story created by logged in project member user', :type => STORY, :wait => true)
    open_card(@project, card_number)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJECT_MEMBER_NAME_TRUNCATED)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {USER_PROPERTY => @project_member.name})
  end

  def test_current_user_sets_user_property_to_logged_in_user_via_add_with_detail
    setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, USER_PROPERTY => CURRENT_USER)
    click_save_defaults

    login_as_proj_admin_user
    add_card_with_detail_via_quick_add('created by project admin user', :type => STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJ_ADMIN_NAME_TRUNCATED)
    save_card
    @browser.wait_for_element_visible 'notice'
    card = find_card_by_name('created by project admin user')
    open_card(@project, card)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJ_ADMIN_NAME_TRUNCATED)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {USER_PROPERTY => @project_admin.name})

    login_as_project_member
    add_card_with_detail_via_quick_add('created by project member', :type => STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJECT_MEMBER_NAME_TRUNCATED)
    save_card
    @browser.wait_for_element_visible 'notice'
    card = find_card_by_name('created by project member')
    navigate_to_history_for(@project)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {:Type => STORY, USER_PROPERTY => @project_member.name})
  end

  def test_current_user_sets_user_property_to_logged_in_user_via_excel_import
    login_as_proj_admin_user
    setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, USER_PROPERTY => CURRENT_USER)
    click_save_defaults
    card_number_created_by_project_admin_user = 25
    navigate_to_card_list_for(@project)
    header_row = ['number', 'name', 'type']
    card_data = [[card_number_created_by_project_admin_user, 'testing card type defaults', STORY]]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_history_generation
    open_card(@project, card_number_created_by_project_admin_user)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJ_ADMIN_NAME_TRUNCATED)
    assert_history_for(:card, card_number_created_by_project_admin_user).version(1).shows(:set_properties => {USER_PROPERTY => @project_admin.name})

    login_as_project_member
    navigate_to_card_list_for(@project)
    card_number_created_by_project_project_member = 26
    header_row = ['number', 'name', 'type']
    card_data = [[card_number_created_by_project_project_member, 'testing card type defaults', STORY]]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_history_generation
    open_card(@project, card_number_created_by_project_project_member)
    click_edit_link_on_card
    assert_card_type_set_on_card_edit(STORY)
    assert_properties_set_on_card_edit(USER_PROPERTY => PROJECT_MEMBER_NAME_TRUNCATED)
    assert_history_for(:card, card_number_created_by_project_project_member).version(1).shows(:set_properties => {USER_PROPERTY => @project_member.name})
  end

  #TODO only need to set up one quick add type
  def test_mingle_admin_that_is_not_team_member_is_not_set_as_current_user_via_card_default
      login_as_proj_admin_user
      setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
      open_edit_defaults_page_for(@project, STORY)
      set_property_defaults(@project, USER_PROPERTY => CURRENT_USER)
      click_save_defaults
      remove_from_team_for(@project, @admin)
      logout
      login_as_admin_user
      add_card_with_detail_via_quick_add('Story created by logged in project admin user', :type => STORY)
      assert_properties_not_set_on_card_edit(USER_PROPERTY)
    end
end
