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

require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_env_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_assertions.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_helper.rb')
include UpgradeTestAssertions
include UpgradeTestHelper

class UpgradeTest02 < ActiveSupport::TestCase

  # PROJECT_1 = ARGV[0]

  # TARGET_PROJECT = get_project_name
  # TEST_DATA_DIR = get_test_data_dir

  # PROJECT_IDENTIFIER = "project_#{ENV['MIGRATE_FROM']}"
  PROJECT_IDENTIFIER = "patch_testing_id"
  # PROJECT_IDENTIFIER = "project_pg_2_3"
  DATA_FOLDER = File.expand_path("test/upgrade_test_automation/data")
  BULK_TAG_NAME1 = 'Bush_tagged'
  BULK_TAG_NAME2 = 'Obama_tagged'
  BULK_TAG_NAME3 = 'Terminator_Tagged'
  SINGLE_TAG_NAME1 = 'apple'
  SINGLE_TAG_NAME2 = 'peach'

  FIXEDSIZE = 'fixed size'

  NEW_CARD_NAME = 'new card name'
  BRAND_NEW_PROJECT = "brand_new_project"
  MURMURS = 'Simple Murmur'
  HIDDEN_DATE_PROPERTY = "I am the hidden date!"
  HIDDEN_NUMBER_PROPERTY = "I am the hidden number!"

