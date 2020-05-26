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

class Scenario140DataSeriesChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  PRIORITY = "priority"
  HIGH = 'high'
  LOW = 'low'
  SIZE = 'size'
  BUG = 'bug'


  CONDITIONS = 'conditions'
  LABELS = 'labels'
  CUMULATIVE = 'cumulative'
  X_LABELS_START = 'x-labels-start'
  X_LABELS_END = 'x-labels-end'
  X_LABELS_STEP = 'x-label-step'
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
  CHART_TYPE = 'chart-type'
  HIDDEN = 'hidden'
  PROJECT = 'project'
  DATA = 'data'
  LABEL_1 = "foo"
  LABEL_2 = "bar"
  X_LABELS_PROPERTY = "x-labels-property"
  SHOW_START_LABEL = "show-start-label"
  START_LABEL = "start-label"
  LINE_WIDTH = "line-width"
  LINE_STYLE = "line-style"
  TREND = "trend"
  TREND_SCOPE = "trend-scope"
  TREND_IGNORE = "trend-ignore"
  TREND_LINE_COLOR = "trend-line-color"
  TREND_LINE_STYLE = "trend-line-style"
  TREND_LINE_WIDTH = "trend-line-width"
  DATA_POINT_SYMBOL = "data-point-symbol"
  DATA_LABELS = "data-labels"

  MEDIUM = "medium"
  SUPER_HIGH = "super_high"
  OWNER = 'owner'
  CHART_LEVEL_PROJECT = "chart_level_project"

  SERIES_LEVEL_LABEL_1 = "series_level_label_1"
  SERIES_LEVEL_LABEL_2 = "series_level_label_2"
  SERIES_LEVEL_PROJECT_1 = "series_level_project_1"
  SERIES_LEVEL_PROJECT_2 = "series_level_project_2"


  DATA_SERIES_CHART = 'data-series-chart'

  DATA_SERIES_CHART_CHART_LEVEL_PARAMETERS = ['conditions', 'cumulative', 'x-labels-start', 'x-labels-end', 'x-labels-step','x-labels-conditions', 'show-start-label', 'x-labels-property', 'x-title', 'y-title',
    'three-d', 'x-labels-tree', 'data-point-symbol', 'data-labels', 'chart-height', 'chart-width', 'plot-height', 'plot-width', 'plot-x-offset', 'plot-y-offset',
    'label-font-angle', 'legend-top-offset', 'legend-offset', 'legend-max-width', 'start-label', 'chart-type', 'line-width', 'line-style', 'trend', 'trend-scope',
    'trend-ignore', 'trend-line-color', 'trend-line-style', 'trend-line-width', 'project']

  DATA_SERIES_CHART_SERIES_LEVEL_PARAMETERS= ['data', 'label', 'color', 'type', 'project', 'data-point-symbol', 'data-labels', 'down-from', 'line-width', 'line-style',
    'trend', 'trend-scope', 'trend-ignore', 'trend-line-color', 'trend-line-style', 'trend-line-width']

  DATA_SERIES_CHART_CHART_LEVEL_DEFAULT_PARAMETERS = ['conditions', 'cumulative','x-labels-start', 'x-labels-end', 'x-labels-step', ]
  DATA_SERIES_CHART_CHART_LEVEL_NON_DEFAULT_PARAMETERS = ['x-labels-conditions', 'show-start-label', 'x-labels-property', 'x-title', 'y-title',
    'three-d', 'x-labels-tree', 'data-point-symbol', 'data-labels', 'chart-height', 'chart-width', 'plot-height', 'plot-width', 'plot-x-offset', 'plot-y-offset',
    'label-font-angle', 'legend-top-offset', 'legend-offset', 'legend-max-width', 'start-label', 'chart-type', 'line-width', 'line-style', 'trend', 'trend-scope',
    'trend-ignore', 'trend-line-color', 'trend-line-style', 'trend-line-width', 'project']

  DATA_SERIES_CHART_SERIES_LEVEL_DEFAULT_PARAMETERS = ['data', 'label', 'color','trend','trend-line-width']
  DATA_SERIES_CHART_SERIES_LEVEL_NON_DEFAULT_PARAMETERS = ['type', 'project', 'data-point-symbol', 'data-labels', 'down-from', 'line-width', 'line-style',
    'trend-scope', 'trend-ignore', 'trend-line-color', 'trend-line-style']

  DATA_SERIES_CHART_DEFAULT_CONTENT = %{
  data-series-chart
    conditions: type = card_type
    cumulative: true
    series:
    - data: SELECT property, aggregate WHERE condition
      label: Series
      color: #FF0000
      trend: true
      trend-line-width: 2
    - data: SELECT property, aggregate WHERE condition
      label: Series
      color: #FF0000
      trend: true
      trend-line-width: 2
}

    INSERT_DATA_SERIES_CHART ='Insert Data Series Chart'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @project_read_only_user = users(:read_only_user)
    @project_team_member = users(:project_member)

    @project = create_project(:prefix => "sc140", :admins => [users(:proj_admin)], :users => [users(:project_member), users(:admin)], :read_only_users => [users(:read_only_user)])
    login_as_proj_admin_user
  end

  # Bug 7669
  def test_using_this_card_in_x_labels_conditions_should_not_give_bad_error_message
    setup_property_definitions('size' => [1,2,4])
    setup_card_relationship_property_definition('iteration')
    open_wiki_page_in_edit_mode

    data_series_content = %{
      data-series-chart
        conditions: iteration=THIS CARD
        cumulative: true
        series:
        - data: SELECT size, count(*)
          label: Series 1
          color: #FF0000
          trend: true
          trend-line-width: 2
        - data: SELECT size, count(*)
          label: Series 2
          color: #FF0000
          trend: true
          trend-line-width: 2
    }

    create_free_hand_macro(data_series_content)
    @browser.assert_text_present("THIS CARD is not a supported macro for page")
  end

  def test_show_user_display_name_and_user_login_when_user_property_is_rendered_for_data_series_chart
    owner = setup_user_definition(OWNER)
    priority = setup_property_definitions(PRIORITY => [HIGH, LOW, MEDIUM, SUPER_HIGH])
    size = create_managed_number_list_property(SIZE, [1, 2, 3, 4])
    type_bug = setup_card_type(@project, BUG, :properties => [PRIORITY, SIZE, OWNER])

    bug_1 = create_card!(:name => 'bug1', :card_type => BUG, SIZE => '1', PRIORITY => "#{HIGH}", OWNER => @project_read_only_user.id)
    bug_2 = create_card!(:name => 'bug2', :card_type => BUG, SIZE => '2', PRIORITY => "#{LOW}", OWNER => @project_admin_user.id)
    bug_3 = create_card!(:name => 'bug3', :card_type => BUG, SIZE => '3', PRIORITY => "#{MEDIUM}", OWNER => @project_team_member.id)
    bug_4 = create_card!(:name => 'bug3', :card_type => BUG, SIZE => '4', PRIORITY => "#{SUPER_HIGH}", OWNER => @mingle_admin.id)
    wiki = open_wiki_page_in_edit_mode
    create_free_hand_macro(%{
        data-series-chart
          render_as_text: true
          conditions: type = card
          chart-height: 400
          chart-width: 400
          series:
           - data: select OWNER, count(*) where priority = low
             label: Series
             color: #FF0000
             trend: true
             trend-line-width: 2
           - data: select OWNER, count(*) where priority = high
             label: Series
             color: #FF0000
             trend: true
             trend-line-width: 2
           - data: select OWNER, count(*) where priority = medium
             label: Series
             color: #FF0000
             trend: true
             trend-line-width: 2
           - data: select OWNER, count(*) where priority = super_high
             label: Series
             color: #FF0000
             trend: true
             trend-line-width: 2
        })
    click_save_link
    open_wiki_page(@project, wiki.name)
    click_link_with_ajax_wait("Chart Data")
    assert_chart("x_labels", "admin@email.com (admin),member@email.com (member),proj_admin@email.com (proj_admin),read_only_user@email.com (read_only_user)")
  end

  private

  def assert_random_color_in_popup_for_series_parameter(chart_type, series_index, parameter_name)
    locator = wiki_page_color_popup_id(chart_type, series_index, parameter_name)
    style = @browser.get_attribute("#{locator}@style")
    rgb_color = (style.match(/\(([^\)]+)\)/)[1].split(", "))
    chosen_color = hex_color(rgb_color)

    assert Color.defaults.include?(chosen_color), "#{chosen_color} was not found in Color.defaults"
  end

  def assert_random_color_for_series_parameter(chart_type, series_index, parameter_name)
    chosen_color = @browser.get_value(selected_color_field_popup_for_series(chart_type, series_index, parameter_name)).upcase
    assert Color.defaults.include?(chosen_color), "#{chosen_color} was not found in Color.defaults"
  end

  def selected_color_field_popup_for_series(chart_type, series_index, parameter_name)
    "css=##{chart_type}_series_#{series_index}_#{parameter_name}_parameter_container .color-palette-container input"
  end

  def hex_color(rgb_color)
    rgb_color.inject("#") {|h, c| h << c.to_i.to_s(16).rjust(2, "0").upcase; h }
  end

end
