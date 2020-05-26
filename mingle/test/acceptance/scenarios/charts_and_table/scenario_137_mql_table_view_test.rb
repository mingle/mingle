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

# Tags: macro
class Scenario137MqlTableViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  
  TABLE_VIEW = 'table-view'
  
  PRIORITY = "priority"
  SAVED_VIEW = 'foo'
  HIGH = 'high'
  BUG = 'bug'
  STORY = 'story'
  SIMPLE_CARD = 'simple card'
  TEXT_FILED = 'text_field'
  OWNER = 'owner'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_137', :admins => [@project_admin_user, users(:admin)])
    @priority = setup_property_definitions(PRIORITY => [HIGH])
    @text_field = setup_property_definitions(TEXT_FILED => [SAVED_VIEW])

    @type_bug = setup_card_type(@project, BUG, :properties => [PRIORITY, TEXT_FILED])
    login_as_proj_admin_user
    @simple_card = create_card!(:name => SIMPLE_CARD, PRIORITY => HIGH, TEXT_FILED => SAVED_VIEW)
  end
  
  def select_table_view_macro_editor
    click_toolbar_wysiwyg_editor('Insert Table View')
    @browser.wait_for_element_present(macro_editor_popup)
    sleep 1
  end
    
  def test_macro_editor_preview_for_table_view_on_card_edit
    create_a_saved_view
    error_message_of_empty_input = "Error in table macro: Need to specify query or view"
    open_card(@project, @simple_card)
    click_edit_link_on_card
    select_table_view_macro_editor
    type_macro_parameters(TABLE_VIEW, :view => "")
    click_preview
    @browser.wait_for_element_present "css=#macro_preview .error"
    preview_content_should_include(error_message_of_empty_input)

    type_macro_parameters(TABLE_VIEW, :view => "cookie")
    click_preview
    @browser.wait_for_element_present "css=#macro_preview .error"
    sleep 0.5
    preview_content_should_include("Error in table macro: No such view: cookie")

    type_macro_parameters(TABLE_VIEW, :view => SAVED_VIEW)

    click_preview
    @browser.wait_for_element_present "css=#macro_preview > table"
    preview_content_should_include(SIMPLE_CARD, HIGH)
  end
  
  def test_links_are_clickable_on_macro_editor_preview_for_table_view_macro_on_card_edit
    create_a_saved_view
    open_card(@project, @simple_card)
    click_edit_link_on_card
    select_table_view_macro_editor
    type_macro_parameters(TABLE_VIEW, :view => SAVED_VIEW)
    click_preview
    @browser.wait_for_element_present "css=#macro_preview > table"
    click_link(SIMPLE_CARD)
    assert_card_location_in_card_show(@project, @simple_card)
    assert_card_name_in_show(SIMPLE_CARD)
  end

  def test_links_are_correctly_html_escaped
    @html_name_card = create_card!(:name => '<b>card</b>', PRIORITY => HIGH, TEXT_FILED => SAVED_VIEW)
    create_a_saved_view('<b>hello</b>')
    open_card(@project, @simple_card)
    click_edit_link_on_card
    insert_table_view_macro_and_save('<b>hello</b>')
    wait_for_card_contents_to_load
    assert_table_row_data_for('page', :row_number => 1, :cell_values => ['2','<b>card</b>', 'high'])
    click_link(@html_name_card.name)
    assert_card_location_in_card_show(@project, @html_name_card)
  end

  def test_can_use_this_card_property_value_for_the_name_parameter
    create_a_saved_view
    open_card(@project, @simple_card.number)
    click_edit_link_on_card
    select_table_view_macro_editor
    type_macro_parameters(TABLE_VIEW, :view => "THIS CARD.#{TEXT_FILED}")
    click_preview
    @browser.wait_for_element_present("css=#macro_preview table")

    preview_content_should_include(SIMPLE_CARD, HIGH)

    click_insert_on_macro_editor
    # click_cancel_on_wysiwyg_editor

    save_card
    assert_table_cell_on_preview(0, 0, "Number")
    assert_table_cell_on_preview(0, 1, "Name")
    assert_table_cell_on_preview(0, 2, "priority")
    assert_table_cell_on_preview(1, 1, "#{SIMPLE_CARD}")
    assert_table_cell_on_preview(1, 2, "#{HIGH}")
  end

  def test_table_view_should_show_and_sort_display_name_and_login_name 
    logins_and_display_names = [
      {:login => 'a_admin', :name => "admin"},
      {:login => 'b_admin', :name => "admin"},
      {:login => 'cap',     :name => "B admin"},
      {:login => 'uncap',   :name =>  "b admin"},
      {:login => 'c_admin', :name => "c admin"},
    ]

    expected_table = [
      {:row_number => 1, :cell_value => ["2", "cookie", "admin (a_admin)"]},
      {:row_number => 2, :cell_value => ["3", "cookie", "admin (b_admin)"]},
      {:row_number => 3, :cell_value => ["4", "cookie", "B admin (cap)"]},
      {:row_number => 4, :cell_value => ["5", "cookie", "b admin (uncap)"]},
      {:row_number => 5, :cell_value => ["6", "cookie", "c admin (c_admin)"]},
    ]

    users_used_in_table_view = create_new_users(logins_and_display_names)        
    property_used_in_table_view = setup_user_definition(OWNER).update_attributes(:card_types => [@project.card_types.find_by_name("Card")])
    users_used_in_table_view.each do |user|
      @project.add_member(user)
      card_used_in_table_view = create_card!(:name => 'cookie', :card_type => 'Card', OWNER =>  user.id) 
    end   
    saved_view_used_in_table_view = create_a_saved_view_for_table_view('table view')

    open_card_for_edit(@project, 1)
    table_view_name = add_table_view_query_and_save(saved_view_used_in_table_view.name)
    expected_table.each do |row|
      assert_table_row_data_for(table_view_name, :row_number  =>  row[:row_number], :cell_values => row[:cell_value])     
    end  

    destroy_users_by_logins(users_used_in_table_view.collect(&:login))
  end


  private
  def create_a_saved_view(view_name = SAVED_VIEW)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [PRIORITY])
    create_card_list_view_for(@project, view_name)
  end
  
  def create_a_saved_view_for_table_view(view_name)
    navigate_to_project_overview_page(@project)
    set_filter_by_url(@project, "filters[]=[Type][is][Card]&filters[]=[#{OWNER}][is+not][]")
    add_column_for(@project, [OWNER])
    sort_by(OWNER)
    saved_view = create_card_list_view_for(@project, 'table view')   
  end
end