# 'trend-line-width',

  DATA_SERIES_CHART_CHART_LEVEL_PARAMETERS = ['x-labels-conditions','show-start-label', 'x-labels-property', 'x-title', 'y-title','three-d', 'x-labels-tree', 'data-point-symbol',
     'data-labels', 'chart-height', 'chart-width', 'plot-height', 'plot-width', 'plot-x-offset', 'plot-y-offset', 'label-font-angle', 'legend-top-offset', 'legend-offset', 'legend-max-width',
     'start-label', 'chart-type', 'line-width', 'line-style', 'trend', 'trend-scope', 'trend-ignore', 'trend-line-color', 'trend-line-style', 'project', 'trend-line-width']
  DATA_SERIES_CHART = 'data-series-chart'

  def setup
    @browser = selenium_session
    @user = @browser
    navigate_to_all_projects_page
  end

  def teardown
    self.class.close_selenium_sessions
  end

  def test_01_can_quick_add_card
    p "--------------------------------------------------------------------"
    p "             quick add one card to #{PROJECT_IDENTIFIER}            "
    p "--------------------------------------------------------------------"
    log_in_upgraded_instance_as_admin
    @browser.open "/projects/#{PROJECT_IDENTIFIER}/cards"
    type_card_name("test_01_can_quick_add_card")
    click_add_property_value_button
    @browser.assert_text_present("was successfully created.")
  end

  def test_02_add_tag_for_single_card
    p "--------------------------------------------------------------------"
    p "             add tags apple, peach for the 1st card                 "
    p "--------------------------------------------------------------------"
    @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards/1")
    log_in_upgraded_instance_as_admin
    tag_add = ["apple", "peach"]
    # tags_after = ["apple", "I am with tag one!", "I am with tag two!", "peach", "tag for iterations", "tag for stories", "tag by xy", "we are release!"]
    tag_with(tag_add)
    # assert_tag_in_widget(tags_after.smart_sort)
    #
    # navigate_to_card(@project, card)
    # assert_tag_in_widget(tags_after.smart_sort)
    #
    # edit_card(:name => 'making sure edit does not remove tags')
    # navigate_to_card(@project, card)
    # assert_tag_in_widget(tags_after.smart_sort)
  end

  def test_03_add_tag_for_multiple_cards
    p "--------------------------------------------------------------------"
    p "                     add tag for multiple cards                     "
    p "--------------------------------------------------------------------"
    @browser.open "/projects/#{PROJECT_IDENTIFIER}/cards"
    log_in_upgraded_instance_as_admin
    select_all
    click_bulk_tag_button
    bulk_tag_with(BULK_TAG_NAME1)
    assert_value_present_in_tagging_panel "All tagged:.*#{BULK_TAG_NAME1}"
    # HistoryGeneration.run_once
    # cards.each do |card|
    #   @browser.open("/projects/#{@project.identifier}/cards/#{card.number}")
    #   assert_history_for(:card, card.number).version(2).shows(:tagged_with => tag)
    # end
  end

  # def test_04_import_project
  #   p "--------------------------------------------------------------------"
  #   p "                  import a project (rabbit icon)                    "
  #   p "--------------------------------------------------------------------"
  #   log_in_upgraded_instance_as_admin
  #   @browser.click_and_wait('link=Import project')
  #   @browser.type "import", "#{PROJECTS_DIR}/projects/rabbit.mingle"
  #   @browser.click_and_wait('link=Import project')
  #   sleep 60
  #   @browser.wait_for_element_present("tab_overview_link")
  #   assert_text_present("Project import complete")
  #   @browser.click_and_wait("link=All projects")
  #   @browser.assert_element_present("link=rabbit")
  # end

  #3.0 macro editor
   # def test_06_user_can_use_macro_editor_for_creating_pie_chart
   #  @browser.open("/projects/#{PROJECT_IDENTIFIER}")
   #  log_in_upgraded_instance_as_admin
   #  @browser.wait_for_element_present("page-edit-link-top")
   #  @browser.click_and_wait("page-edit-link-top")
   #  select_macro_editor(PIE_CHART)
   #  assert_should_see_macro_editor_lightbox
   #  assert_macro_parameters_field_exist(PIE_CHART, PIE_CHART_ALL_PARAMETERS)
   #  assert_macro_parameters_visible(PIE_CHART, PIE_CHART_DEFAULT_PARAMETERS)
   #  assert_macro_parameters_not_visible(PIE_CHART, PIE_CHART_NON_DEFAULT_PARAMETERS)
   #  assert_text_present(SELECT_EXAMPLE)
   #  submit_macro_editor
   #  assert_page_content(PIE_CHART_DEFAULT_CONTENT)
   #  sleep 10
   # end

   def test_07_create_new_project
     p "--------------------------------------------------------------------"
     p "                     create one brand new project                   "
     p "--------------------------------------------------------------------"
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("link=New project")
     @browser.type("project_name", BRAND_NEW_PROJECT)
     @browser.click_and_wait("create_project")
   end

   #3.0 Clone Card From One Project To Another
   def test_08_copy_one_card_from_upgraded_project_to_the_brand_new_one
     p "--------------------------------------------------------------------"
     p " copy one card from upgraded project to the newly created project   "
     p "--------------------------------------------------------------------"
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards/50")
     log_in_upgraded_instance_as_admin
     @browser.with_ajax_wait { @browser.click('link=Copy to...')}
     @browser.with_ajax_wait { @browser.click('select_project_drop_link')}
     @browser.with_ajax_wait { @browser.click("select_project_option_#{BRAND_NEW_PROJECT}")}
     @browser.with_ajax_wait { @browser.click("continue")}
     @browser.with_ajax_wait { @browser.click('continue')}
     @browser.open ("projects/#{BRAND_NEW_PROJECT}/cards/1")
     assert_current_url("/projects/#{BRAND_NEW_PROJECT}/cards/1")
     @browser.assert_text_present("#1")
     @browser.assert_text_present("brand_new_project")
     @browser.assert_text_present("Card10")
   end

   #3.0 Cross Project Linking
   def test_09_cross_project_linking
    p "--------------------------------------------------------------------"
    p "      cross project linking on overview page of upgraded project    "
    p "--------------------------------------------------------------------"
    @browser.open("/projects/#{PROJECT_IDENTIFIER}")
    log_in_upgraded_instance_as_admin
    @browser.click_and_wait("page-edit-link-top")
    @browser.type("page_content", "#{BRAND_NEW_PROJECT}/#1")
    @browser.click_and_wait("link=Save")
    @browser.click_and_wait("link=#{BRAND_NEW_PROJECT}/#1")
    assert_current_url("/projects/#{BRAND_NEW_PROJECT}/cards/1")
    @browser.assert_text_present("#1")
    @browser.assert_text_present("brand_new_project")
    @browser.assert_text_present("Card10")
   end

   #3.0 Post Murmurs
   def test_10_post_murmurs_on_murmurs_page
    p "--------------------------------------------------------------------"
    p "                  post/disable/enable murmurs                       "
    p "--------------------------------------------------------------------"
    @browser.open("projects/#{PROJECT_IDENTIFIER}/murmurs")
    log_in_upgraded_instance_as_admin
    @browser.type("murmur_murmur", MURMURS)
    @browser.with_ajax_wait{@browser.click("murmur_submit")}
    @browser.assert_text_present(MURMURS)
    @browser.assert_text_present("(Posted less than a minute ago)")
   end

   #3.0 Checkbox for Showing Hidden Propery
   def test_11_show_hidden_properties_on_card_show
    p "--------------------------------------------------------------------"
    p "             show/hide the hidden properies on card show            "
    p "--------------------------------------------------------------------"
    @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards/25")
    log_in_upgraded_instance_as_admin
    @browser.assert_text_not_present("#{HIDDEN_NUMBER_PROPERTY}")
    @browser.assert_text_not_present("#{HIDDEN_DATE_PROPERTY}")
    @browser.with_ajax_wait{@browser.click("toggle_hidden_properties")}
    @browser.assert_text_present("#{HIDDEN_NUMBER_PROPERTY}")
    @browser.assert_text_present("#{HIDDEN_DATE_PROPERTY}")
   end

   #3.0
   def test_12_create_conditional_aggregate
     p "--------------------------------------------------------------------"
     p "          create a conditional aggregate for Story type             "
     p "--------------------------------------------------------------------"
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards")
     log_in_upgraded_instance_as_admin
     @browser.click('workspace_selector_link')
     @browser.wait_for_element_visible('workspace_selector_panel')
     @browser.click_and_wait("link=story_defect_card tree")
     @browser.click('tree-configure-widget-button')
     @browser.click_and_wait('link=configure')
     @browser.click_and_wait("link=Edit aggregate properties")
     # @browser.wait_for_all_ajax_finished
     # @browser.wait_for_element_not_visible('tree_result_spinner') if @browser.is_element_present('tree_result_spinner')
     @browser.with_ajax_wait do
       @browser.click(%{dom=this.browserbot.getCurrentWindow().$$("a.aggregates-edit-link")[0]})
     end

     @browser.wait_for_element_visible("aggregate_property_definition_name")
     @browser.type("aggregate_property_definition_name", 'foo_agg')
     @browser.select('aggregate_property_definition_aggregate_type', 'Count')
     @browser.select('aggregate_property_definition_aggregate_scope_card_type_id', "Define condition... (for example: type = story AND status = open)")
     @browser.type('aggregate_property_definition_aggregate_condition', "Type = defect AND 'flex text' = 'eee'")

     @browser.with_ajax_wait do
       @browser.click('commit')
     end

    @browser.assert_text_present("Aggregate property foo_agg was successfully created")
    @browser.open("/projects/#{PROJECT_IDENTIFIER}/cards/19")
    @browser.assert_text_present("foo_agg")
   end

   #3.0
   def test_13_using_conditional_aggregate_in_formulas
     p "--------------------------------------------------------------------"
     p "          create a formula using conditional aggreate parameter     "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/property_definitions/new")
     log_in_upgraded_instance_as_admin
     @browser.type("property_definition_name", "xy_formu")
     @browser.click('definition_type_formula')
     @browser.type("property_definition_formula", "foo_agg * 2")
     @browser.click("select_none")
     @browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[16]})
     @browser.click_and_wait("link=Create property")
     @browser.assert_text_present("Property was successfully created.")
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/cards/19")
     @browser.assert_text_present("xy_formu")
   end

   #3.0 lane selector
   def test_14_lane_selector
     p "--------------------------------------------------------------------"
     p "  select Release type and Defect type in grid view by lane selector "
     p "--------------------------------------------------------------------"
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards/grid")
     log_in_upgraded_instance_as_admin

     # now we have changed the drop downs to Mingle drop downs (3.1 #6029) the test will need to do the following:
     #   @browser.click('select_group_by_drop_link')
     #   @browser.click('select_group_by_option_Type')
     # instead of:
     @browser.select('tag-group-select', "Type")

     @browser.wait_for_page_to_load
     @browser.wait_for_all_ajax_finished
     @browser.with_ajax_wait{@browser.click("column-selector-link")}
     @browser.assert_element_present("card_1") # Release type
     @browser.assert_element_present("card_15") # Iteration type
     @browser.assert_element_present("card_28") # Story type
     @browser.assert_element_present("card_40") # Defect type
     @browser.assert_element_present("card_50") # Card type
     @browser.with_ajax_wait{@browser.click("select_all_lanes")}
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[47]})} #Release type
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("input")[50]})} #Defect type
     @browser.with_ajax_wait{@browser.click("apply_selected_lanes")}
     @browser.assert_element_present("card_1")
     @browser.assert_element_present("card_40")
     @browser.assert_element_not_present("card_15")
     @browser.assert_element_not_present("card_28")
     @browser.assert_element_not_present("card_50")
   end

   #3.0
   def test_14_saved_view_from_one_mql_filter_with_conditional_aggregate
     p "--------------------------------------------------------------------"
     p "       delete an aggregate which used by formula and saved view     "
     p "--------------------------------------------------------------------"
     @browser.open ("/projects/#{PROJECT_IDENTIFIER}/cards")
     log_in_upgraded_instance_as_admin
     click_on_edit_mql_filter
     input_mql_conditions("type = Story AND 'foo_agg' = 4 AND 'xy_formu' = 8")
     @browser.with_ajax_wait do
       @browser.click(%{dom=this.browserbot.getCurrentWindow().$$('.finish-editing')[0]})
     end
     expand_favorites_menu
     @browser.type('new-view-name', "Foo Stroy Wall")
     @browser.click_and_wait 'name=save-view'

     @browser.click('workspace_selector_link')
     @browser.wait_for_element_visible('workspace_selector_panel')
     @browser.click_and_wait("link=story_defect_card tree")
     @browser.click('tree-configure-widget-button')
     @browser.click_and_wait('link=configure')
     @browser.click_and_wait("link=Edit aggregate properties")
     @browser.with_ajax_wait do
       @browser.click(%{dom=this.browserbot.getCurrentWindow().$$("a.aggregates-edit-link")[0]})
     end
     @browser.wait_for_element_visible("aggregate_property_definition_name")
     @browser.with_ajax_wait{@browser.click(%{dom=this.browserbot.getCurrentWindow().$$("a.delete-agregate")[0]})}
     @browser.assert_text_present("foo_agg cannot be deleted:")
     @browser.assert_text_present("is used as a component property of xy_formu. To manage xy_formu, please go to card property management page. ")
     @browser.assert_text_present("is used in team favorite Foo Stroy Wall. To manage Foo Stroy Wall, please go to team favorites & tabs management page.")
   end

   #3.0
   def test_15_history_and_card_subscriptions
     p "--------------------------------------------------------------------"
     p "        view the card and history subscription from profile page    "
     p "--------------------------------------------------------------------"
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("link=Profile for admin")

     assert_table_values("global_subscriptions", 2, 1, "Cards")
     assert_table_values("global_subscriptions", 2, 2, "(anything)")
     assert_table_values("global_subscriptions", 2, 3, "(anything)")
     assert_table_values("global_subscriptions", 2, 4, "(anyone)")
     assert_table_values("global_subscriptions", 2, 5, "Unsubscribe")

     assert_table_values("card_subscriptions", 2, 1, "#50")
     assert_table_values("card_subscriptions", 2, 2, "Card 10")
     assert_table_values("card_subscriptions", 2, 3, "Unsubscribe")
   end

   #3.0
   def test_16_p4_repostiroies_should_stil_work_after_upgraded
     p "--------------------------------------------------------------------"
     p "                        check the P4 repo                           "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/p4_repo/")
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("tab_source_link")
     @browser.assert_text_present("Changelists")

     @browser.assert_element_present("content")
     @browser.assert_text_present("Filename")
     @browser.assert_text_present("Rev.")
     @browser.assert_text_present("Size")
     @browser.assert_text_present("Date modified")
     @browser.assert_text_present("Head change")
     @browser.assert_text_present("Head action")
     @browser.assert_text_present("Filetype")

     @browser.click_and_wait("link=Changelists")
     @browser.assert_text_present("History for:")
     @browser.assert_text_present("Today")
     @browser.assert_text_present("Yesterday")
     @browser.assert_element_present("history-results")
  end

   #3.0
   def test_16_svn_repostiroies_should_stil_work_after_upgraded
     p "--------------------------------------------------------------------"
     p "                       check the SVN repo                           "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/svn_repo/")
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("tab_source_link")
     @browser.assert_text_present("Revisions")

     @browser.assert_element_present("svn_browser")
     @browser.assert_text_present("Filename")
     @browser.assert_text_present("File size")
     @browser.assert_text_present("Revision")
     @browser.assert_text_present("User")
     @browser.assert_text_present("Age")
     @browser.assert_text_present("Last change")

     @browser.click_and_wait("link=Revisions")
     @browser.assert_text_present("History for:")
     @browser.assert_text_present("Today")
     @browser.assert_text_present("Yesterday")
     @browser.assert_element_present("history-results")
   end

   #3.0
   def test_17_can_setup_hg_repo
     p "--------------------------------------------------------------------"
     p "                       setup the HG repo                            "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/cards")
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("tab_project_admin_link")
     @browser.click_and_wait("link=Project repository settings")
     @browser.select_and_wait('repository-type-select', 'Mercurial')
     @browser.type("hg_configuration_repository_path", "http://10.18.3.175:8000")
     @browser.type("hg_configuration_username", "mingle")
     @browser.click_and_wait("link=Save settings")
     @browser.click_and_wait("tab_source_link")
     @browser.assert_text_present("Mingle has not finished processing your project repository information. Depending on the size of your repository, this may take a while. Please continue to work as normal.")
   end

   def test_18_newly_add_reserved_words_of_3_0
     p "--------------------------------------------------------------------"
     p "                       check the new saved word                     "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/#{PROJECT_IDENTIFIER}")
     log_in_upgraded_instance_as_admin
     @browser.click_and_wait("tab_defect_wall_link")
     @browser.assert_text_present("Filter is invalid. 'Project' is only supported in SELECT statement")
     @browser.click_and_wait("tab_new_defect_wall_link")
     @browser.assert_text_present("Filter is invalid. The project variable (set) does not exist")
     @browser.open("projects/#{PROJECT_IDENTIFIER}/cards/29")
     @browser.assert_text_present("created on_1")
     @browser.assert_text_present("modified on_1")
     @browser.assert_text_present("project_1")
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/project_variables/list")
     @browser.assert_text_present("(set_1)")
     @browser.open("projects/#{PROJECT_IDENTIFIER}/cards/25")
     @browser.assert_text_not_present("I am set")
     @browser.with_ajax_wait{@browser.click("link=testing saved word \"set\"")}
     @browser.assert_text_present("I am set")
   end

   def test_20_macro_editor_for_data_series_chart
     p "--------------------------------------------------------------------"
     p "              setup one data series chart from macro editor         "
     p "--------------------------------------------------------------------"
     @browser.open("/projects/#{PROJECT_IDENTIFIER}/wiki/fresh_new")
     log_in_upgraded_instance_as_admin
     select_macro_editor(DATA_SERIES_CHART)
     add_macro_parameters_for(DATA_SERIES_CHART, DATA_SERIES_CHART_CHART_LEVEL_PARAMETERS)

     @browser.type("macro_editor_data-series-chart_conditions", "type = card or type = story")
     @browser.type("macro_editor_data-series-chart_x-labels-start", "1111")
     @browser.type("macro_editor_data-series-chart_x-labels-end", "2222")
     @browser.type("macro_editor_data-series-chart_x-labels-step", "10")
     @browser.click("macro_editor_data-series-chart_show-start-label_true")
     @browser.type("macro_editor_data-series-chart_x-labels-property", '"flex number"')
     @browser.type('macro_editor_data-series-chart_x-title', "foo")
     @browser.type('macro_editor_data-series-chart_y-title', "bar")
     @browser.click('macro_editor_data-series-chart_three-d_true')
     @browser.click('macro_editor_data-series-chart_data-point-symbol_square')
     @browser.click('macro_editor_data-series-chart_data-point-symbol_diamond')
     @browser.click('macro_editor_data-series-chart_data-labels_true')
     @browser.type('macro_editor_data-series-chart_chart-height', '500')
     @browser.type('macro_editor_data-series-chart_chart-width', "600")
     @browser.type('macro_editor_data-series-chart_plot-height', '300')
     @browser.type('macro_editor_data-series-chart_plot-width', '400')
     @browser.type('macro_editor_data-series-chart_plot-x-offset', '30')
     @browser.type('macro_editor_data-series-chart_plot-y-offset', '100')
     @browser.type('macro_editor_data-series-chart_label-font-angle', '90')
     @browser.type('macro_editor_data-series-chart_legend-top-offset', '50')
     @browser.type('macro_editor_data-series-chart_legend-max-width', '200')
     @browser.type('macro_editor_data-series-chart_start-label', 'xyz')
     @browser.click('macro_editor_data-series-chart_chart-type_area')
     @browser.type('macro_editor_data-series-chart_line-width', '60')
     @browser.click('macro_editor_data-series-chart_line-style_dash')
     @browser.type('macro_editor_data-series-chart_line-width', "60")
     @browser.click('macro_editor_data-series-chart_line-style_solid')
     @browser.click('macro_editor_data-series-chart_trend_true')
     @browser.type('macro_editor_data-series-chart_trend-scope', 'story')
     @browser.click('macro_editor_data-series-chart_trend-ignore_zeroes-at-end')
     @browser.type('macro_editor_data-series-chart_trend-line-width', '90')
     @browser.type('macro_editor_data-series-chart_project', "#{PROJECT_IDENTIFIER}")

     @browser.with_ajax_wait{@browser.click("data-series-chart_add_series_button_1")}

     @browser.type("data-series-chart_series_0_data_parameter", 'SELECT "flex number", count(*) WHERE type = story')
     @browser.type("data-series-chart_series_1_data_parameter", 'SELECT "flex number", count(*) WHERE type = card')
     @browser.type("data-series-chart_series_2_data_parameter", 'SELECT "flex number", count(*) WHERE type = release')

     @browser.with_ajax_wait{ @browser.click("preview_macro") }
     @browser.assert_element_does_not_match('macro_preview', /Error/)
     @browser.click("submit_macro_editor")
     @browser.wait_for_element_not_present('data-series-chart_macro_panel')
