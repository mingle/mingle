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

#Tags:  card-properties, #4405
class Scenario112CardTypePropertyUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'
  DEPENDENCY = 'dependency'

 CARD = 'Card'
  STORY = 'Story'
  DEFECT = 'Defect'

  NOTSET = '(not set)'
  ANY = '(any)'
  SIMPLE_TREE = 'simple tree'

  TREE_STORY = 'tree_story'
  TREE_RELEASE = 'tree_release'
  TREE_ITERATION = 'tree_iteration'
  SUM = 'Sum'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @admin = users(:admin)
    @read_only_user = users(:read_only_user)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_112',:users => [@non_admin_user], :admins => [@project_admin_user, @admin], :read_only_users => [@read_only_user])
    setup_property_definitions(PRIORITY => ['high', 'low'], STATUS => ['new',  'close', 'open'])
    @story_type = setup_card_type(@project, STORY, :properties => [PRIORITY])
    @defect_type = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS])

    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'sample card_1', :card_type => STORY, PRIORITY => 'high')
    @card_2 = create_card!(:name => 'sample dependency', :card_type => DEFECT)
    @card_3 = create_card!(:name => 'sample card_3', :card_type => STORY)
    @card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => [STORY])
  end

  def test_property_tooltip_on_card_explore_panel
    edit_property_definition_for(@project, PRIORITY, :description => "this is dependency.")

    open_card(@project, @card_1)
    open_card_selection_widget_for_property_from_card_show_page(DEPENDENCY)
    add_new_filter_on_card_explore_panel
    set_the_filter_property_option_on_card_explore_panel(1, PRIORITY)
    assert_property_tooltip_on_card_explore_panel(1, PRIORITY)
  end

  def test_card_navigation_icon_should_be_available_for_anonymous_and_read_only_user
    register_license_that_allows_anonymous_users
    login_as_proj_admin_user
    navigate_to_project_admin_for(@project)
    enable_project_anonymous_accessible_on_project_admin_page

    create_tree_and_add_cards_to_tree
    add_properties_for_card_type(@defect_type, [@card_property])
    open_card(@project, @card_2)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_3)

    anonymous_and_readonly_users = {"read_only_user" => MINGLE_TEST_DEFAULT_PASSWORD, "anonymous" => ""}

    anonymous_and_readonly_users.each do |login, password|
      login_as(login,password) unless login == "anonymous"
      open_card(@project, @card_2)
      assert_card_navigation_icon_displayed_for_readonly_property(DEPENDENCY)
      click_card_navigation_icon_for_readonly_property(DEPENDENCY)
      assert_card_name_in_show(@card_3.name)

      open_card(@project, @card_2)
      assert_card_navigation_icon_displayed_for_readonly_property("tree-#{STORY}")
      click_card_navigation_icon_for_readonly_property("tree-#{STORY}")
      assert_card_name_in_show(@card_1.name)
      logout
      end
  end

  def test_card_navigation_icon_for_relationship_property_on_card_old_version
    create_tree_and_add_cards_to_tree
    open_card(@project, @card_2)
    set_relationship_properties_on_card_show("tree-#{STORY}" => "(not set)")

    open_card_version(@project, @card_2.number, 1)
    assert_card_navigation_icon_not_displayed_for_readonly_property("tree-#{STORY}")

    open_card_version(@project, @card_2.number, 2)
    assert_card_navigation_icon_displayed_for_readonly_property("tree-#{STORY}")
    click_card_navigation_icon_for_readonly_property("tree-#{STORY}")
    assert_card_name_in_show(@card_1.name)
  end

  def test_card_navigation_icon_for_card_type_property_on_card_old_version
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_3)

    ensure_browser_logged_in_as(@non_admin_user.login,"longtest")

    open_card_version(@project, @card_1.number, 1)
    assert_card_navigation_icon_not_displayed_for_readonly_property(DEPENDENCY)

    open_card_version(@project, @card_1.number, 2)
    assert_card_navigation_icon_displayed_for_readonly_property(DEPENDENCY)
    click_card_navigation_icon_for_readonly_property(DEPENDENCY)
    assert_card_name_in_show(@card_2.name)
  end

  def test_card_navigation_icon_for_tree_property
      create_tree_and_add_cards_to_tree
      ensure_browser_logged_in_as(@non_admin_user.login,"longtest")

      open_card(@project, @card_2)
      assert_card_navigation_icon_displayed_for_property("tree-#{STORY}")
      click_card_navigation_icon_for_property("tree-#{STORY}")
      assert_card_name_in_show(@card_1.name)

      open_card(@project, @card_2)
      set_relationship_properties_on_card_show("tree-#{STORY}" => "(not set)")
      assert_card_navigation_icon_not_displayed_for_property("tree-#{STORY}")
      set_relationship_properties_on_card_show("tree-#{STORY}" => @card_1)
      assert_card_navigation_icon_displayed_for_property("tree-#{STORY}")
      click_card_navigation_icon_for_property("tree-#{STORY}")
      assert_card_name_in_show(@card_1.name)

      open_card(@project, @card_2)
      set_relationship_properties_on_card_show("tree-#{STORY}" => @card_3)
      assert_card_navigation_icon_displayed_for_property("tree-#{STORY}")
      click_card_navigation_icon_for_property("tree-#{STORY}")
      assert_card_name_in_show(@card_3.name)
  end

  def test_card_navigation_icon_for_card_type_property
    open_card(@project, @card_1)
    assert_card_navigation_icon_not_displayed_for_property(DEPENDENCY)
      set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
      assert_card_navigation_icon_displayed_for_property(DEPENDENCY)
      click_card_navigation_icon_for_property(DEPENDENCY)
      assert_card_name_in_show(@card_2.name)

      open_card(@project, @card_1)
      set_relationship_properties_on_card_show(DEPENDENCY => @card_3)
      click_card_navigation_icon_for_property(DEPENDENCY)
      assert_card_name_in_show(@card_3.name)

      open_card(@project, @card_1)
      set_relationship_properties_on_card_show(DEPENDENCY => "(not set)")
      assert_card_navigation_icon_not_displayed_for_property(DEPENDENCY)
  end

  def test_card_navigation_icon_for_hidden_property
    hide_property(@project,DEPENDENCY)
    open_card(@project, @card_1)
    ensure_hidden_properties_visible
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    assert_card_navigation_icon_displayed_for_property(DEPENDENCY)
    click_card_navigation_icon_for_property(DEPENDENCY)
    assert_card_name_in_show(@card_2.name)
  end

  #bug 5586
  def test_transition_should_be_able_to_set_the_cards_property_value_to_not_set
    @plv = create_project_variable(@project, :name => 'plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :properties => [DEPENDENCY])

    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    new_transition = create_transition_for(@project, 'set dependency to not set', :type => STORY, :set_properties => {DEPENDENCY => "(#{@plv.name})"})
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@card_1, @card_3)
    execute_bulk_transition_action(new_transition)
    assert_bulk_action_for_transitions_applied_for_selected_cards(new_transition.name, @card_3.number, @card_1.number)
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, NOTSET)
  end

  def test_card_property_PLV_can_be_used_in_filter
    @plv = create_project_variable(@project, :name => 'plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :properties => [DEPENDENCY])

    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, DEPENDENCY => plv_display_name(@plv.name))
  end

  def test_search_cards_in_card_selecton_widget_with_card_number
    open_card(@project, @card_1)
    open_card_selection_widget_for_property_from_card_show_page(DEPENDENCY)
    @browser.run_once_full_text_search
    @browser.assert_visible('filter-active-tab')
    search_through_card_selection_widget('#4')
    @browser.assert_text_present("There are no cards matching your criteria.")
    search_through_card_selection_widget('#2')
    assert_card_present_in_card_selector_search_result(@card_2.number)
    search_through_card_selection_widget(@card_1.number.to_s)
    assert_card_present_in_card_selector_search_result(@card_1.number)
    search_through_card_selection_widget('sample card_1')
    assert_card_present_in_card_selector_search_result(@card_1.number)
  end

  def test_filter_cards_in_card_selection_widget_with_card_types
    open_card(@project, @card_1)
    open_card_selection_widget_for_property_from_card_show_page(DEPENDENCY)
    filter_cards_through_card_selection_widget_by_card_type_name('Card')
    @browser.assert_text_present("There are no cards matching your criteria.")
    filter_cards_through_card_selection_widget_by_card_type_name('Defect')
    assert_card_present_in_card_selector_filter_result(@card_2.number)
  end

  def test_bulk_operation_of_card_property_in_list_view
    card_4 = create_card!(:name => 'sample card_4', :card_type => STORY)
    card_5 = create_card!(:name => 'sample card_5', :card_type => STORY)
    navigate_to_view_for(@project, 'list')
    # bulk edit
    check_cards_in_list_view(@card_3, card_4)
    click_edit_properties_button
    set_bulk_properties(@project, DEPENDENCY => @card_2)
    assert_notice_message("2 cards updated.")

    #transition
    create_transiton_to_set_card_property
    navigate_to_view_for(@project, 'list')
    select_none
    check_cards_in_list_view(@card_3,@card_1)
    execute_bulk_transition_action(@transition)
    @browser.assert_text_present("#{@transition.name} successfully applied to cards ##{@card_3.number}, ##{@card_1.number}")

    # delete
    select_none
    check_cards_in_list_view(@card_2, card_5)
    click_bulk_delete_button
    assert_card_delete_confirm_light_box_present
    @browser.assert_text_present("Used as a card relationship property value on 3 cards.")
    click_on_continue_to_delete_link
    assert_notice_message "Cards deleted successfully."
  end

  def test_quick_add_with_default_in_list_grid_view
    navigate_to_view_for(@project, 'list')
    add_card_via_quick_add('with out default',:type => STORY)
    card_added = @project.cards.find_by_name("with out default")
    open_card(@project, card_added)
    assert_property_set_on_card_show(DEPENDENCY, NOTSET)

    create_story_type_default_with_card_property_set
    navigate_to_view_for(@project, 'list')
    add_card_via_quick_add('with default', :type => STORY)
    card_added = @project.cards.find_by_name("with default")
    open_card(@project, card_added)
    assert_property_set_on_card_show(DEPENDENCY, @card_2)
  end

  def test_filtered_by_card_property_in_list_grid_tree_view_and_history_tab
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    # history filter
    navigate_to_history_for @project
    assert_history_for(:card, @card_1.number).version(1).present
    assert_history_for(:card, @card_2.number).version(1).present
    assert_history_for(:card, @card_3.number).version(1).present
    filter_history_using_first_condition_by(@project, DEPENDENCY => card_number_and_name(@card_2))
    assert_history_for(:card, @card_1.number).version(1).not_present
    assert_history_for(:card, @card_2.number).version(1).not_present
    assert_history_for(:card, @card_3.number).version(1).not_present
    assert_history_for(:card, @card_1.number).version(2).present
    # filter and mql filter
    navigate_to_view_for(@project, 'list')
    set_filter_to_type_is_story_dependency_is(@card_2)
    assert_cards_not_present_in_list(@card_2, @card_3)
    assert_card_present_in_list(@card_1)
    set_mql_filter_for("type=#{STORY} and #{DEPENDENCY} != '#{@card_2.name}'")
    assert_cards_not_present_in_list(@card_1, @card_2)
    assert_card_present_in_list(@card_3)
    # tree filter
    create_tree_and_add_cards_to_tree
    navigate_to_tree_view_for(@project, SIMPLE_TREE)
    set_tree_filter_dependency_for_story_type(@card_2)
    assert_cards_showing_on_tree(@card_1, @card_2)
    assert_card_not_showing_on_tree(@card_3)
  end

  def test_card_property_used_in_transition
    create_transiton_to_set_card_property
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, NOTSET)
    click_transition_link_on_card(@transition)
    assert_property_set_on_card_show(DEPENDENCY, @card_2)

    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    navigate_to_view_for(@project, 'list')
    check_cards_in_list_view(@card_1)
    execute_bulk_transition_action(@transition)
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, @card_2)

    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    navigate_to_view_for(@project, 'grid')
    click_on_card_in_grid_view(@card_1.number)
    click_transition_link_on_card_in_grid_view(@transition)
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, @card_2)
  end

  def test_hidden_card_property_became_invisible_in_card_bulk_edit_columns_and_filter
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    create_saved_view_filtered_by_card_property
    hide_property(@project, DEPENDENCY)
    #  card show, card edit
    open_card(@project, @card_1)
    assert_property_not_present_on_card_show(DEPENDENCY)
    click_edit_link_on_card
    assert_property_not_present_on_card_edit(DEPENDENCY)
    #  bulk, column,filter
    navigate_to_view_for(@project, 'list')
    check_cards_in_list_view(@card_1)
    click_edit_properties_button
    @browser.assert_element_not_present("bulk_cardrelationshippropertydefinition_#{@card_property.id}_label")
    assert_properties_not_present_on_add_remove_column_dropdown(@project, [@card_property])
    set_the_filter_value_option(0, STORY)
    add_new_filter
    assert_filter_property_not_present_on(1, :properties => [DEPENDENCY])
    navigate_to_tree_view_for(@project, SIMPLE_TREE)
    add_new_tree_filter_for(@story_type)
    open_tree_filter_property_list(@story_type, 0)
    assert_filter_property_not_available(@story_type, 0, DEPENDENCY)
    #  saved view
    navigate_to_favorites_management_page_for(@project)
    assert_favorites_not_present_on_management_page(@project, @list_view)
    assert_favorites_not_present_on_management_page(@project, @tree_view)
  end

  def test_usage_of_hidden_card_property_in_card_default_and_transition
    create_story_type_default_with_card_property_set
    create_transiton_to_set_card_property

    hide_property(@project, DEPENDENCY)

    navigate_to_view_for(@project, 'list')
    add_new_card('with default', :type => STORY)
    card_added = @project.cards.find_by_name("with default")
    open_card(@project, card_added)
    assert_property_not_present_on_card_show(DEPENDENCY)
    assert_history_for(:card, card_added.number).version(1).shows(:set_properties => { DEPENDENCY => '' })

    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(2).not_present
    click_transition_link_on_card(@transition)

    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(2).shows(:set_properties => { DEPENDENCY => '' })
  end

  def test_usage_of_tran_only_card_property
    create_transiton_to_set_card_property
    make_property_transition_only_for(@project, DEPENDENCY)
    logout
    login_as(@non_admin_user.login, 'longtest')

    open_card(@project, @card_1)
    assert_property_not_editable_on_card_show(DEPENDENCY)
    click_edit_link_on_card
    assert_property_not_editable_on_card_edit(DEPENDENCY)

    navigate_to_view_for(@project, 'list')
    check_cards_in_list_view(@card_1)
    click_edit_properties_button
    assert_property_not_editable_in_bulk_edit_properties_panel(@project, DEPENDENCY)
  end

  #bug 5092
  def test_imported_template_sets_card_defaults_to_not_set_for_card_properties
    login_as_admin_user
    create_story_type_default_with_card_property_set
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_name("#{@project.name} template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    open_edit_defaults_page_for(project_created_from_template, STORY)
    assert_property_set_on_card_defaults(project_created_from_template, DEPENDENCY, NOTSET)
  end

  #bug 5191
  def test_deleting_a_card_that_is_a_value_of_a_card_relationship_property_should_not_set_all_card_relationship_properties_to_NOT_SET
    login_as_admin_user
    other_card = create_property_definition_for(@project, 'other_card', :type => CARD, :types => [STORY])
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    set_relationship_properties_on_card_show('other_card' => @card_3)
    delete_card(@project, @card_2.name)
    assert_property_set_on_card_show(DEPENDENCY, NOTSET)
    assert_property_set_on_card_show('other_card', @card_3)
  end

  private

  def create_tree_and_add_cards_to_tree
    @tree = setup_tree(@project, SIMPLE_TREE, :types => [@story_type, @defect_type],:relationship_names => ["tree-#{STORY}"])
    add_card_to_tree(@tree, @card_1)
    add_card_to_tree(@tree, @card_3)
    add_card_to_tree(@tree, @card_2, @card_1)
  end


  def create_story_type_default_with_card_property_set
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults_and_save_default_for(@project, STORY, :properties => {DEPENDENCY => @card_2})
  end

  def create_transiton_to_set_card_property
    @transition = create_transition_for(@project, 'Set Card Property', :type => STORY, :set_properties => {DEPENDENCY => card_number_and_name(@card_2)})
  end

  def set_filter_to_type_is_story_dependency_is(card)
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_option(1, DEPENDENCY)
    set_the_filter_value_using_select_lightbox(1, card)
  end

  def set_tree_filter_dependency_for_story_type(dependency_value)
    add_new_tree_filter_for @story_type
    set_the_tree_filter_property_option(@story_type, 0, DEPENDENCY)
    set_the_tree_filter_value_option_to_card_number(@story_type, 0, "#{dependency_value.number}")
  end

  def create_saved_view_filtered_by_card_property
     navigate_to_view_for(@project, 'list')
     set_the_filter_value_option(0, STORY)
     add_new_filter
     set_the_filter_property_option(1, DEPENDENCY)
     set_the_filter_value_using_select_lightbox(1, @card_2)
     add_column_for(@project, [DEPENDENCY])
     @list_view = create_card_list_view_for(@project, 'list view')
     create_tree_and_add_cards_to_tree
     # add_card_to_tree(@tree, @card_1)
     # add_card_to_tree(@tree, @card_3)
     # add_card_to_tree(@tree, @card_2, @card_1)
     navigate_to_tree_view_for(@project, SIMPLE_TREE)
     add_new_tree_filter_for @story_type
     set_the_tree_filter_property_option(@story_type, 0, DEPENDENCY)
     set_the_tree_filter_value_option_to_card_number(@story_type, 0, @card_2.number)
     @tree_view = create_card_list_view_for(@project, 'tree view')
  end

end
