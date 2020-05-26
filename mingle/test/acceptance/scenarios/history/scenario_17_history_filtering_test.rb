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
# Tags: history, tagging, properties
class Scenario17HistoryFilteringTest < ActiveSupport::TestCase


  fixtures :users, :login_access

  ANY = '(any)'
  NOT_SET = '(not set)'
  ANY_CHANGE = '(any change)'

  WITH_QUESTION_MARK = 'has auto test?'
  YES = 'yes'
  NO = 'no'
  WITH_QUESTION_MARK_YES = {WITH_QUESTION_MARK => YES}
  WITH_QUESTION_MARK_NO = {WITH_QUESTION_MARK => NO}


  FEATURE = 'feature'
  CARDS = 'cards'
  PROPERTY_VALUE = {FEATURE => CARDS}

  LANG = 'lang'
  JAVASCRIPT = 'JavaScript'
  CAMEL_CASE_PROPERTY_VALUE = {LANG => JAVASCRIPT}

  STATUS = 'status'
  NEW = 'new'
  IN_PROGRESS = 'in progress'
  ANOTHER_PROPERTY_VALUE = { STATUS => NEW }
  PROPERTY_VALUE_WITH_SPACE = { STATUS => IN_PROGRESS }

  TAG = 'wiki'
  TAG_WITH_SPACES = 'some feature'
  CAMEL_CASE_TAG = 'JavaScript'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = User.find_by_login('member')
    @admin = User.find_by_login('admin')

    login_as_project_member
    @project = create_project(:prefix => 'project_17', :users => [@project_member, @admin])
    setup_property_definitions(STATUS => [NEW, IN_PROGRESS], FEATURE => [CARDS], LANG => [JAVASCRIPT], WITH_QUESTION_MARK => [YES, NO])
    open_project(@project)
  end

  def teardown
    super
    @project.deactivate
  end

  def test_should_provide_tooltip_for_property_on_history_filter_panel
    login_as_admin_user
    edit_property_definition_for(@project, STATUS, :description => "this is status.")
    edit_property_definition_for(@project, FEATURE, :description => "this is feature.")
    navigate_to_history_for(@project)
    assert_property_tooltip_in_first_filter_widget(STATUS)
    assert_property_tooltip_in_second_filter_widget(FEATURE)
  end

  # Story 12754 -quick add on funky tray
  def test_should_be_able_to_quick_add_card_on_history_page
    navigate_to_history_for(@project)
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card", :wait => true)
    @browser.wait_for_element_visible("notice")
    card = find_card_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created.", :escape => true)
  end

  def test_what_properties_are_supported_and_what_are_not_supported_in_history_filter_and_plv_is_not_supported_in_history_filters
     super_card_type = setup_card_type(@project, "Super Card")
     sub_card_type = setup_card_type(@project, "Sub Card")
     card_type = @project.card_types.find_by_name('Card')

     managed_text = setup_property_definitions :status => ['open', 'closed']
     any_text = setup_allow_any_text_property_definition 'address'
     managed_number = setup_numeric_property_definition('size',[1,2,3])
     any_number = setup_allow_any_number_property_definition 'iteration'
     any_date = setup_date_property_definition 'started on'
     formula = setup_formula_property_definition('formula', "'#{any_date.name}' + 1")
     any_card = setup_card_relationship_property_definition('dependency')
     user = setup_user_definition('owner')
     tree = setup_tree(@project, 'Simple Tree', :types => [super_card_type, card_type, sub_card_type], :relationship_names => ["tree - first", "tree - second"])
     aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, tree.id, card_type.id, sub_card_type)

     card_for_plv_value = create_card!(:card_type => super_card_type, :name => 'plv value card')
     setup_project_variable(@project, :name => 'text plv', :data_type => 'StringType', :value => 'any',:properties => ['status'])
     setup_project_variable(@project, :name => 'number plv', :data_type => 'NumericType', :value => '0',:properties => ['size'])
     setup_project_variable(@project, :name => 'user plv', :data_type => 'UserType', :value => @project_member,:properties => ['owner'])
     setup_project_variable(@project, :name => 'card plv', :data_type => 'CardType', :value => card_for_plv_value, :card_type => card_type,:properties => ['dependency','tree - second'])

     navigate_to_history_for(@project)

     # Check what properties are supported or not in history filter.
     assert_properties_in_first_filter_widget({'status' => '(any)'})
     assert_properties_in_first_filter_widget({'size' => '(any)'})
     assert_properties_in_first_filter_widget({'owner' => '(any)'})
     assert_properties_in_first_filter_widget({'tree - first' => '(any)'})
     assert_properties_in_first_filter_widget({'dependency' => '(any)'})

     assert_property_not_present_in_first_filter_widget('address')
     assert_property_not_present_in_first_filter_widget('formula')
     assert_property_not_present_in_first_filter_widget('iteration')
     assert_property_not_present_in_first_filter_widget('started on')
     assert_property_not_present_in_first_filter_widget('aggregate')

    # Bug # 6679 PLV is not supported in history filter
     assert_value_not_present_in_history_filter_drop_list_for("status","(text plv)",:property_type => "enumerated")
     assert_value_not_present_in_history_filter_drop_list_for("size","(number plv)",:property_type => "enumerated")
     assert_value_not_present_in_history_filter_drop_list_for("owner","(user plv)",:property_type => "user")
     assert_value_not_present_in_history_filter_drop_list_for("dependency","(card plv)",:property_type => "cardrelationship")
     assert_value_not_present_in_history_filter_drop_list_for("tree - second","(card plv)",:property_type => "treerelationship")

     # bug 8108
     assert_no_inline_edits_present
  end

  def test_filter_history_by_no_team_member_returns_cards_and_pages_created_or_modified_by_user
    card_created_by_project_member = create_card!(:name => 'created by project admin')
    page_name = 'foo'
    page_created_by_project_member = create_new_wiki_page(@project, page_name, 'some reqs')
    login_as_admin_user
    open_card(@project, card_created_by_project_member.number)
    set_properties_on_card_show(STATUS => NEW) #v2

    @browser.run_once_history_generation

    navigate_to_history_for(@project)
    filter_history_by_team_member(@project_member)
    assert_page_history_for(:page, page_name).version(1).shows(:created_by => @project_member.name)
    assert_page_history_for(:page, page_name).version(2).not_present
    assert_history_for(:card, card_created_by_project_member.number).version(1).shows(:created_by => @project_member.name)
    assert_history_for(:card, card_created_by_project_member.number).version(2).not_present
    filter_history_by_no_team_member

    assert_page_history_for(:page, page_name).version(1).present
    assert_history_for(:card, card_created_by_project_member.number).version(1).present
    assert_history_for(:card, card_created_by_project_member.number).version(2).present
    filter_history_by_team_member(@admin)
    assert_page_history_for(:page, page_name).version(1).not_present
    assert_history_for(:card, card_created_by_project_member.number).version(1).not_present
    assert_history_for(:card, card_created_by_project_member.number).version(2).shows(:modified_by => @admin.name)
  end

  def test_filerting_by_cards_and_pages
    page_name = 'stuff'
    create_new_wiki_page(@project, page_name, 'some contents')
    card = create_card!(:name => 'some work', STATUS => NEW)

    # create version 2 for each
    open_card(@project, card.number)
    set_properties_on_card_show(STATUS => NOT_SET)
    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    click_type_for_history_filtering('pages')
    assert_card_not_present(card)
    assert_page_history_for(:page, page_name).version(1).present

    click_type_for_history_filtering('cards')
    assert_page_history_for(:page, page_name).version(1).present
    assert_history_for(:card, card.number).version(1).shows(:created_by => @project_member.name)
    assert_history_for(:card, card.number).version(2).shows(:changed => STATUS, :from => NEW, :to => NOT_SET)

    click_type_for_history_filtering('pages')
    assert_page_history_for(:page, page_name).version(1).not_present
    assert_page_history_for(:page, page_name).version(2).not_present
    assert_history_for(:card, card.number).version(1).shows(:created_by => @project_member.name)
    assert_history_for(:card, card.number).version(2).shows(:changed => STATUS, :from => NEW, :to => NOT_SET)
  end

  def test_filtering_history_with_any_and_not_set
    card_with_feature_set_and_no_changes = create_card!(:name => 'has changes', FEATURE => CARDS)
    card_with_feature_changes = create_card!(:name => 'another', STATUS => NEW, FEATURE => CARDS)
    card_without_properties = create_card!(:name => 'without properties')

    open_card(@project, card_with_feature_changes.number)
    set_properties_on_card_show(FEATURE => NOT_SET) #v2
    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    filter_history_using_first_condition_by(@project, FEATURE => NOT_SET)
    assert_history_for(:card, card_without_properties.number).version(1).shows(:created_by => @project_member.name)
    assert_history_for(:card, card_with_feature_changes.number).version(2).shows(:unset_properties => {FEATURE => CARDS})
    assert_card_not_present(card_with_feature_set_and_no_changes)
    assert_history_for(:card, card_with_feature_changes.number).version(1).not_present

    filter_history_using_first_condition_by(@project, FEATURE => ANY)
    filter_history_using_second_condition_by(@project, FEATURE => NOT_SET)
    assert_history_for(:card, card_with_feature_changes.number).version(2).shows(:unset_properties => {FEATURE => CARDS})
    assert_card_not_present(card_with_feature_set_and_no_changes)
    assert_card_not_present(card_without_properties)
  end

  def test_filtering_with_property1
    assert_history_contains_correct_property_events_for_card(:first_filter => WITH_QUESTION_MARK_YES, :second_filter => PROPERTY_VALUE)
  end

  def test_filtering_with_property2
    assert_history_contains_correct_property_events_for_card(:first_filter => PROPERTY_VALUE_WITH_SPACE, :second_filter => WITH_QUESTION_MARK_NO)
  end

  def test_filter_with_property_set_to_any_change
     create_card(STATUS => NEW)
      update_card(STATUS => IN_PROGRESS)
      update_card(LANG => JAVASCRIPT)
      set_history_filter_as({ STATUS => NEW }, { STATUS => ANY_CHANGE })
      filter_result_should_contain(STATUS, NEW, IN_PROGRESS)
      filter_result_should_not_contain(LANG, NOT_SET, JAVASCRIPT)
  end

  def assert_history_contains_correct_property_events_for_card(options = {})
    first_filter = options[:first_filter]
    second_filter = options[:second_filter]
    card_name = 'card 1'
    card_number = create_card_with_interesting_versions_related_to(first_filter, second_filter, card_name)
    card_number_of_untaggged = create_untagged_card

    @browser.run_once_history_generation # added this to generate history
    navigate_to_history_for @project

    filter_history_using_first_condition_by @project, first_filter
    assert_history_for(:card, card_number).version(1).shows(:set_properties => first_filter)
    assert_history_for(:card, card_number).version(2).not_present

    assert_history_for(:card, card_number).version(3).shows(:set_properties => first_filter)
    assert_history_for(:card, card_number).version(4).shows(:changed => 'Name', :from => card_name, :to => 'creating new event')
    assert_history_for(:card, card_number).version(5).shows(:set_properties => second_filter)
    assert_history_for(:card, card_number).version(6).not_present

    assert_history_for(:card, card_number).version(7).not_present
    assert_history_for(:card, card_number_of_untaggged).version(1).not_present

    filter_history_using_second_condition_by @project, second_filter
    assert_history_for(:card, card_number).version(5).shows(:set_properties => second_filter)

    @browser.click_and_wait 'name=reset'
    assert_history_for(:card, card_number).version(1).shows(:set_properties => first_filter)
    assert_history_for(:card, card_number).version(2).shows(:unset_properties => first_filter)
    assert_history_for(:card, card_number).version(3).shows(:set_properties => first_filter)
    assert_history_for(:card, card_number).version(4).shows(:changed => 'Name', :from => card_name, :to => 'creating new event')
    assert_history_for(:card, card_number).version(5).shows(:set_properties => second_filter)
    assert_history_for(:card, card_number).version(6).shows(:unset_properties => first_filter)
    assert_history_for(:card, card_number).version(7).present
    assert_history_for(:card, card_number_of_untaggged).version(1).present

    filter_history_by_team_member(@admin)
    assert_history_for(:card, card_number).version(8).present

    login_as_project_member
  end

  def create_card_with_interesting_versions_related_to(first_filter_properties, second_filter_properties, card_name)
       @card = create_card!({:name => card_name}.merge(first_filter_properties))
       card_number = @card.number

       # version 2: set first filter property's value to not set
       @card.update_properties(empty_properties(first_filter_properties))
       @card.save!

       #version 3: reset first filter property's value
       @card.update_properties(first_filter_properties)
       @card.save!

       # version 4: do something else
       @card.name = 'creating new event'
       @card.save!

       # version 5:  set second filter property's value
       @card.update_properties(second_filter_properties)
       @card.save!

       # version 6: set first filter property's value to not set
       @card.update_properties(empty_properties(first_filter_properties))
       @card.save!

       # version 7: do something else
       @card.description = 'adding new details'
       @card.save!


       login_as_admin_user

       # version 8: login as different user and change the card
       @card.update_properties(first_filter_properties)
       @card.save!

      card_number
  end

  def create_untagged_card
     card_without_tagging_name = 'not tagged'
     @card = create_card!(:name => card_without_tagging_name)
     card_without_tagging_number=@card.number
     card_without_tagging_number
  end

  def empty_properties(properties)
    properties.keys.inject({}){|result, key| result[key] = nil; result }
  end

  #bug 8207
  def test_should_give_confirmation_message_after_filtering_history
    create_card!(:name => 'testing card')
    create_new_wiki_page(@project, 'testing page', 'some reqs')

    navigate_to_history_for(@project)
    click_type_for_history_filtering('pages')
    assert_info_message('Viewing 1 to 1 of 1 event')
  end

  # bug 6612, secario 4
  def test_auto_enrolled_user_should_appear_in_drop_down_of_user_type_property_and_deleted_property_not_appear_in_history_filters
    login_as_admin_user

    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    user = setup_user_definition('owner')

    auto_enroll_all_users_as_full_users(@project)
    navigate_to_user_management_page
    click_new_user_link
    new_user = add_new_user("new_user@gmail.com", "password1.")

    navigate_to_history_for(@project)

    assert_value_present_in_history_filter_drop_list_for_property_in_first_filter_widget('owner',new_user.name,:property_type => 'user')
    assert_value_present_in_history_filter_drop_list_for_property_in_second_filter_widget('owner',new_user.name,:property_type => 'user')
    @browser.click_and_wait(css_locator("input[value='Reset']"))

    # deleted property should no longer appears in_history filters
    @browser.assert_element_does_not_match('involved_filter_widget', /#{STATUS}/)
    @browser.assert_element_does_not_match('acquired_filter_widget', /#{STATUS}/)
  end

  #
  # #TODO need new test scenario for the fixed filtering
  # # def xtest_filter_by_mixed_properties_and_tags
  # #   #assert_history_contains_correct_events_for_card(:first_filter => PROPERTY_VALUE.merge(:tags => TAG), :second_filter => CAMEL_CASE_PROPERTY_VALUE)
  # #   # need to allow :second_filter to handle multiple values - jem 10/4/2007
  # #   # assert_history_contains_correct_events_for_card(:first_filter => [TAG], :second_filter => [ANOTHER_PROPERTY_VALUE, TAG_WITH_SPACES])
  # #   #assert_history_contains_correct_events_for_card(:first_filter => [CAMEL_CASE_TAG], :second_filter => [TAG, PROPERTY_VALUE_WITH_SPACE])
  # # end
  #

end