expdata = %{{{
  data-series-chart
    conditions: type = card or type = story
    cumulative: true
    x-labels-start: 1111
    x-labels-end: 2222
    x-labels-step: 10
    show-start-label: true
    x-labels-property: "flex number"
    x-title: foo
    y-title: bar
    three-d: true
    data-point-symbol: diamond
    data-labels: true
    chart-height: 500
    chart-width: 600
    plot-height: 300
    plot-width: 400
    plot-x-offset: 30
    plot-y-offset: 100
    label-font-angle: 90
    legend-top-offset: 50
    legend-max-width: 200
    start-label: xyz
    chart-type: area
    line-width: 60
    line-style: solid
    trend: true
    trend-scope: story
    trend-ignore: zeroes-at-end
    trend-line-color: #FF0000
    trend-line-style: dash
    trend-line-width: 90
    project: #{PROJECT_IDENTIFIER}
    series:
    - data: SELECT "flex number", count(*) WHERE type = story
      label: Series
      color: #FF0000
      trend: true
      trend-line-width: 2
    - data: SELECT "flex number", count(*) WHERE type = card
      label: Series
      color: #FF0000
      trend: true
      trend-line-width: 2
    - data: SELECT "flex number", count(*) WHERE type = release
      label: Series
      color: #FF0000
      trend: true
      trend-line-width: 2
}}}
     assert_page_content(expdata)
     @browser.click_and_wait("link=Save")
   end

 end
