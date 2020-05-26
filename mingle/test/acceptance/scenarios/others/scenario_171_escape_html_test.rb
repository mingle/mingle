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
# Tags: html

class Scenario171EscapeHtmlTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session

    @project = create_project(:prefix => 'scenario_171', :admins => [users(:admin)])
    login_as_admin_user
    open_project(@project)
  end

  def test_property_and_value_should_be_html_escaped_in_table_query
    property_with_html_tag = '<h3>status</h3>'
    value_with_html_tag = '<h3>open</h3>'
    setup_property_definitions(property_with_html_tag => [value_with_html_tag])
    create_card! :name => 'card1', property_with_html_tag => value_with_html_tag

    edit_overview_page
    create_free_hand_macro("table query: SELECT '#{property_with_html_tag}'")
    assert_html_escaped_in(property_with_html_tag, CardEditPageId::RENDERABLE_CONTENTS)
    assert_html_escaped_in(value_with_html_tag, CardEditPageId::RENDERABLE_CONTENTS)
  end

  def test_team_favorites_name_should_be_html_escaped
    team_favorites_with_html_tag = '<div>team_fav</div>'
    team_favorite_2_with_html_tag = '<h3>team_fav</h3>'
    navigate_to_card_list_for(@project)
    fav = create_card_list_view_for(@project, team_favorites_with_html_tag)
    fav2 = create_card_list_view_for(@project, team_favorite_2_with_html_tag)
    assert_card_favorites_link_present(team_favorites_with_html_tag)
    assert_card_favorites_link_present(team_favorite_2_with_html_tag)

    navigate_to_favorites_management_page_for(@project)
    assert_html_escaped_in(team_favorites_with_html_tag, 'favorites')
    assert_html_escaped_in(team_favorite_2_with_html_tag, 'favorites')

    toggle_tab_for_saved_view(fav)
    toggle_tab_for_saved_view(fav2)
    assert_html_escaped_in(team_favorites_with_html_tag, tab_link_id(team_favorites_with_html_tag))
    assert_html_escaped_in(team_favorite_2_with_html_tag, tab_link_id(team_favorite_2_with_html_tag))

    card1 = create_card! :name => 'card1'
    @browser.open("/projects/#{@project.identifier}/cards/list?style=list&tab=#{team_favorites_with_html_tag}")
    click_card_on_list(card1)
    rendered_html = @browser.get_raw_inner_html("up")
    assert_include("&lt;div&gt;team_...", rendered_html)

    card2 = create_card! :name => 'card2'
    @browser.open("/projects/#{@project.identifier}/cards/list?style=list&tab=#{team_favorite_2_with_html_tag}")
    click_card_on_list(card2)
    rendered_html = @browser.get_raw_inner_html("up")
    assert_include("&lt;h3&gt;team_f...", rendered_html)
  end

  def test_filter_in_favorites_should_be_html_escaped
    property_with_html_tag = '<h3>status</h3>'
    value_with_html_tag = '<h3>open</h3>'
    setup_property_definitions(property_with_html_tag => [value_with_html_tag])
    create_card! :name => 'card1', property_with_html_tag => value_with_html_tag

    my_favorites_with_html_tag = '<script>status is open</script>'
    set_filter_by_url(@project, "filters[]=[#{property_with_html_tag}][is][#{value_with_html_tag}]")

    fav = create_card_list_view_for(@project, my_favorites_with_html_tag, :personal => true)
    assert_card_favorites_link_present(my_favorites_with_html_tag)

    go_to_profile_page

    assert_html_escaped_in(my_favorites_with_html_tag, "global_personal_views")
  end

  def test_project_name_should_be_html_escaped
    name_with_html = '<h1>foo</foo>'
    @project.update_attribute(:name, name_with_html)
    navigate_to_all_projects_page
    assert_html_escaped_in(name_with_html, css_locator('.project-description'))

    delete_project_permanently(@project)
    assert_html_escaped_in(name_with_html, 'notice')
  end

  def test_tree_name_should_be_html_escaped_on_relationship_name_auto_suggestion
    name_with_html = '<h1>tree</h1>'
    setup_card_type(@project, 'STORY')
    navigate_to_tree_configuration_management_page_for(@project)
    click_create_new_card_tree_link
    type_tree_name(name_with_html)
    select_type_on_tree_node(0, 'Card')
    assert_relationship_property_name_on_tree_configuration("#{name_with_html.escape_html} - Card")

    click_link("Save and configure aggregates")
    assert_relationship_property_name_on_tree_configuration("#{name_with_html.escape_html} - Card")
  end

  def test_tree_property_on_card_show_and_card_edit_should_be_html_escaped
    name_with_html = '<h1>tree</h1>'
    card_type = @project.card_types.first
    story_type = setup_card_type(@project, 'STORY')
    card1 = create_card!(:name => 'card1', :card_type => card_type.name)
    story1 = create_card!(:name => 'story1', :card_type => story_type.name)

    relationship_name = "#{name_with_html} - Card"
    tree = setup_tree(@project, name_with_html, :types => [card_type, story_type], :relationship_names => [relationship_name])
    add_card_to_tree(tree, card1)
    add_card_to_tree(tree, story1, card1)

    open_card(@project, story1)
    assert_html_escaped_in(name_with_html, css_locator('.go-to-tree-link'))

    relationship = @project.tree_configurations.first.relationships.first
    assert_html_escaped_in(name_with_html, property_editor_property_name_id(relationship, "show"))
  end

  def test_user_input_on_recover_password_page_should_be_html_escaped
    name_with_html = '<h1>foo</h1>'
    recover_password_for(name_with_html)
    assert_html_escaped_in(name_with_html, "error")
  end

  def test_user_name_on_user_search_result_should_be_html_escaped
    navigate_to_user_management_page
    user_with_html = users(:user_with_html)
    search_user_in_user_management_page(user_with_html.name)
    assert_html_escaped_in(user_with_html.name, "info")
  end

  def test_user_name_should_be_html_escaped_when_updating_profile
    user_with_html = users(:user_with_html)
    edit_user_profile_details(user_with_html)
    assert_html_escaped_in(user_with_html.name, 'notice')
  end

  def test_card_type_should_be_html_escaped_when_delete
    name_with_html = '<h1>foo</h1>'
    setup_card_type(@project, name_with_html)
    get_the_delete_confirm_message_for_card_type(@project, name_with_html)
    assert_html_escaped_in(name_with_html, css_locator('#deletion_warnings'))
  end

  def test_project_name_should_be_html_escaped_when_copying_a_card
    name_with_html = '<h1>foo</h1>'
    card1 = create_card!(:name => 'card1')
    create_project(:prefix => name_with_html)
    open_card(@project, card1)
    click_copy_to_link
    click_select_project_link
    assert_html_escaped_in(name_with_html,'select_project_drop_down')
  end

  def test_favorite_name_should_be_html_escpaed_when_try_to_hide_a_property_used_in_this
    setup_property_definitions('status' => ['open'])
    set_filter_by_url(@project, "filters[]=[status][is][open]")
    favorites_with_html_tag = '<h1>foo</h1>'

    create_card_list_view_for(@project, favorites_with_html_tag)
    hide_property(@project, 'status')

    assert_html_escaped_in(favorites_with_html_tag, 'notice')
  end

  def test_user_name_should_be_html_escaped_when_changing_password
    user_with_html = users(:user_with_html)
    change_password_for(user_with_html, MINGLE_TEST_DEFAULT_PASSWORD, current_password = nil)
    assert_html_escaped_in(user_with_html.name, 'notice')
  end

  def test_template_name_should_be_html_escaped_when_create_new_project_using_template
    name_with_html = '<h3>foo</h3>'
    project = create_project(:prefix => name_with_html)
    create_template_for(project)
    navigate_to_all_projects_page
    click_new_project_link
    assert_html_escaped_in(name_with_html, 'template-list')
  end

  def test_free_text_property_value_should_be_html_escaped_on_card_edit_page
    setup_allow_any_text_property_definition("free")
    card1 = create_card! :name => 'card1'
    open_card_for_edit(@project, card1)

    value_with_html_tag = '<h1>foo</h1>'
    add_new_value_to_property_on_card_edit(@project, 'free', value_with_html_tag)
    assert_html_escaped_in(value_with_html_tag, 'edit-properties')
  end

  def test_property_name_should_be_html_escaped_in_card_updating_message
    property_with_html_tag = '<h3>status</h3>'
    setup_property_definitions(property_with_html_tag => [])
    card1 = create_card! :name => 'card1'
    open_card(@project, card1)
    add_new_value_to_property_on_card_show(@project, property_with_html_tag, '(whatever)')
    assert_html_escaped_in(property_with_html_tag, 'error')
    open_card_for_edit(@project, card1)
    add_new_value_to_property_on_card_edit(@project, property_with_html_tag, '(whatever)')
    save_card_with_flash
    @browser.wait_for_element_present('error')
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_card_defaults_update_message
    property_with_html_tag = '<h3>status</h3>'
    setup_property_definitions(property_with_html_tag => [])
    open_edit_defaults_page_for(@project, 'card')
    set_property_defaults_via_inline_value_add(@project, property_with_html_tag, '(foo)')
    click_save_defaults
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_transition_crud_message
    property_with_html_tag = '<h3>address</h3>'
    setup_allow_any_text_property_definition(property_with_html_tag)
    create_transition_for(@project, 'transition', :set_properties => { property_with_html_tag => '(foo)'})
    assert_html_escaped_in(property_with_html_tag, 'error')

    transition = create_transition_for(@project, 'transition', :set_properties => { property_with_html_tag => 'foo'})
    edit_transition_for(@project, transition, :set_properties => {property_with_html_tag => '(bar)'})
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_execute_transition_message
    property_with_html_tag = '<h3>address</h3>'
    setup_allow_any_text_property_definition(property_with_html_tag)
    transition = create_transition(@project, 'transition', :set_properties => { property_with_html_tag => '(user input - required)'})
    card1 = create_card!(:name => 'card1')
    open_card(@project, card1)
    click_transition_link_on_card(transition)
    add_value_to_free_text_property_lightbox_editor_on_transition_complete(property_with_html_tag => '(foo)')
    click_on_complete_transition
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_bulk_edit_message
    property_with_html_tag = '<h3>address</h3>'
    prop_def = setup_allow_any_text_property_definition(property_with_html_tag)
    card1 = create_card! :name => 'card1'
    click_all_tab
    select_all
    click_edit_properties_button
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(prop_def, '(foo)')
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_excel_import_error_message
    property_with_html_tag = '<h3>address</h3>'
    navigate_to_grid_view_for(@project)
    header_row = ['name', 'type', property_with_html_tag]
    card_data = [['cardname', 'Card', '(foo)']]
    import(excel_copy_string(header_row, card_data))
    assert_html_escaped_in(property_with_html_tag, 'error')
  end

  def test_property_name_should_be_html_escaped_in_aggregate_description_on_tree_config_view
    property_with_html_tag = '<h3>size</h3>'
    aggregate_name_with_html_tag = '<h1>sum size</h1>'
    size_property = setup_numeric_property_definition(property_with_html_tag, [1])

    type_story = setup_card_type(@project, 'story', :properties => [property_with_html_tag])
    type_iteration = setup_card_type(@project, 'iteration')
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [type_iteration, type_story], :relationship_names => ['PT iteration'])

    aggregate_property = setup_aggregate_property_definition(aggregate_name_with_html_tag, AggregateType::SUM, size_property, planning_tree.id, type_iteration.id, type_story)
    open_aggregate_property_management_page_for(@project, planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(type_iteration)
    assert_html_escaped_in(property_with_html_tag, "aggregate_description_0")
    assert_html_escaped_in(aggregate_name_with_html_tag, "aggregate_description_0")
  end

  def test_formula_should_be_html_escaped_in_error_message
    formula_with_html_tag = '<h1>foo' #'/' in '</h1>' will be treated as operator
    create_property_definition_for(@project, 'formula', :type => 'formula', :formula => formula_with_html_tag)
    assert_html_escaped_in(formula_with_html_tag, 'error')
  end

  def test_transition_name_should_be_html_escaped_in_transition_crud_message
    setup_allow_any_text_property_definition("free")
    name_with_html_tag = '<h3>transition</h3>'
    transition = create_transition_for(@project, name_with_html_tag, :set_properties => { 'free' => 'foo'})
    assert_html_escaped_in(name_with_html_tag, 'notice')

    edit_transition_for(@project, transition, :set_properties => { 'free' => 'bar'})
    assert_html_escaped_in(name_with_html_tag, 'notice')
  end

  def test_user_name_should_be_by_html_escaped_in_transition_management_page
    user_with_html = users(:user_with_html)
    setup_allow_any_text_property_definition("free")
    @project.add_member(user_with_html)
    transition = create_transition(@project, 'transition', :set_properties => { 'free' => 'foo' }, :user_prerequisites => [user_with_html.id])
    navigate_to_transition_management_for(@project)
    assert_html_escaped_in(user_with_html.name, "transition-#{transition.id}")
  end

  def test_unsubscribe_message_should_be_html_escaped_on_profile_page
    name_with_html_tag = '<h1>foo</h1>'
    @project.update_attribute('name', name_with_html_tag)
    navigate_to_history_for(@project)
    click_subscribe_via_email

    card = create_card!(:name => name_with_html_tag)
    open_card(@project, card.number)
    click_subscribe_via_email

    go_to_profile_page

    click_unsubscribe_on_subscriptions_table('global', 0)
    assert_html_escaped_in(name_with_html_tag, 'notice')

    click_unsubscribe_on_subscriptions_table('card', 0)
    assert_html_escaped_in(name_with_html_tag, 'notice')
  end

  def test_card_type_and_property_name_should_be_html_escaped_in_transition_workflow_error_messages
    card_type_name_with_html_tag = '<h1>bar</h1>'
    card_type = setup_card_type(@project, card_type_name_with_html_tag)

    property_name_with_html_tag = '<h1>foo</h1>'
    setup_property_definitions(property_name_with_html_tag => [1])

    create_transition @project, 'transition', :card_type => card_type, :set_properties => { property_name_with_html_tag => '1' }
    navigate_to_transition_management_for(@project)
    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(card_type_name_with_html_tag)
    select_property_for_transtion_work_flow(property_name_with_html_tag)
    assert_html_escaped_in(card_type_name_with_html_tag, css_locator('.warning-box'))
    assert_html_escaped_in(property_name_with_html_tag, css_locator('.warning-box'))
  end

  #9673
  def test_html_in_error_message_for_project_rolls_up_should_not_be_escaped
    expected_error = "Error in cross-project-rollup macro: Parameter 'rows' is required"
    card1 = create_card! :name => 'card1'
    open_card_for_edit(@project, card1)
    cross_project_rollup_content = %{
        cross-project-rollup
        project-group:
        rows:
        rows-conditions:
        columns:
        -    label: count of stories
             aggregate: count(*)
             conditions:
      }
    paste_query(cross_project_rollup_content)
    assert_mql_error_messages(expected_error)
  end

  #bug 9486
  def test_show_mail_to_and_xmpp_properly_on_wiki
    open_project(@project)
    edit_overview_page
    type_page_content(%{<a href="mailto:astark1@unl.edu">mail to astark</a> sdfdf <a href="xmpp:hmli@conference.chistdmng13.thoughtworks.com">xmpp</a>})
    with_ajax_wait {click_save_link}
    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$$('#content a')[0].innerHTML"), "astark1@unl.edu")
    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$$('#content a')[0].href"), "mailto:astark1@unl.edu")

    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$$('#content a')[1].innerHTML"), "hmli@conference.chistdmng13.thoughtworks.com")
    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$$('#content a')[1].href"), "mailto:hmli@conference.chistdmng13.thoughtworks.com")
  end

  private
  def assert_html_escaped_in(to_be_escaped, container_element)
      assert_include(to_be_escaped.escape_html, @browser.get_raw_inner_html(container_element))
  end
end
