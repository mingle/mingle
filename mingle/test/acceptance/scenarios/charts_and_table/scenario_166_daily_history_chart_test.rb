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
#Tags: mql, macro, chart, dailyHistoryChart
class Scenario166DailyHistoryChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  DAILY_HISTORY_CHART = "daily-history-chart"
  INSERT_DAILY_HISTORY_CHART = 'Insert Daily History Chart'
  SIZE = 'size'
  STATUS = 'status'
  DAILY_HISTORY_CHART_LEVEL_PARAMETERS = [
      'aggregate', 'chart-conditions', 'start-date', 'end-date', 'x-labels-step',
      'x-title', 'y-title', 'line-width',
      'scope-series', 'completion-series', 'target-release-date',
      'chart-height', 'chart-width', 'plot-height', 'plot-width', 'plot-x-offset', 'plot-y-offset',
      'label-font-angle', 'legend-top-offset', 'legend-offset', 'legend-max-width']

  DAILY_HISTORY_CHART_SERIES_LEVEL_PARAMETERS= ['label', 'color', 'line-width', 'conditions']
  DAILY_HISTORY_CHART_CHART_LEVEL_DEFAULT_PARAMETERS = ['aggregate', 'chart-conditions', 'start-date', 'end-date']
  DAILY_HISTORY_CHART_SERIES_LEVEL_DEFAULT_PARAMETERS = ['label', 'color', 'conditions']
  DAILY_HISOTRY_CHART_LEVEL_REQUIRED_PARAMETERS = ['aggregate', 'start-date', 'end-date']
  CHART_CACHE_NOT_READY_MESSAGE = "While Mingle is preparing all the data for this chart. Revisit this page later to see the complete chart. We calculate data for each day in your date range"

  DEFAULT_MACRO_CONTENT = %{
  daily-history-chart
    aggregate: SUM ('numeric property name')
    start-date:
    end-date:
    chart-conditions: type = card_type
    series:
    - conditions: type = card_type
      color: #FF0000
    - conditions: type = card_type
      color: #FF0000
}

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_team_member = users(:project_member)
    @project = create_project(:prefix => "scenario_166", :admins => [users(:proj_admin)], :users => [users(:project_member)])
    @proj_admin = login_as_proj_admin_user
    @project.update_attribute :time_zone, ActiveSupport::TimeZone.new('UTC').name
  end

  def test_daily_history_chart_renders
    create_managed_number_list_property(SIZE, [1, 2, 3, 4])
    Clock.now_is("2009-05-14") { @bug = create_card!(:name => 'bug1', SIZE => '2') }
    Clock.now_is("2009-05-15") { @bug.update_attribute(:cp_size, 1) }
    Clock.now_is("2009-05-16") { @bug.update_attribute(:cp_size, 0) }
    open_wiki_page_in_edit_mode 'test page'
    create_free_hand_macro <<-YAML
          daily-history-chart
            render_as_text: true
            aggregate: COUNT(*)
            start-date: 14 May 2009
            end-date: 16 May 2009
            x-title: our date
            y-title: our count
            series:
              - label: less_than_one
                conditions: Size < 1
                color: Red
              - label: equal_to_one
                conditions: Size = 1
                color: SpringGreen
              - label: greater_than_one
                conditions: Size > 1
                color:
    YAML
    with_ajax_wait { click_save_link }
    @browser.assert_text_present_in "page-content", CHART_CACHE_NOT_READY_MESSAGE
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    click_link_with_ajax_wait("Chart Data")
    assert_chart("x_labels", "2009-05-14,2009-05-15,2009-05-16")
    assert_chart("data_for_less_than_one", "0,0,1")
    assert_chart("data_for_equal_to_one", "0,1,0")
    assert_chart("data_for_greater_than_one", "1,0,0")
    assert_chart("x_title", "our date")
    assert_chart("y_title", "our count")
  end

  def test_cannot_view_daily_history_chart_and_give_valid_info
    create_date_property('start_date')
    create_date_property('end_date')
    daily_history_chart = <<-YAML
          daily-history-chart
            render_as_text: true
            aggregate: COUNT(*)
            start-date: THIS CARD.start_date
            end-date: THIS CARD.end_date
            series:
              - label: Total Count
    YAML

    open_edit_defaults_page_for(@project, 'card')
    create_free_hand_macro(daily_history_chart)
    wait_for_wysiwyg_editor_ready
    @browser.assert_text_present_in("renderable-contents", "Macros using THIS CARD.start_date will be rendered when card is created using this card default. Macros using THIS CARD.end_date will be rendered when card is created using this card default.")
  end

  #cache
  def test_daily_history_chart_caches_image_after_its_done_processing
    create_managed_number_list_property(SIZE, [1, 2, 3, 4])
    Clock.now_is("2009-05-14") { @bug = create_card!(:name => 'bug1', SIZE => '2') }
    open_wiki_page_in_edit_mode 'test page'
    create_free_hand_macro <<-YAML
      daily-history-chart
        render_as_text: true
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: less_than_one
            conditions: Size < 1
            color: Red

    YAML
    with_ajax_wait { click_save_link }
    assert_daily_history_chart_not_ready_message
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    logout
    login_as_project_member
    with_ajax_wait { open_wiki_page @project, 'test page' }
    assert_daily_history_chart_rendered
  end

  def test_using_TAGGED_WITH_in_series_condition
    invalid_TAGGED_WITH_in_content = %{
    daily-history-chart
    aggregate: count(*)
    start-date: 2009 May 16
    end-date: 2009 May 17
    series:
      - label: invalid_TAGGED_WITH_property
        conditions: type=card AND TAGGED with "foo"
  }

    invalid_TAGGED_WITH_error_message = "Error in daily-history-chart macro: TAGGED WITH is not supported in the daily history chart."
    @bug = create_card!(:name => 'bug1')
    open_card_for_edit(@project, @bug)
    create_free_hand_macro(invalid_TAGGED_WITH_in_content)
    assert_mql_error_messages(invalid_TAGGED_WITH_error_message)
  end

  def assert_daily_history_chart_not_ready_message(container = "content")
    @browser.assert_text_present_in container, CHART_CACHE_NOT_READY_MESSAGE
  end

  def assert_daily_history_chart_rendered(container_locator = nil)
    if container_locator
      parent_inner_html = @browser.get_inner_html(container_locator)
      assert_include "Chart Data", parent_inner_html
    else
      @browser.assert_element_present("link=Chart Data")
    end
  end

  def assert_daily_history_chart_row_column_sample_table(table_index, row, column, expected_result)
    @browser.assert_table_cell(css_locator('table', table_index), row, column, expected_result)
  end


  def test_using_THIS_CARD_in_conditions
    create_card_type_property("property1")
    create_card_type_property('property2')
    create_card_type_property('property3')

    Clock.now_is("2009-05-14") do
      @release = create_card!(:name => 'Release_1')
      @bug_1 = create_card!(:name => 'bug1')
      @bug_2 = create_card!(:name => 'bug2')
      @bug_3 = create_card!(:name => 'bug3')
      @bug_1.update_attribute(:cp_property1, @release)
      @bug_1.update_attribute(:cp_property2, @release)
      @bug_3.update_attribute(:cp_property1, @release)
    end

    Clock.now_is("2009-05-15") do
      @bug_2.update_attribute(:cp_property1, @release)
      @bug_3.update_attribute(:cp_property3, @release)
    end

    Clock.now_is("2009-05-16") { @bug_2.update_attribute(:cp_property3, @release) }

    macro_content = %{
      daily-history-chart
        render_as_text: true
        aggregate: COUNT(*)
        chart-conditions: property1 = THIS CARD
        start-date: 2009 May 14
        end-date: 2009 May 16
        x-title: our date
        y-title: our count
        series:
          - label:
            conditions: property2 = THIS CARD
            color: Yellow
          - label:
            conditions: property3 = THIS CARD
            color: green
  }

    open_card_for_edit(@project, @release)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_property2 = THIS CARD", "1,1,1")
    assert_chart("data_for_property3 = THIS CARD", "0,1,2")
  end


  def test_using_THIS_CARD_property_as_parameter_value
    create_date_property('start')
    create_date_property('end')
    create_managed_number_list_property("step", ['1', '2', '3'])
    create_managed_text_list_property("label", ['label1', 'lable2', 'lable3'])
    create_managed_text_list_property("color", ['green', 'yellow', 'pink'])
    @card1 = create_card!(:name => 'card 1')

    Clock.now_is("2009-05-14") do
      @card1.update_attribute(:cp_start, '2009-05-14')
      @card1.update_attribute(:cp_label, 'label1')
    end

    Clock.now_is("2009-05-15") do
      @card1.update_attribute(:cp_color, 'pink')
      @card1.update_attribute(:cp_step, '3')
    end

    Clock.now_is("2009-05-16") do
      @card1.update_attribute(:cp_end, '2009-05-16')
    end

    macro_content = %{
          daily-history-chart
          render_as_text: true
          aggregate: COUNT(*)
          chart-conditions:
          start-date: THIS CARD.start
          end-date: THIS CARD.end
          x-labels-step: THIS CARD.step
          series:
          - label: THIS CARD.label
            conditions:
            color:
          - label: THIS CARD.color
            conditions:
            color:
          }

    open_card_for_edit(@project, @card1)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_label1", "1,1,1")
    assert_chart("data_for_pink", "1,1,1")
  end


  def test_using_plv_in_conditions
    create_managed_number_list_property("size", [1, 2, 3, 4])
    create_managed_text_list_property("priority", ['low', 'medium', 'high'])
    create_card_type_property("other_card")
    @release = create_card!(:name => 'Release_1')

    create_project_variable(@project, :name => "numeric_plv", :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :properties => ["size"])
    create_project_variable(@project, :name => "priority_plv", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'high', :properties => ["priority"])
    create_project_variable(@project, :name => 'card_plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => @release, :properties => ["other_card"])

    Clock.now_is("2009-05-14") do
      @bug_1 = create_card!(:name => 'bug1', "size" => 1)
      @bug_1.update_attribute(:cp_other_card, @release)
      @bug_1.update_attribute(:cp_priority, 'low')
    end

    Clock.now_is("2009-05-15") do
      @bug_1.update_attribute(:cp_size, 2)
      @bug_1.update_attribute(:cp_size, 3)
    end

    Clock.now_is("2009-05-16") do
      @bug_1.update_attribute(:cp_size, 3)
      @bug_1.update_attribute(:cp_priority, 'high')
    end

    macro_content = %{

          daily-history-chart
          render_as_text: true
          aggregate: COUNT(*)
          chart-conditions: size = (numeric_plv)
          start-date: 2009 May 14
          end-date: 2009 May 16
          x-title: our date
          y-title: our count
          series:
            - label:
              conditions: other_card = (card_plv)
              color: Yellow
            - label: text plv
              conditions: priority = (priority_plv)
              color: Green
  }

    open_card_for_edit(@project, @release)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_other_card = (card_plv)", "0,1,1")
    assert_chart("data_for_text plv", "0,0,1")
  end

  def test_using_plv_as_parameter_value
    create_date_property('start_date')
    create_date_property('end_date')
    create_managed_number_list_property("step", ['1', '2', '3'])
    create_managed_text_list_property("label", ['green', 'lable2', 'lable3'])
    @card1 = create_card!(:name => 'card 1')

    create_project_variable(@project, :name => "step_plv", :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1', :properties => ["step"])
    create_project_variable(@project, :name => "start_date_plv", :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '2009-05-14', :properties => ["start_date"])
    create_project_variable(@project, :name => "end_date_plv", :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '2009-05-16', :properties => ["end_date"])
    create_project_variable(@project, :name => "label_plv", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'label2', :properties => ["label"])
    create_project_variable(@project, :name => "color_plv", :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'green', :properties => ["label"])

    Clock.now_is("2009-05-14") do
      @card1.update_attribute(:cp_start_date, '2009-05-14')
      @card1.update_attribute(:cp_label, 'label1')
    end

    Clock.now_is("2009-05-15") do
      @card1.update_attribute(:cp_label, 'green')
    end

    Clock.now_is("2009-05-16") do
      @card1.update_attribute(:cp_end_date, '2009-05-16')
    end

    macro_content = %{

        daily-history-chart
        render_as_text: true
        aggregate: COUNT(*)
        chart-conditions:
        start-date: (start_date_plv)
        end-date: (end_date_plv)
        x-labels-step: (step_plv)
        series:
        - label: (label_plv)
          conditions: start_date > (start_date_plv)
          color:
        - label:
          conditions: end_date = (end_date_plv)
          color: (color_plv)
         }

    open_card_for_edit(@project, @card1)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_label2", "0,0,0")
    assert_chart("data_for_end_date = (end_date_plv)", "0,0,1")
  end


  def test_project_identifier_changes
    open_wiki_page_in_edit_mode 'test page'
    create_free_hand_macro <<-YAML
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 16 May 2009
              series:
                - label: Total Count
    YAML
    with_ajax_wait { click_save_link }
    DailyHistoryChart.process(:batch_size => 6)
    assert_daily_history_chart_not_ready_message
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    @project.update_attribute :identifier, 'test_chart'
    with_ajax_wait { open_wiki_page @project, 'test page' }
    assert_daily_history_chart_rendered
  end

  def test_project_timezone_changes
    open_wiki_page_in_edit_mode 'test page'
    create_free_hand_macro <<-YAML
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 16 May 2009
              series:
                - label: Total Count
    YAML
    with_ajax_wait { click_save_link }
    DailyHistoryChart.process(:batch_size => 6)
    assert_daily_history_chart_not_ready_message
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    @project.update_attribute :time_zone, 'Beijing'
    with_ajax_wait { open_wiki_page @project, 'test page' }
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered
  end

  def test_non_association_property_definiton_is_deleted
    revision = setup_allow_any_text_property_definition 'revision'
    card = create_card!(:name => 'i can haz chart')

    chart = %{
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 16 May 2009
              series:
                - label: Total Count
          }

    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart)

    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, 'revision')
    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_association_property_definition_changes
    owner = setup_user_definition 'owner'
    card = create_card! :name => 'i can haz chart', :owner => @proj_admin.id

    chart_query = %{
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 16 May 2009
              series:
                - label: Total Count
        }

    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart_query)

    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, 'owner', :new_property_name => 'new owner')

    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_managed_text_property_definition_changes
    status = setup_managed_text_definition 'status', ['open', 'close']
    card = create_card! :name => 'i can haz chart', :status => 'open'

    chart_query = %{
              daily-history-chart
                render_as_text: true
                aggregate: COUNT(*)
                start-date: 14 May 2009
                end-date: 15 May 2009
                series:
                  - label: Total Count
                    conditions: Status IN ('open', 'close')
          }

    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart_query)

    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    navigate_to_property_management_page_for(@project)
    edit_enumeration_value_for(@project, 'status', 'open', 'opened')

    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_card_type_changes
    card_type = @project.card_types.first
    bug_type = @project.card_types.create! :name => 'bug'
    card = create_card! :card_type => card_type, :name => 'i can haz chart'
    chart_query = %{
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              chart-conditions: Type IN ('bug')
              start-date: 14 May 2009
              end-date: 15 May 2009
              series:
                - label: Total Count
        }
    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart_query)
    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 10)
    sleep 4
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered
    navigate_to_card_type_management_for(@project)
    edit_card_type_for_project(@project, 'bug', :new_card_type_name => 'buggy')
    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
    DailyHistoryChart.process(:batch_size => 10)
    sleep 4
    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_rendered
    navigate_to_card_type_management_for(@project)
    delete_card_type(@project, 'buggy')
    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_plv_value_changes
    size = create_managed_number_list_property("size", [3, 4])
    create_plv!(@project, :name => "numeric_plv", :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :property_definition_ids => [size.id])
    card = create_card!(:name => 'i can haz chart', :size => 3)

    chart_query = %{
              daily-history-chart
                render_as_text: true
                aggregate: COUNT(*)
                chart-conditions: Size = (numeric_plv)
                start-date: 14 May 2009
                end-date: 15 May 2009
                series:
                  - label: Total Count
          }
    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart_query)

    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    navigate_to_project_variable_management_page_for(@project)
    edit_project_variable(@project, 'numeric_plv', :new_value => '4', :data_type => ProjectVariable::NUMERIC_DATA_TYPE)
    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_delete_cards_update_the_daily_history_chart
    simple_delete_card = create_card! :name => 'i am a simple delete card'
    bulk_delete_card = create_card! :name => 'i am a bulk delete card'
    chart_card = create_card! :name => 'i can haz chart'

    chart_query = %{
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 15 May 2009
              series:
                - label: Total Count
          }

    open_card_for_edit(@project, chart_card)
    create_free_hand_macro_and_save(chart_query)

    with_ajax_wait { open_card @project, chart_card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    delete_card(@project, simple_delete_card.name)

    with_ajax_wait { open_card @project, chart_card }
    assert_daily_history_chart_not_ready_message('card-description')

    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { open_card @project, chart_card }
    assert_daily_history_chart_rendered

    navigate_to_card_list_for(@project)
    select_cards([bulk_delete_card])
    click_bulk_delete_button
    click_confirm_bulk_delete

    with_ajax_wait { open_card @project, chart_card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  def test_property_is_disassociated_with_card_type
    owner = setup_user_definition('owner')
    card = create_card! :name => 'i can haz chart'

    chart_query = %{
            daily-history-chart
              render_as_text: true
              aggregate: COUNT(*)
              start-date: 14 May 2009
              end-date: 15 May 2009
              series:
                - label: Total Count
          }

    open_card_for_edit(@project, card)
    create_free_hand_macro_and_save(chart_query)


    with_ajax_wait { open_card @project, card }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered

    navigate_to_card_type_management_for(@project)
    edit_card_type_for_project(@project, @project.card_types.first.name, :uncheck_properties => ['owner'])

    with_ajax_wait { open_card @project, card }
    assert_daily_history_chart_not_ready_message('card-description')
  end

  # wysiwyg - edit macro - need to implement right now this will render 4 charts
  def ignored_test_recache_should_happen_only_to_the_modified_chart
    open_wiki_page_in_edit_mode('test page')
    enter_text_in_editor('blah\\n\\n\\n')

    create_free_hand_macro <<-EOS
        daily-history-chart
          render_as_text: true
          aggregate: COUNT(*)
          start-date: 14 May 2009
          end-date: 15 May 2009
          series:
            - label: Total Count
    EOS

    with_ajax_wait { click_save_link }
    # reload_current_page
    click_edit_link_on_wiki_page
    enter_text_in_editor('blah\\n\\n\\n')

    create_free_hand_macro %{
              daily-history-chart
                render_as_text: true
                aggregate: COUNT(*)
                start-date: 15 May 2009
                end-date: 16 May 2009
                series:
                  - label: Total Count
          }
    with_ajax_wait { click_save_link }

    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    assert_daily_history_chart_rendered_in("history-chart-data-1")
    assert_daily_history_chart_rendered_in("history-chart-data-2")
    click_edit_link_on_wiki_page

    create_free_hand_macro <<-EOS
        daily-history-chart
          render_as_text: true
          aggregate: COUNT(*)
          start-date: 15 May 2009
          end-date: 16 May 2009
          series:
            - label: TOTAL COUNT IS CHANGED
    EOS
    with_ajax_wait { click_save_link }
    # click_edit_link_on_wiki_page
    #   enter_text_in_editor('blah\\n\\n\\n')
    #
    #   create_free_hand_macro %{
    #     daily-history-chart
    #       aggregate: COUNT(*)
    #       start-date: 15 May 2009
    #       end-date: 16 May 2009
    #       series:
    #         - label: Total Count
    #   }
    #
    #   with_ajax_wait { click_save_link }
    assert_daily_history_chart_not_ready_message("history-chart-data-1")
    assert_daily_history_chart_rendered_in("history-chart-data-2")
  end

  def assert_daily_history_chart_rendered(container_locator = nil)
    if container_locator
      assert_include "Chart Data", @browser.get_inner_html(container_locator)
    else
      @browser.assert_element_present("link=Chart Data")
    end
  end

  alias :assert_daily_history_chart_rendered_in :assert_daily_history_chart_rendered

  def assert_daily_history_chart_not_ready_message(container = "content")
    @browser.assert_text_present_in container, CHART_CACHE_NOT_READY_MESSAGE
  end

  def assert_macro_error(container, option)
    # need to update app code to support locating the macro error message
    # @browser.assert_text_present_in("##{option[:macro]}-error", "#{option[:message]}")
    @browser.assert_text_present_in(container, "Error in #{option[:macro]} macro: #{option[:message]}")
  end

  #bug 9480
  def test_using_special_characters_in_series_condition
    status = setup_managed_text_definition '<status>', ['open', 'close']
    card = create_card! :name => 'i can haz chart'
    chart_query = %{
          daily-history-chart
            aggregate: COUNT(*)
            start-date: 14 May 2009
            end-date: 15 May 2009
            series:
              - label: Total Count
                conditions: <Status>
      }

    open_card_for_edit(@project, card)
    create_free_hand_macro(chart_query)
    assert_mql_error_messages("Error in daily-history-chart macro: parse error on value \"<\" (LESS_THAN). You may have a project variable, property, or tag with a name shared by a MQL keyword. If this is the case, you will need to surround the variable, property, or tags with quotes.")
  end


  def test_x_and_y_title_default_values
    open_wiki_page_in_edit_mode('test page')
    create_free_hand_macro <<-YAML
          daily-history-chart
            render_as_text: true
            aggregate: COUNT(*)
            start-date: 14 May 2009
            end-date: 16 May 2009
            series:
              - label: greater_than_one
    YAML
    with_ajax_wait { click_save_link }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    click_link_with_ajax_wait("Chart Data")
    assert_chart("x_title", "Date")
    assert_chart("y_title", "Number of cards")
  end

  #ghost
  def test_x_labels_step
    ["2009-05-1", "2009-05-2", "2009-05-2", "2009-05-3", "2009-05-5"].each do |date|
      Clock.now_is(date) { create_card!(:name => 'card') }
    end
    open_wiki_page_in_edit_mode 'test page'
    create_free_hand_macro <<-YAML

          daily-history-chart
            render_as_text: true
            aggregate: COUNT(*)
            start-date: 1 May 2009
            end-date: 5 May 2009
            x-title: date
            y-title: count
            x-labels-step: 3
            series:
              - label: count
    YAML
    with_ajax_wait { click_save_link }
    DailyHistoryChart.process(:batch_size => 6)
    with_ajax_wait { reload_current_page }
    click_link_with_ajax_wait("Chart Data")
    assert_chart("step", "3")
    assert_chart("x_labels", "2009-05-01,2009-05-04")
    assert_chart("data_for_count", "1,3,4,4,5")
  end


  def test_aggregate_with_managed_number_list
    create_managed_number_list_property(SIZE, [1, 2, 3, 4])
    Clock.now_is("2009-05-14") do
      @bug_1 = create_card!(:name => 'bug1', SIZE => '2')
      @bug_2 = create_card!(:name => 'bug1', SIZE => '3')
    end
    Clock.now_is("2009-05-15") do
      @bug_1.update_attribute(:cp_size, 1)
      @bug_2.update_attribute(:cp_size, 3)
    end
    Clock.now_is("2009-05-16") do
      @bug_1.update_attribute(:cp_size, 0)
      @bug_2.update_attribute(:cp_size, 2)
    end

    macro_content = %{
      daily-history-chart
        render_as_text: true
        aggregate: SUM(size)
        start-date: 2009 May 14
        end-date: 2009 May 16
        x-title: our date
        y-title: our count
        series:
          - label: less_than_one
            color: Yellow
    }

    open_card_for_edit(@project, @bug_1)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_less_than_one", "5,4,2")
  end

  def test_aggregate_with_formula
    create_managed_number_list_property(SIZE, [1, 3, 4, 7])
    create_formula_property("double_size_formula", "size*2")

    Clock.now_is("2009-05-14") do
      @bug = create_card!(:name => 'bug1', SIZE => '7')
      @another_bug = create_card!(:name => 'bug2', SIZE => '3')
    end
    Clock.now_is("2009-05-15") do
      @bug.update_attribute(:cp_size, 4)
      @another_bug.update_attribute(:cp_size, 4)
    end
    Clock.now_is("2009-05-16") do
      @bug.update_attribute(:cp_size, 3)
      @another_bug.update_attribute(:cp_size, 1)
    end

    macro_content = %{
      daily-history-chart
        render_as_text: true
        aggregate: AVG(double_size_formula)
        start-date: 2009 May 14
        end-date: 2009 May 16
        x-title: our date
        y-title: our count
        series:
          - label: Doubled_Size
            color: Yellow
    }

    open_card_for_edit(@project, @bug)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("data_for_Doubled_Size", "10,8,4")
  end


  def test_different_date_formats
    @bug = create_card!(:name => 'bug1')
    macro_content = %{
      daily-history-chart
        render_as_text: true
        aggregate: COUNT(*)
        start-date: 2009 May 14
        end-date: 2009 May 16
        x-title: our date
        y-title: our count
        series:
          - label: number of cards
    }

    navigate_to_project_admin_for(@project)
    set_project_date_format('yyyy/mm/dd')

    open_card_for_edit(@project, @bug)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("x_labels", "2009-05-14,2009-05-15,2009-05-16")

    navigate_to_project_admin_for(@project)
    set_project_date_format('dd/mm/yyyy')


    card2 = create_card!(:name => 'test')
    open_card_for_edit(@project, card2)

    add_daily_history_chart_and_save(macro_content)
    assert_chart("x_labels", "2009-05-14,2009-05-15,2009-05-16")

    navigate_to_project_admin_for(@project)
    set_project_date_format('mm/dd/yyyy')

    card3 = create_card!(:name => 'test')

    open_card_for_edit(@project, card3)
    add_daily_history_chart_and_save(macro_content)
    assert_chart("x_labels", "2009-05-14,2009-05-15,2009-05-16")
  end


  def test_end_date_is_invalid_date
    invalid_end_date_in_macro_content = %{
          daily-history-chart
            aggregate: count(*)
            start-date: 2009 May 16
            end-date: 2009 June 98
            series:
              - label: invalid_end_date
      }
    invalid_end_date_error = "Error in daily-history-chart macro: Parameter end_date must be a valid date."
    @bug = create_card!(:name => 'bug1')
    open_card_for_edit(@project, @bug)

    create_free_hand_macro(invalid_end_date_in_macro_content)
    assert_mql_error_messages(invalid_end_date_error)
  end

  def test_start_date_is_invalid_date
    invalid_start_date_in_macro_content = %{
          daily-history-chart
            aggregate: count(*)
            start-date: 2009 Feb 31
            end-date: 2009 May 16
            series:
              - label: invalid_start_date
        }
    invalid_start_date_error = "Error in daily-history-chart macro: Parameter start_date must be a valid date."
    @bug = create_card!(:name => 'bug1')
    open_card_for_edit(@project, @bug)
    create_free_hand_macro(invalid_start_date_in_macro_content)
    assert_mql_error_messages(invalid_start_date_error)
  end

  def test_start_date_is_after_end_date
    invalid_date_in_macro_content = %{
          daily-history-chart
            aggregate: count(*)
            start-date: 2009 May 16
            end-date: 2009 May 15
            series:
              - label: invalid_date
        }
    invalid_date_error = "Error in daily-history-chart macro: start-date must be before end-date."
    @bug = create_card!(:name => 'bug1')
    open_card_for_edit(@project, @bug)
    create_free_hand_macro(invalid_date_in_macro_content)
    assert_mql_error_messages(invalid_date_error)
  end

  def test_using_TAGGED_WITH_in_chart_condition
    invalid_TAGGED_WITH_in_content = %{
        daily-history-chart
          aggregate: count(*)
          chart-conditions: type=card AND TAGGED with "foo"
          start-date: 2009 May 16
          end-date: 2009 May 17
          series:
            - label: invalid_TAGGED_WITH_property
      }
    invalid_TAGGED_WITH_error_message = "Error in daily-history-chart macro: TAGGED WITH is not supported in the daily history chart."
    @bug = create_card!(:name => 'bug1')
    open_card_for_edit(@project, @bug)

    create_free_hand_macro(invalid_TAGGED_WITH_in_content)
    assert_mql_error_messages(invalid_TAGGED_WITH_error_message)
  end

  def test_user_gets_an_error_message_when_using_project_parameter_in_daily_history_chart_on_card
    card = create_card!(:name => 'foo')
    @another_project = create_project(:identifier => "another_project", :admins => [users(:proj_admin)], :users => [users(:project_member)])
    macro_content = %{
          daily-history-chart
            aggregate: COUNT(*)
            start-date: 2009 May 14
            end-date: 2009 May 16
            project: another_project
            series:
              - label: number of cards
                project: another_project
        }
    open_card_for_edit(@project, 1)
    create_free_hand_macro(macro_content)
    assert_mql_error_messages("Error in daily-history-chart macro: Project parameter is not allowed for the daily history chart")
  end

  def test_using_TODAY_or_CURRENT_USER_or_THIS_CARD_property_on_card
    size = create_managed_number_list_property(SIZE, [1, 2, 3, 4])
    story_1 = create_card!(:name => 'story1', SIZE => '1')

    macro_content = %{
        daily-history-chart
          aggregate: count(*)
          chart-conditions: size > THIS CARD.number AND "created by" = current user AND "created on" = TODAY
          start-date: 2009 May 14
          end-date: 2019 May 16
          x-title: our date
          y-title: our count
          series:
            - color: Yellow
              conditions: size > THIS CARD.number AND "created by" = current user AND "created on" = TODAY
            - label: lable should also print
              color: Green
              conditions: size > THIS CARD.number AND "created by" = current user AND "created on" = TODAY
        }
    open_card_for_edit(@project, story_1)
    create_free_hand_macro(macro_content)
    assert_mql_error_messages("Error in daily-history-chart macro: THIS CARD.Number is not supported in the daily history chart chart-conditions or series conditions parameters. Current User is not supported in the daily history chart. Today is not supported in the daily history chart., start-date and end-date are more than 5 years apart.")
  end

  def test_using_TODAY_or_CURRENT_USER_or_THIS_CARD_property_on_wiki
    size = create_managed_number_list_property(SIZE, [1, 2, 3, 4])

    open_wiki_page_in_edit_mode 'test page'
    macro_content = %{
          daily-history-chart
            aggregate: count(*)
            chart-conditions: size > 2 AND "created by" = current user AND "created on" = TODAY
            start-date: 2009 May 14
            end-date: 2019 May 16
            x-title: our date
            y-title: our count
            series:
              - color: Yellow
                conditions: "created by" = current user AND "created on" = TODAY
              - label: lable should also print
                color: Green
                conditions: "created by" = current user AND "created on" < TODAY
          }
    create_free_hand_macro(macro_content)
    assert_mql_error_messages("Error in daily-history-chart macro: Current User is not supported in the daily history chart. Today is not supported in the daily history chart., start-date and end-date are more than 5 years apart.")
  end

  def test_view_daily_history_chart_on_wiki_page
    daily_history_chart = <<-YAML

          daily-history-chart
            aggregate: COUNT(*)
            start-date: 14 May 2009
            end-date: 16 May 2009
            series:
              - label: Total Count

    YAML
    page = @project.pages.create!(:name => 'page1')

    open_wiki_page_in_edit_mode(page.name)

    create_free_hand_macro(daily_history_chart)
    click_save_link
    change_license_to_allow_anonymous_access
    @project.update_attribute(:anonymous_accessible, true)
    logout
    with_ajax_wait { open_wiki_page(@project, "page1") }
    assert_text_not_present("Daily history charts cannot be viewed for a page version.")
  end

  #bug 9479
  def test_view_daily_history_chart_on_card
    daily_history_chart = <<-YAML

          daily-history-chart
            aggregate: COUNT(*)
            start-date: 14 May 2009
            end-date: 16 May 2009
            series:
              - label: Total Count

    YAML
    bug = create_card!(:name => 'bug1')

    open_card_for_edit(@project, bug)
    create_free_hand_macro_and_save(daily_history_chart)
    change_license_to_allow_anonymous_access
    @project.update_attribute(:anonymous_accessible, true)
    logout
    with_ajax_wait { open_card(@project, bug.number) }
    assert_text_not_present("Daily history charts cannot be viewed for a card version.")
  end
end
