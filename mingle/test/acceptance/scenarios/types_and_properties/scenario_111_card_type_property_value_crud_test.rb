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

#Tags: card-properties
class Scenario111CardTypePropertyValueCrudTest < ActiveSupport::TestCase

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

  NOT_NOT_SETSET = '(not set)'
  SIMPLE_TREE = 'simple tree'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenari_111',:admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => ['high', 'low'], STATUS => ['new',  'close', 'open'])
    @story_type = setup_card_type(@project, STORY, :properties => [PRIORITY])
    @defect_type = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS])

    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'sample card_1', :card_type => STORY, PRIORITY => 'high')
    @card_2 = create_card!(:name => 'sample dependency', :card_type => DEFECT)
    @card_3 = create_card!(:name => 'sample card_3', :card_type => STORY)
    @card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => [STORY])
  end

  def test_change_and_rename_card_type_which_is_used_as_card_property_value
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    assert_history_for(:card, @card_1.number).version(3).not_present

    navigate_to_view_for(@project, 'list')
    check_cards_in_list_view(@card_2)
    click_edit_properties_button
    set_bulk_properties(@project, 'Type' => STORY)
    edit_card_type_for_project(@project, STORY, :new_card_type_name => "new story" )

    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(3).not_present
  end

  def test_rename_card_title_which_is_used_as_card_property_value
    have_everything_prepared_for_test_change_card_property_value(:has_tree => true)
    new_card_name = 'new name'

    open_card(@project, @card_2)
    edit_card(:name => new_card_name)
    renamed_card = @project.cards.find_by_name(new_card_name)

    # default
    open_edit_defaults_page_for(@project, STORY)
    assert_property_set_on_card_defaults(@project, DEPENDENCY, renamed_card)
    # transition
    open_transition_for_edit(@project, @transition.name)
    assert_sets_property(DEPENDENCY => card_number_and_name(renamed_card))
    # plv
    open_project_variable_for_edit(@project, @plv)
    assert_value_for_project_variable(@project, @plv, renamed_card)
    #  card show, card edit
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, renamed_card)
    # saved view, popup
    open_saved_view ('list view')
    assert_selected_value_for_the_filter(1, card_number_and_name(renamed_card))
    open_saved_view ('tree view')
    assert_selected_value_for_the_tree_filter(@story_type, 0, card_number_and_name(renamed_card))
    click_on_card_in_tree(@card_1)
    assert_property_on_popup_on_tree_view("dependency:#2newname", @card_1.number, 2)
    # history
    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(2).shows(:set_properties => {DEPENDENCY => '#2 new name'})
    assert_history_for(:card, @card_1.number).version(3).not_present
  end

  def test_delete_card_which_is_used_as_card_property_value
    have_everything_prepared_for_test_change_card_property_value(:has_tree => false)
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(3).not_present
    open_card(@project, @card_2)
    click_card_delete_link
    sleep 5
    @browser.assert_text_present("Used as a card relationship property value on 1 card.")
    @browser.assert_text_present("The following 1 transition will be deleted: #{@transition.name}.")
    # bug #5125
    @browser.assert_text_present("The following 1 project variable will be (not set): #{@plv.name}.")
    click_continue_to_delete_on_confirmation_popup
    # default
    open_edit_defaults_page_for(@project, STORY)
    # bug #5127
    assert_property_set_on_card_defaults(@project, DEPENDENCY, NOT_SET)

    # transition
    assert_transition_not_present_on_managment_page_for @project,@transition.name
    # plv
    open_project_variable_for_edit(@project, @plv)
    assert_value_for_project_variable(@project, @plv, NOT_SET)
    assert_properties_present_for_association_to_project_variable(@project, DEPENDENCY)
    # history bug #4998
    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(3).shows(:changed => DEPENDENCY, :from => 'deleted card', :to => NOT_SET)
    assert_history_for(:card, @card_1.number).version(2).shows(:set_properties => {DEPENDENCY => 'deleted card'})
  end

  def test_delete_card_which_is_value_of_card_date_type_plv
    have_everything_prepared_for_test_delete_card_date_type_plv_value

    open_card(@project, @card_2)
    click_card_delete_link
    # bug #5125
    @browser.assert_text_present("The following 1 transition will be deleted: #{@transition.name}.")
    @browser.assert_text_present("The following 1 project variable will be (not set): #{@plv.name}.")
    click_on_continue_to_delete_link
    # plv
    open_project_variable_for_edit(@project, @plv)
    assert_value_for_project_variable(@project, @plv, NOT_SET)
    # bug #5125
    assert_properties_present_for_association_to_project_variable(@project, DEPENDENCY)

    # transition
    # bug #5125
    assert_transition_not_present_for(@project, @transition)
  end

  def test_card_property_value_can_be_updated_via_import_from_excel
    header_row = ['number', 'name', 'type','dependency']
    card_data = [["#{@card_1.number}", "#{@card_1.name}", STORY,'#2']]

    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, NOT_SET)

    navigate_to_view_for(@project, 'list')
    import(excel_copy_string(header_row, card_data))
    open_card(@project, @card_1)
    assert_property_set_on_card_show(DEPENDENCY, @card_2 )

    wrong_card_data = [["#{@card_1.number}", "#{@card_1.name}", STORY,'#200']]
    navigate_to_view_for(@project, 'list')
    import(excel_copy_string(header_row, wrong_card_data))
    assert_error_message("Cards were not imported. 200 is not a valid card number.")
  end

  # transition, plv, saved view, card default
  def test_create_from_template_when_cards_are_used_as_card_property_value
    have_everything_prepared_for_test_change_card_property_value(:has_tree => true)
    logout
    login_as_admin_user
    project_template = create_template_and_activate_it(@project)
    new_project_name = 'created_from_template'
    new_project = create_new_project_from_template(new_project_name, project_template.identifier)
    # plv
    new_plv = new_project.project_variables.find_by_name(@plv.name)
    navigate_to_project_variable_management_page_for(new_project_name)
    assert_project_variable_present_on_property_management_page(new_plv.name)
    open_project_variable_for_edit(new_project, new_plv)
    assert_value_for_project_variable(new_project, new_plv, NOT_SET)
    # transition
    new_transition_name = @transition.name
    open_transition_for_edit(new_project, new_transition_name)
    assert_sets_property(DEPENDENCY => NOT_SET)
    # default
    open_edit_defaults_page_for(new_project, STORY)
    assert_property_set_on_card_defaults(new_project, DEPENDENCY, NOT_SET)
    # saved view
    assert_nil new_project.card_list_views.find_by_name(@list_view.name)
    assert_nil new_project.card_list_views.find_by_name(@tree_view.name)
  end

  #bug 8332
  def test_should_validate_tree_names_are_less_than_255_characters
    login_as_admin_user
    open_create_new_tree_page_for(@project)
    type_tree_name("a" * 256)
    type_description("tree name too long")
    save_tree_permanently
    @browser.assert_element_present(css_locator("#error"))
  end

  private
  def have_everything_prepared_for_test_change_card_property_value(options = {})
    create_story_type_default_with_card_property_set_to(@card_2)
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_2)
    @transition = create_transition_for(@project, 'Set Card Property', :type => STORY, :set_properties => {DEPENDENCY => card_number_and_name(@card_2)})
    create_list_view_filted_by_card_property
    create_plv_card_data_type_set_value_to('Any card type', @card_2)
    has_tree = options[:has_tree] || false
    create_tree_view_filted_by_card_property if has_tree == true
  end

  def have_everything_prepared_for_test_delete_card_date_type_plv_value
    create_plv_card_data_type_set_value_to('Any card type', @card_2)
    @transition = create_transition_for(@project, 'Set Card Property', :type => STORY, :set_properties => {DEPENDENCY => plv_display_name(@plv.name)})
    navigate_to_view_for(@project, 'list')
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_option(1, DEPENDENCY)
    set_the_filter_value_option(1, plv_display_name(@plv.name))
    @list_view = create_card_list_view_for(@project, 'list view')
  end

  def create_list_view_filted_by_card_property
     navigate_to_view_for(@project, 'list')
     set_the_filter_value_option(0, STORY)
     add_new_filter
     set_the_filter_property_option(1, DEPENDENCY)
     set_the_filter_value_using_select_lightbox(1, @card_2)
     add_column_for(@project, [DEPENDENCY])
     @list_view = create_card_list_view_for(@project, 'list view')
   end

   def create_tree_view_filted_by_card_property
     create_tree_and_add_cards_to_tree
     add_card_to_tree(@tree, @card_1)
     add_card_to_tree(@tree, @card_3)
     add_card_to_tree(@tree, @card_2, @card_1)
     navigate_to_tree_view_for(@project, SIMPLE_TREE)
     add_new_tree_filter_for @story_type
     set_the_tree_filter_property_option(@story_type, 0, DEPENDENCY)
     set_the_tree_filter_value_option_to_card_number(@story_type, 0, @card_2.number)
     @tree_view = create_card_list_view_for(@project, 'tree view')
  end

  def create_tree_and_add_cards_to_tree
    @tree = setup_tree(@project, SIMPLE_TREE, :types => [@story_type, @defect_type],:relationship_names => ["tree-#{STORY}"])
    add_card_to_tree(@tree, @card_1)
    add_card_to_tree(@tree, @card_3)
    add_card_to_tree(@tree, @card_2, @card_1)
  end

  def create_story_type_default_with_card_property_set_to(value)
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults_and_save_default_for(@project, STORY, :properties => {DEPENDENCY => value})
  end

  def create_plv_card_data_type_set_value_to(card_type, card)
    @plv = create_project_variable(@project, :name => 'project_variable_name', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => card_type, :value => card, :properties => DEPENDENCY)
  end

end
