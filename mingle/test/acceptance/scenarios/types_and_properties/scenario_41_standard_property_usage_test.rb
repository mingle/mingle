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

# Tags: scenario, bug, properties, #178, #961, #962, #1134, #1158, #1165, #1167, #1168, #1188, #1439
class Scenario41StandardPropertyUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'

  ANY_TEXT = 'any text'
  PROPERTY_VALUE = 'text value'
  MANAGED_TEXT_LIST = 'managed text list'
  CARD_NAME = 'Plain card'
  PROPERTY_NAME = 'Simple property'

  PRIORITY = 'priority'
  HIGH = 'high'
  MIDDLE = 'middle'
  LOW = 'low'
  NOT_SET = '(not set)'

  CAPITALIZED_SPECIAL_WORDS = ['Method', 'Methods', 'Class', 'Display', 'Send', 'Freeze', 'Select', 'Table', 'Where', 'And', 'Join', 'Left', 'Outer', 'Inner', 'User', 'New', 'Group','From', 'Using']
  LOWERCASE_SPECIAL_WORDS = CAPITALIZED_SPECIAL_WORDS.collect(&:downcase)
  VARIETY_OF_PROPERTY_NAMES = ["'single quotes'", 'ALLCAPS', 'Capitalized', 'CamelCase', 'moreCamelCase', 'has space', 'with, comma', 'with-hyphen']

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_41', :admins => [users(:proj_admin)])
    @project.activate
    login_as_proj_admin_user
  end

  def test_all_members_can_see_property_tooltip
    create_property_definition_for(@project, 'release', :type => 'card', :description => "this property indicates which release is this card belongs to.")
    card = create_card!(:name => 'morning sf')

    add_readonly_and_full_member_to_project
    enable_anonymous_access_for_project
    logout

    open_card(@project, card)    # test tooltip for anon user
    assert_property_tooltip_on_card_show_for_anon_user('release')

    login_as_read_only_user
    open_card(@project, card)    # test tooltip for anon user
    assert_property_tooltip_on_card_show_for_read_only_user('release')

    full_member_and_proj_admin = ["bob", "proj_admin"].each do |login|
      login_as(login)
      open_card(@project, card)
      assert_property_tooltip_on_card_show('release')
      logout
      end
  end

  def test_tooltip_of_property_who_does_not_have_description_on_card_show
    create_property_definition_for(@project, 'release')
    card = create_card!(:name => 'morning sf')

    open_card(@project, card)
    assert_property_tooltip_on_card_show('release')
  end

  def test_property_tooltip_on_old_card_version
    create_property_definition_for(@project, 'release', :type => 'card', :description => "this property indicates which release is this card belongs to.")
    card = create_card!(:name => 'morning sf')

    open_card(@project, card)
    set_relationship_properties_on_card_show('release' => card)
    open_card_version(@project, card.number, 1)
    assert_property_tooltip_on_old_card_version('release')
  end

  def test_tooltip_for_hidden_property_on_card_edit_page
    create_property_definition_for(@project, 'estimate', :type => 'any number', :description => "this is a property indicates estimate for each story.")
    hide_property(@project,'estimate')

    navigate_to_card_list_for(@project)

    card = create_card!(:name => 'morning sf')

    open_card(@project, card)
    ensure_hidden_properties_visible
    assert_property_tooltip_on_card_edit('estimate')
  end

  def test_tooltip_for_property_on_card_edit
    create_property_definition_for(@project, 'status', :description => "this is a property indicates current status for each card.")

    card = create_card!(:name => CARD_NAME)
    open_card_for_edit(@project, card.number)
    assert_property_tooltip_on_card_edit('status')
  end


  def test_tooltip_for_property_on_card_show
    create_property_definition_for(@project, PRIORITY, :type => 'any text', :description => "this is a property indicates priority for each card.")

    card = create_card!(:name => CARD_NAME)
    open_card(@project, card.number)
    assert_property_tooltip_on_card_show(PRIORITY)
  end

  def test_search_value_for_managed_text_property_on_card_edit
    setup_property_definitions(:priority => [HIGH,MIDDLE,LOW])
    card = create_card!(:name => CARD_NAME)

    open_card_for_edit(@project, card.number)
    click_property_on_card_edit(PRIORITY)
    assert_values_present_in_property_drop_down_on_card_edit(PRIORITY,[NOT_SET,HIGH,MIDDLE,LOW])
    type_keyword_to_search_value_for_property_on_card_edit(PRIORITY,'HELLO')
    assert_values_not_present_in_property_drop_down_on_card_edit(PRIORITY, [NOT_SET,HIGH,MIDDLE,LOW])
    type_keyword_to_search_value_for_property_on_card_edit(PRIORITY,'I')
    assert_values_present_in_property_drop_down_on_card_edit(PRIORITY,[MIDDLE,HIGH])
    assert_values_not_present_in_property_drop_down_on_card_edit(PRIORITY, [NOT_SET,LOW])
    type_keyword_to_search_value_for_property_on_card_edit(PRIORITY,'Lo')
    assert_values_not_present_in_property_drop_down_on_card_edit(PRIORITY, [NOT_SET,HIGH,MIDDLE])
    assert_values_present_in_property_drop_down_on_card_edit(PRIORITY, [LOW])
    select_value_in_drop_down_for_property_on_card_edit(PRIORITY,LOW)
    assert_edit_property_set(PRIORITY,LOW)
  end

  def test_search_value_for_managed_text_property_on_card_show
    setup_property_definitions(:priority => [HIGH,MIDDLE,LOW])
    card = create_card!(:name => CARD_NAME)
    open_card(@project, card.number)
    click_property_on_card_show(PRIORITY)
    assert_value_present_in_property_drop_down_on_card_show(PRIORITY,[NOT_SET,HIGH,MIDDLE,LOW])
    type_keyword_to_search_value_for_property_on_card_show(PRIORITY,'hello')
    assert_value_not_present_in_property_drop_down_on_card_show(PRIORITY,[MIDDLE,HIGH,LOW,NOT_SET])
    type_keyword_to_search_value_for_property_on_card_show(PRIORITY,'o')
    assert_value_present_in_property_drop_down_on_card_show(PRIORITY,[LOW,NOT_SET])
    assert_value_not_present_in_property_drop_down_on_card_show(PRIORITY,[MIDDLE,HIGH])
    select_value_in_drop_down_for_property_on_card_show(PRIORITY,LOW)
    assert_property_set_on_card_show(PRIORITY, LOW)
  end

  # bug 1134
  def test_can_set_property_to_values_that_contain_ampersand
    enum_value = 'Dev 1 & Dev 2'
    property_name = 'owner'
    setup_property_definitions(property_name => [enum_value])
    card_without_properties = create_card!(:name => 'plain card')
    open_card(@project, card_without_properties.number)
    set_properties_on_card_show(property_name => enum_value)
    @browser.run_once_history_generation
    open_card(@project, card_without_properties.number)
    assert_history_for(:card, card_without_properties.number).version(2).shows(:set_properties => {property_name => enum_value})
  end


  def test_can_set_values_on_card_for_various_property_names
    card_without_properties = create_card!(:name => CARD_NAME)
    VARIETY_OF_PROPERTY_NAMES.each do |property_name|
     create_managed_text_list_property(property_name, [PROPERTY_VALUE])
    end
    open_card(@project, card_without_properties.number)
    VARIETY_OF_PROPERTY_NAMES.each do |property_name|
     set_properties_on_card_show(property_name => PROPERTY_VALUE)
    end
    @browser.run_once_history_generation
    last_version_number = VARIETY_OF_PROPERTY_NAMES.size + 1
    assert_history_for(:card, card_without_properties.number).version(last_version_number).present
  end

  # bug 178, 1439
  def test_can_add_and_remove_columns_for_various_property_names
    card_without_properties  = create_card!(:name => CARD_NAME)
    VARIETY_OF_PROPERTY_NAMES.each do |property_name|
     create_managed_text_list_property(property_name, [PROPERTY_VALUE])
    end
    navigate_to_card_list_by_clicking(@project)
    assert_can_add_and_remove_columns_for(@project, VARIETY_OF_PROPERTY_NAMES)
  end

  # bugs 961, 962, 1188
  def test_can_create_property_definitions_with_capitalized_reserved_words_and_use_them
    new_card = create_card!(:name => CARD_NAME)
    CAPITALIZED_SPECIAL_WORDS.each do |property_name|
      property_def = create_property_definition_for(@project, property_name)
      assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    end
    navigate_to_property_management_page_for(@project)
    assert_properties_present_on_property_management_page(CAPITALIZED_SPECIAL_WORDS)
    click_all_tab
    assert_can_add_and_remove_columns_for(@project, CAPITALIZED_SPECIAL_WORDS)
  end

  # bugs 1188
  def test_can_create_property_definitions_with_reserved_words_and_use_them
    new_card = create_card!(:name => CARD_NAME)
    LOWERCASE_SPECIAL_WORDS.each do |property_name|
      property_def = create_property_definition_for(@project, property_name)
      assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    end
    navigate_to_property_management_page_for(@project)
    assert_properties_present_on_property_management_page(LOWERCASE_SPECIAL_WORDS)
    click_all_tab
    assert_can_add_and_remove_columns_for(@project, LOWERCASE_SPECIAL_WORDS)
  end

  # bug 1158
  def test_all_properties_sorted_alphabetically_natural_with_number_order
    managed_text_value = %w(a b)
    property_iteration = create_managed_text_list_property('iteration', managed_text_value)
    property_10_property = create_managed_text_list_property('10 property', managed_text_value)
    property_status = create_managed_text_list_property('status', managed_text_value)
    property_8_property = create_managed_text_list_property('8 property', managed_text_value)
    property_Int = create_managed_text_list_property('Int', managed_text_value)
    property_priority = create_managed_text_list_property('PRIORITY', managed_text_value)
    navigate_to_property_management_page_for(@project)
    assert_properties_order_in_property_management_list([property_8_property, property_10_property, property_Int, property_iteration, property_priority, property_status])
  end


  #bug 1165
  def test_group_by_and_order_by_in_grid_view_should_keep_users_entered_case_for_properties
    property1 = 'TESTING'
    property2 = 'FooBar'
    property3 = 'foo'
    create_managed_text_list_property(property1, ['value1', 'value2'])
    create_managed_text_list_property(property2, ['value3', 'value4'])
    create_managed_text_list_property(property3, ['value5', 'value6'])
    new_card = create_card!(:name => CARD_NAME, property1 => 'value1', property2 => 'value3', property3 => 'value5')
    navigate_to_grid_view_for(@project)
    group_by_and_order_by_drop_down_boxes_does_not_humanizing_properties_name([property1, property2, property3])
  end


  #bug 1168
  def test_property_should_not_miss_the_underscores_in_its_name_in_card_view_or_edit_page
    new_property_name = 'work_in_scope'
    new_property = create_allow_any_text_property(new_property_name)
    new_card = create_card!(:name => CARD_NAME)
    open_card(@project, new_card.number)
    assert_property_present_on_card_show(new_property)
  end

  #bug 1319
  def test_proeprty_should_not_take_more_than_255_chars_while_adding_new_value_inline_in_card_show
    enum_value_more_than_255 = 'dfgdfgdfsgdfgdfgdfgergeberthrtwherterytrgerygertfgryhrstegq34ygrtfg34tyegrhqge5rhtrgq435yw65hfghfgdgaerhstrdfggesdfbafshgbfgerhdfbrehfgbhdfhfgaghsdhdfgeshdbbaergsergserghdfgbdgersdfgersdfgsertdfgsergrfgrgsegssdfghrsthdsftegergherhgfdshtrehsdhbrthesrtghbhrd'
    enum_value_length_255 = 'dfgdfgdfsgdfgdfgdfgergeberthrtwherterytrgerygertfgryhrstegq34ygrtfg34tyegrhqge5rhtrgq435yw65hfghfgdgaerhstrdfggesdfbafshgbfgerhdfbrehfgbhdfhfgaghsdhdfgeshdbbaergsergserghdfgbdgersdfgersdfgsertdfgsergrfgrgsegssdfghrsthdsftegergherhgfdshtrehsdhbrthesrtghbhr'
    create_managed_text_list_property(PROPERTY_NAME, ['abc', 'def'])
    card = create_card!(:name => CARD_NAME)
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, PROPERTY_NAME, enum_value_more_than_255)
    assert_property_name_too_long_error_present(PROPERTY_NAME)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).not_present
    add_new_value_to_property_on_card_show(@project, PROPERTY_NAME, enum_value_length_255)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {PROPERTY_NAME => enum_value_length_255})
  end

  # bug 7826
  def test_clicking_bolded_part_of_filtered_option_will_highlight_and_select_option
    setup_property_definitions(:priority => [HIGH, MIDDLE, LOW])
    card = create_card!(:name => CARD_NAME)

    open_card_for_edit(@project, card.number)
    click_property_on_card_edit(PRIORITY)

    type_keyword_to_search_value_for_property_on_card_edit(PRIORITY, 'IDD')
    click_bolded_keyword_part_of_value_on_card_edit(PRIORITY, MIDDLE)
    assert_property_set_on_card_edit(PRIORITY, MIDDLE)
  end

  private

  def enable_anonymous_access_for_project
    register_license_that_allows_anonymous_users
    login_as_proj_admin_user
    navigate_to_project_admin_for(@project)
    enable_project_anonymous_accessible_on_project_admin_page
  end

  def add_readonly_and_full_member_to_project
    team_member = users(:bob)
    read_only_user = users(:read_only_user)
    add_full_member_to_team_for(@project, team_member)
    add_to_team_as_read_only_user_for(@project, read_only_user)
  end
end
