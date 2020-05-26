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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class DailyHistoryChartValidationsTest < ActiveSupport::TestCase
  def setup
    login_as_member
  end

  def test_should_not_allow_project_parameter
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        project: first_project
        series:
          - label: First
    }} }
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_should_not_do_other_validations_when_validating_project_parameter_failed
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        project: first_project
        series:
          - label: First
            conditions: type = xxx
    }} }
    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /#{'Project'.bold} parameter is not allowed for the daily history chart/ do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_should_not_allow_project_parameter_in_series
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: First
            project: first_project
    }} }
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_should_not_allow_from_tree_condition
    with_data_series_chart_project do |project|
      project.update_attribute :time_zone, ActiveSupport::TimeZone.new('UTC').name
      template = default_template(:chart_conditions => "FROM TREE 'planning tree'")
      
      assert_raise_message Macro::ProcessingError, /FROM TREE.*\sis not supported in the daily history chart/ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end
  
  def test_should_require_a_valid_chart_condition
    with_first_project do |project|
      template = default_template(:chart_conditions => "Type = foo")

      assert_raise Macro::ProcessingError do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_should_require_a_valid_start_date
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: Foobuary
        end-date: 23 May 2010
        series:
          - label: 
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /must be a valid date./ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_should_require_a_scope_series_when_target_release_date_is_given
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2010
        target-release-date: 16 May 2010
        completion-series: xyz
        series:
          - label: xyz
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError,/'scope-series' and 'completion-series' are required to show burnup chart with target-release-date./ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end
  
  def test_should_require_a_completion_series_when_target_release_date_is_given
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2010
        target-release-date: 16 May 2010
        scope-series: xyz
        series:
          - label: xyz
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError,/'scope-series' and 'completion-series' are required to show burnup chart with target-release-date./ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end
  
  def test_should_validate_burn_up_chart_with_target_release_date
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2010
        target-release-date: 16 May 2010
        scope-series: A scope series
        completion-series: A completion series
        series:
          - label: A scope series
          - label: A completion series
    }} }

    with_first_project do |project|
      begin
        chart = Chart.extract(template, 'daily-history-chart', 1)
      rescue Macro::ProcessingError => e
        #fail on error
        assert false, "Threw error: #{e.message}"
      end  
    end
  end

  def test_should_validate_start_date_and_target_release_date_in_5_years_range
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2010
        target-release-date: 16 May 2015
        scope-series: A scope series
        completion-series: A completion series
        series:
          - label: A scope series
          - label: A completion series
    }} }
    with_first_project do |project|
      assert_raise_message Macro::ProcessingError,/#{'start-date'.bold} and #{'target-release-date'.bold} are more than 5 years apart/ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end

  end

  def test_should_validate_start_date_and_end_date_in_5_years_range
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2020
        target-release-date: 16 May 2011
        scope-series: A scope series
        completion-series: A completion series
        series:
          - label: A scope series
          - label: A completion series
    }} }
    with_first_project do |project|
      assert_raise_message Macro::ProcessingError,/#{'start-date'.bold} and #{'end-date'.bold} are more than 5 years apart/ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end

  end


  def test_target_release_date_should_be_after_start_date
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 12 May 2010
        end-date: 23 May 2010
        target-release-date: 11 May 2010
        scope-series: A scope series
        completion-series: A completion series
        series:
          - label: A scope series
          - label: A completion series
    }} }
    with_first_project do |project|
      assert_raise_message Macro::ProcessingError,/#{'start-date'.bold} must be before #{'target-release-date'.bold}/ do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_should_not_allow_today_as_series_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: 
            conditions: 'start date' = today
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /Today.*\sis not supported in the daily history chart/ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end

  def test_should_not_allow_today_as_chart_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: 'start date' = today
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: 
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /Today.*\sis not supported in the daily history chart/ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end
  
  def test_should_display_multiple_chart_and_series_error_messages_without_duplicates_and_with_spaces_between_each_message
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: 'start date' = today
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: 
            conditions: 'start date' = today AND number = THIS CARD.number AND number = THIS CARD.number
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /#{'Today'.bold} is not supported in the daily history chart\. #{'THIS CARD.Number'.bold} is not supported in the daily history chart./ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end
  
  # bug #9624 
  def test_should_show_error_if_this_card_is_used_in_chart_conditions
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: 'release' = THIS CARD.number
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: 
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /#{'THIS CARD.Number'.bold} is not supported in the daily history chart chart-conditions or series conditions parameters./ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end
  
  def test_should_not_allow_tagged_with_as_chart_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: tagged with 'dangerzone'
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: heyo
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /TAGGED WITH.*\sis not supported in the daily history chart.$/ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end
  
  def test_should_not_allow_tagged_with_as_series_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: 
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: heyo
            conditions: tagged with 'bazookajoe'
    }} }

    with_first_project do |project|
      assert_raise_message Macro::ProcessingError, /TAGGED WITH.*\sis not supported in the daily history chart./ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end

  def test_should_require_a_valid_card_type
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 22 May 2010
        end-date: 23 May 2010
        series:
          - label: 
            conditions: Type = foo
    }} }

    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_should_require_a_valid_aggregate
    template = default_template(:aggregate => "x")
    
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        chart = Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_should_require_start_date_before_end_date
    template = default_template(:start_date => 2.days.from_now, :end_date => 1.day.ago)
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  def test_today_detected_in_conditions
    with_first_project do |project|
      query_string = "SELECT COUNT(*) AS OF '14 May 2009' WHERE 'start date' IS TODAY"
      assert_equal ["#{'Today'.bold} is not supported in the daily history chart."], CardQuery::DailyHistoryChartValidations.new(CardQuery.parse(query_string)).execute
    end
  end

  def test_current_user_detected_in_conditions
    with_first_project do |project|
      query_string = "SELECT COUNT(*) AS OF '14 May 2009' WHERE 'dev' IS CURRENT USER"
      login_as_member
      assert_equal ["#{'Current User'.bold} is not supported in the daily history chart."], CardQuery::DailyHistoryChartValidations.new(CardQuery.parse(query_string)).execute
    end
  end

  def test_this_card_properties_detected_in_conditions
    with_first_project do |project|
      query_string = "SELECT COUNT(*) AS OF '14 May 2009' WHERE number IS THIS CARD.number"
      assert_equal ["#{'THIS CARD.Number'.bold} is not supported in the daily history chart chart-conditions or series conditions parameters."], CardQuery::DailyHistoryChartValidations.new(CardQuery.parse(query_string)).execute
    end
  end

  def test_should_show_single_error_when_and_keyword_is_used
    with_card_query_project do |project|
      query_string = "SELECT COUNT(*) AS OF '14 May 2009' WHERE number IS THIS CARD.number AND number IS THIS CARD.number"
      assert_equal ["#{'THIS CARD.Number'.bold} is not supported in the daily history chart chart-conditions or series conditions parameters."], CardQuery::DailyHistoryChartValidations.new(CardQuery.parse(query_string)).execute
    end
  end

  def test_should_warn_users_with_useful_error_message_when_this_card_is_used_in_conditions_parameter_of_a_new_card
    template = default_template(:aggregate => 'COUNT(*)', :start_date => '2 Jun 2009', :end_date => '6 Jun 2009', :chart_conditions => "type=THIS CARD.type")
    with_new_project(:time_zone => 'UTC') do |project|
      assert_raise_message Macro::ProcessingError, /#{"THIS CARD.type".bold} is not supported in the daily history chart chart-conditions or series conditions parameters/i do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.new(:number => 42, :name => 'new card'))
      end
    end
  end

  def test_should_give_error_when_scope_series_name_does_not_exist_in_series
    template = forecast_template('scope-series' => 'SCOPE does not exist', 'completion-series' => 'COMPLETED')
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_should_give_error_when_completion_series_name_does_not_exist_in_series
    template = forecast_template('scope-series' => 'scope', 'completion-series' => 'COMPLETED does not exist')
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_x_labels_step_is_a_number
    template = x_labels_step_template('not_number')
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_x_labels_step_must_bigger_than_zero
    template1 = x_labels_step_template(0)
    template2 = x_labels_step_template(-1)
    with_first_project do |project|
      assert_raise Macro::ProcessingError do
        Chart.extract(template1, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
      assert_raise Macro::ProcessingError do
        Chart.extract(template2, 'daily-history-chart', 1, :content_provider => project.cards.first)
      end
    end
  end

  def test_some_chart_level_parameters_should_be_mandatory
    with_first_project do |project|
      template = %{ {{
        daily-history-chart
      }} }
    
      assert_raise_message(Macro::ProcessingError, /Parameters #{'aggregate, end-date, series, start-date'.bold} are required/) do
        Chart.extract(template, 'daily-history-chart', 1)
      end
    end
  end

  private
  def default_template(attrs = {})
    builder = Macro::Builder.parse <<-TEMPLATE
{{
  daily-history-chart
    aggregate: COUNT(*)
    start-date: 14 May 2009
    end-date: 17 May 2009
    series:
    - label: First
}}
TEMPLATE
    if attrs.is_a?(Hash)
      attrs[:start_date] = to_date_string attrs[:start_date] if attrs[:start_date]
      attrs[:end_date] = to_date_string attrs[:end_date] if attrs[:end_date]
    end
    builder.build(attrs)
  end

  def to_date_string(date)
    return if date.blank?
    date.is_a?(String) ? date : date.to_date.strftime("%d %b %Y")
  end

  def forecast_template(attrs={})
    default_template(
      {
        'start-date' => '8 May 2009',
        'end-date' => '16 May 2009',
        'scope-series' => 'Scope',
        'completion-series' => 'Completed',
        'chart-width' => '800',
        'plot-width' => '600',
        'legend-max-width' => '200',
        'series' => [
          {'label' => 'Scope', 'conditions' => 'status > new'},
          {'label' => 'Completed', 'conditions' => 'status = closed'}
        ]
      }.merge(attrs)
    )
  end

  def x_labels_step_template(x_labels_step)
    builder = Macro::Builder.parse <<-TEMPLATE
{{
  daily-history-chart
    aggregate: COUNT(*)
    start-date: 1 May 2009
    end-date: 15 May 2009
    series:
    - label: First
}}
TEMPLATE
    builder.build('x-labels-step' => x_labels_step)
  end
end
