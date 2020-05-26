# -*- coding: utf-8 -*-

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

#Tags: mql, macro, chart, stackBarChart

class Scenario131MqlStackBarChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  PRIORITY = 'priörity'
  HIGH = 'high'
  LOW = 'low'
  SIZE = 'sizé'
  BUG = 'bug'
  OWNER = 'owner'

  CONDITIONS = 'conditions'
  LABELS = 'labels'
  CUMULATIVE = 'cumulative'
  X_LABEL_START = 'x-label-start'
  X_LABEL_END = 'x-label-end'
  X_LABEL_STEP = 'x-label-step'
  X_LABELS_TREE = 'x-labels-tree'
  X_TITLE = 'x-title'
  Y_TITLE = 'y-title'
  THREE_D = 'three-d'
  CHART_HEIGHT = 'chart-height'
  CHART_WIDTH = 'chart-width'
  PLOT_HEIGHT = 'plot-height'
  PLOT_WIDTH = 'plot-width'
  PLOT_X_OFFSET = 'plot-x-offset'
  PLOT_Y_OFFSET = 'plot-y-offset'
  LABEL_FONT_ANGLE = 'label-font-angle'
  LEGEND_TOP_OFFSET = 'legend-top-offset'
  LEGEND_OFFSET = 'legend-offset'
  LEGEND_MAX_WIDTH = 'legend-max-width'
  LABEL = 'label'
  COLOR = 'color'
  COMBINE = 'combine'
  CHART_TYPE = 'chart_type'
  HIDDEN = 'hidden'
  PROJECT = 'project'
  DATA = 'data'
  LABEL_1 = "foo"
  LABEL_2 = "bar"

  MEDIUM = "medium"
  SUPER_HIGH = "super_high"

  CHART_LEVEL_PROJECT = "chart_level_project"

  SERIES_LEVEL_LABEL_1 = "series_level_label_1"
  SERIES_LEVEL_LABEL_2 = "series_level_label_2"
  SERIES_LEVEL_PROJECT_1 = "series_level_project_1"
  SERIES_LEVEL_PROJECT_2 = "series_level_project_2"

  STACK_BAR_CHART = 'stacked-bar-chart'
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @project_read_only_user = users(:read_only_user)
    @project_team_member = users(:project_member)

    @project = create_project(:prefix => "sc131", :admins => [users(:proj_admin)], :users => [users(:project_member), users(:admin)], :read_only_users => [users(:read_only_user)])
    @project_identifier = @project.identifier
    login_as_proj_admin_user
  end

  # bug 7366
  def test_x_label_start_can_use_value_which_is_not_used_by_cards
    setup_property_definitions 'size' => [1,2,3,4]
    setup_card_type(@project, 'story', :properties => ['size'])
    setup_card_type(@project, 'bug', :properties => ['size'])
    story1 = create_card!(:name => 'card1', :card_type => 'story', 'size' => '1')
    story2 = create_card!(:name => 'card2', :card_type => 'story', 'size' => '2')
    bug1 = create_card!(:name => 'bug1', :card_type => 'bug', 'size' => '3')
    bug2 = create_card!(:name => 'bug2', :card_type => 'bug', 'size' => '4')
    wiki = open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
         stack-bar-chart
             render_as_text: true
             conditions: type = bug
             cumulative: false
             labels: select size
             x-label-start: 2
             series:
             - data: SELECT size, count(*)
               label: Series

     })
    click_save_link
    open_wiki_page(@project, wiki.name)
    click_link_with_ajax_wait("Chart Data")
    assert_chart("x_labels", "4,3")
    assert_chart("data_for_Series", "1,1")
  end

  # bug 6932 x label start (and likely end) impact the data used in the chart on stack bar chart instead of just changing what is shown
  def test_should_caculate_correct_value_from_x_label_start
    setup_property_definitions 'size' => [1,2,3,4]
    setup_card_type(@project, 'bug', :properties => ['size'])
    create_card!(:name => 'bug1', :card_type => 'bug', 'size' => '1')
    create_card!(:name => 'bug2', :card_type => 'bug', 'size' => '2')
    create_card!(:name => 'bug3', :card_type => 'bug', 'size' => '3')
    create_card!(:name => 'bug4', :card_type => 'bug', 'size' => '4')
    create_card!(:name => 'bug5', :card_type => 'bug', 'size' => '2')
    wiki = open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
         stack-bar-chart
             render_as_text: true
             conditions: type = bug
             cumulative: true
             labels: select distinct size
             x-label-start: 2
             series:
             - data: SELECT size, count(*)
               label: Series

     })
    click_save_link
    open_wiki_page(@project, wiki.name)
    click_link_with_ajax_wait("Chart Data")
    assert_chart("data_for_Series", "3,4,5")
  end

  private

  def macro_as_yaml(macro)
    name = macro.index("\n") + 1
    # kind of a cheat - hex values for color become nil,
    # which is good because we can't anticipate randomly chosen colors
    YAML.fix_encoding_and_load(macro[name..-1])
  end

end

