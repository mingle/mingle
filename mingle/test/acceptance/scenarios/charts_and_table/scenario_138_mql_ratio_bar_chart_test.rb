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

#Tags: mql, macro, ratio, chart
class Scenario138MqlRatioBarChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  RATIO_BAR_CHART = 'ratio-bar-chart'

  PRIORITY = "priority"
  SIZE = 'size'

  SAVED_VIEW = '='
  HIGH = 'high'
  LOW = 'low'
  BUG = 'bug'
  SIMPLE_CARD = 'simple card'

  CONDITION_EXAMPLE = "Example: condition"
  SELECT_EXAMPLE = "Example: SELECT property, aggregate WHERE condition"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_138', :admins => [@project_admin_user, users(:admin)])
    login_as_proj_admin_user
  end

  def test_macro_editor_preview_for_ratio_bar_chart_on_card_edit
    setup_property_definitions(PRIORITY => [HIGH, LOW])
    create_managed_number_list_property(SIZE, [1, 2, 3])
    setup_card_type(@project, BUG, :properties => [PRIORITY, SIZE])
    create_card!(:name => SIMPLE_CARD, PRIORITY => HIGH)

    create_card!(:name => 'cookie', :card_type => BUG, PRIORITY => HIGH, SIZE => 1)
    create_card!(:name => 'waffle', :card_type => BUG, PRIORITY => LOW, SIZE => 2)
    create_card!(:name => 'apple', :card_type => BUG, PRIORITY => LOW, SIZE => 3)

    error_message_of_empty_input = "Error in ratio-bar-chart macro: Parameters restrict-ratio-with, totals are required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
    open_wiki_page_in_edit_mode
    edit_overview_page
    invalid_macro = %{
        ratio-bar-chart
          totals:
          restrict-ratio-with:
    }
    enter_text_in_macro_editor(invalid_macro)
    click_ok_on_macro_editor
    assert_mql_error_messages(error_message_of_empty_input)
    invalid_ratio_bar_chart_paras = %{
        ratio-bar-chart
          totals: select size, count(*)
          restrict-ratio-with:
          color: red
          x-title: x title
          y-title: y title

    }

    error_message_of_missing_restrict_ratio_with_para = "Error in ratio-bar-chart macro: Parameter restrict-ratio-with is required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
    enter_text_in_macro_editor(invalid_ratio_bar_chart_paras)
    click_ok_on_macro_editor
    assert_mql_error_messages(error_message_of_missing_restrict_ratio_with_para)

    valid_ratio_bar_chart_paras = %{
        ratio-bar-chart
          totals: select size, count(*)
          restrict-ratio-with: type = bug
          color: red
          x-title: x title
          y-title: y title

    }
    enter_text_in_macro_editor(valid_ratio_bar_chart_paras)
    click_ok_on_macro_editor
    click_save_link
    wait_for_card_contents_to_load
    @browser.assert_element_present('css=.ratio-bar-chart')
  end

  def test_can_use_this_card_property_value_for_the_parameters_used_in_ratio_bar_chart
    priority = setup_property_definitions(PRIORITY => [HIGH, LOW])
    size = create_managed_number_list_property(SIZE, [1, 2, 3])
    type_bug = setup_card_type(@project, BUG, :properties => [PRIORITY, SIZE])

    restrict_ratio_with = create_managed_text_list_property("restrict_ratio_with", ["#{PRIORITY} = #{HIGH}"])
    x_title = create_managed_text_list_property("x_title", ["foo"])
    y_title = create_managed_text_list_property("y_title", ["bar"])
    chart_width = setup_numeric_property_definition("chart_width", ["200"])
    chart_height = setup_numeric_property_definition("chart_height", ["200"])
    plot_height = setup_numeric_property_definition("plot_height", ["100"])
    plot_width = setup_numeric_property_definition("plot_width", ["100"])
    plot_x_offset = setup_numeric_property_definition("plot_x_offset", ["20"])
    plot_y_offset = setup_numeric_property_definition("plot_y_offset", ["20"])
    label_font_angle = setup_numeric_property_definition("label_font_angle", ["45"])

    add_properties_for_card_type(type_bug, [restrict_ratio_with, x_title, y_title, chart_width, chart_height, plot_width, plot_height, plot_x_offset, plot_y_offset, label_font_angle])

    bug_1 = create_card!(:name => 'story_1', :card_type => BUG, SIZE => '2', PRIORITY => "#{HIGH}", "restrict_ratio_with" => "#{PRIORITY} = #{HIGH}", "x_title" => "foo", "y_title" => "bar", "chart_width" => "200", "chart_height" => "200",
                         "chart_width" => 200, "plot_height" => "100", "plot_width" => "100", "plot_x_offset" => "20", "plot_y_offset" => "20", "label_font_angle" => "45")
    bug_2 = create_card!(:name => 'story_2', :card_type => BUG, SIZE => '1', PRIORITY => "#{LOW}")

    open_card(@project, bug_1.number)
    click_edit_link_on_card
    ratio_bar_chart_paras = %{
        ratio-bar-chart
          totals: Select number, count(*) where type = THIS CARD.type
          restrict-ratio-with: THIS CARD.restrict_ratio_with
          chart-width: THIS CARD.chart_width
          x-title: THIS CARD.x_title
          y-title: THIS CARD.y_title
          label-font-angle: THIS CARD.label_font_angle
    }
    enter_text_in_macro_editor(ratio_bar_chart_paras)
    click_ok_on_macro_editor
    save_card
    wait_for_card_contents_to_load
    @browser.assert_element_not_present("css=.error")
    @browser.assert_element_present("css=.ratio-bar-chart")
  end

  def test_ratio_bar_chart_should_show_and_sort_display_name_and_login_name
    logins_and_display_names = [
      {:login => 'a_admin', :name => "admin"},
      {:login => 'b_admin', :name => "admin"},
      {:login => 'cap',     :name => "B admin"},
      {:login => 'uncap',   :name =>  "b admin"},
      {:login => 'c_admin', :name => "c admin"},
    ]

    users_used_in_chart = create_new_users(logins_and_display_names)
    property_used_in_chart = setup_user_definition('owner')

    users_used_in_chart.each do |user|
      @project.add_member(user)
      card_used_in_chart = create_card!(:name => 'cookie', :card_type => 'Card', 'owner' =>  user.id)
    end

    wiki = open_wiki_page_in_edit_mode
    add_ratio_bar_chart_and_save_for('owner', "count(*)", :render_as_text => true, :restrict_conditions  => "type = card")
    open_wiki_page(@project, wiki.name)
    click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK)
    expected_x_labels = users_used_in_chart.map{ |item| item.name_and_login}.join(',')
    assert_chart('x_labels',expected_x_labels)
    destroy_users_by_logins(users_used_in_chart.collect(&:login))
  end

  # bug 2813
  def test_ratio_bar_chart_throws_valid_error_message_when_query_does_not_have_property_set
    # navigate_to_card_list_for(@project)
    navigate_to_project_overview_page(@project)
    edit_overview_page
    ratio_one = %{
        ratio-bar-chart
          totals: SELECT Count(*)
          restrict-ratio-with: Type = Card
    }
    enter_text_in_macro_editor(ratio_one)
    click_ok_on_macro_editor
    assert_mql_error_messages("Error in ratio-bar-chart macro: A two-dimensional (two columns) query must be supplied for the totals. The totals contains 1 column")
  end
end
