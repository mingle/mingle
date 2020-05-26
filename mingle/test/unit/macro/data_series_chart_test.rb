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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class DataSeriesChartTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit, TreeFixtures::PlanningTree

  def setup
    login_as_member
    @project = data_series_chart_project
    @project.activate
    @data_series_point_chart_options = {'show' =>false, 'symbols' =>{}, 'focus' =>{'expand' =>{'enabled' =>false}}}
    @data_series_tooltip_chart_options = {'grouped' => false}
  end

  def test_can_render_chart_for_a_non_host_project
    first_project.with_active_project do |active_project|
      template = %{ {{
        data-series-chart
          cumulative: false
          project: data_series_chart_project
          series:
            - label       : Scope
              data        : SELECT 'Entered Scope Iteration', SUM(Size)
      }} }

      chart = Chart.extract(template, 'data-series', 1)
      chart_options = JSON.parse(chart.generate)
      assert template_can_be_cached?(template, active_project)
      assert_equal %w(1 2 3 4 5), chart.x_axis_values
      assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope'].values
      assert_equal @data_series_point_chart_options, chart_options['point']
      assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    end
  end

  def test_should_be_able_to_render_embed_chart
    template = %{ {{
      data-series-chart
        cumulative: false
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    scanner = StringScanner.new(template)
    scanner.scan_until(Chart::MACRO_SYNTAX)
    parameters = Macro.parse_parameters(scanner[2])
    content_provider = @project.cards.first
    chart = Macro.create('data-series-chart', {:project => @project,
                                                :view_helper => view_helper,
                                                :content_provider_project => @project,
                                                :content_provider => content_provider,
                                                :embed_chart => true}, parameters, template)


      assert_include "id='dataserieschart-Card-#{content_provider.id}-1'", chart.chart_callback({position: 1})
  end

  def test_can_use_plvs
    create_plv!(@project, :name => 'my_scope_label', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Scope')
    create_plv!(@project, :name => 'my_scope_data',  :data_type => ProjectVariable::STRING_DATA_TYPE, :value => "SELECT 'Entered Scope Iteration', SUM(Size)")

    first_project.with_active_project do |active_project|
      create_plv!(active_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'data_series_chart_project')

      template = ' {{
        data-series-chart
          cumulative: false
          project: (my_project)
          series:
            - label       : (my_scope_label)
              data        : (my_scope_data)
      }} '

      chart = Chart.extract(template, 'data-series', 1)
      chart_options = JSON.parse(chart.generate)

      assert template_can_be_cached?(template, active_project)
      assert_equal %w(1 2 3 4 5), chart.x_axis_values
      assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope'].values
      assert_equal @data_series_point_chart_options, chart_options['point']
      assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    end
  end

  def test_can_render_simple_non_cumulative_line
    template = %{ {{
      data-series-chart
        cumulative: false
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  # bug #9795
  def test_can_render_chart_with_numeric_label
    template = %{ {{
      data-series-chart
        cumulative: false
        series:
          - label       : 123
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 14, 0, 0, 0], chart.series_by_label['123'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_render_simple_non_cumulative_line_using_string_parameter
    template = %{ {{
      data-series-chart
        cumulative: 'false'
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_render_simple_line_cumulative_at_chart_level
    template = %{ {{
      data-series-chart
        cumulative  : true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 43, 43, 43, 43], chart.series_by_label['Scope'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_render_simple_line_cumulative_at_chart_level_using_string_parameter
    template = %{ {{
      data-series-chart
        cumulative  : true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 43, 43, 43, 43], chart.series_by_label['Scope'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_cumulative_must_be_true_or_false
    e = assert_error_on_charting %{ {{
      data-series-chart
        cumulative: bogus
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    assert e.message.include?('cumulative')
    assert e.message.include?('true')
    assert e.message.include?('false')
  end

  def test_can_render_multiple_series
    template = %{ {{
      data-series-chart
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
          - label       : Analysis Complete
            data        : SELECT 'Analysis Complete Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5), chart.x_axis_values
    assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope'].values
    assert_equal [27, 4, 12, 0 , 0], chart.series_by_label['Analysis Complete'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_render_line_down_from
    template = %{ {{
      data-series-chart
        cumulative: true
        start-label: Custom Start Label
        series:
          - label       : Remaining Work
            data        : SELECT 'Development Complete Iteration', SUM(Size)
            down-from   : SELECT SUM(Size) WHERE 'Entered Scope Iteration' IS NOT NULL
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal ['Custom Start Label', '1', '2', '3', '4', '5', '6', '7'], chart.x_axis_values
    assert_equal [43, 33, 26, 22, 10, 10, 10, 10], chart.series_by_label['Remaining Work'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_turn_off_start_label_when_rendering_line_down_from
    template = %{ {{
        data-series-chart
          cumulative: true
          show-start-label: false
          series:
            - label       : Remaining Work
              data        : SELECT 'Development Complete Iteration', SUM(Size)
              down-from   : SELECT SUM(Size) WHERE 'Entered Scope Iteration' IS NOT NULL
      }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert template_can_be_cached?(template, @project)
    assert_equal %w(1 2 3 4 5 6 7), chart.x_axis_values
    assert_equal [33, 26, 22, 10, 10, 10, 10], chart.series_by_label['Remaining Work'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_show_start_label_must_be_true_or_false
    e = assert_error_on_charting %{ {{
        data-series-chart
          cumulative: true
          show-start-label: asfsaf
          series:
            - label       : Remaining Work
              data        : SELECT 'Development Complete Iteration', SUM(Size)
              down-from   : SELECT SUM(Size) WHERE 'Entered Scope Iteration' IS NOT NULL
      }} }
    assert e.message.include?('show-start-label')

  end

  def test_can_specify_x_labels_property_for_chart
    assert_equal 7, @project.find_property_definition('Development Complete Iteration').values.size
    assert_equal 5, @project.find_property_definition('Analysis Complete Iteration').values.size

    template = %{ {{
      data-series-chart
        x-labels-property: Development Complete Iteration
        series:
          - label       : Analysis Complete
            data        : SELECT 'Analysis Complete Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    assert_equal %w(1 2 3 4 5 6 7), chart.x_axis_values
    assert_equal [27, 4, 12, 0, 0, 0, 0], chart.series_by_label['Analysis Complete'].values
  end

  def test_bogus_x_labels_property_blows_up_chart
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-property: Nothing Complete Iteration
        series:
          - label       : Analysis Complete
            data        : SELECT 'Analysis Complete Iteration', SUM(Size)
    }} }

    assert e.message.include?('Nothing Complete Iteration')
    assert e.message.include?('x-labels-property')
  end

  def test_can_render_trend
    template = %{ {{
      data-series-chart
        conditions: Type = Story
        cumulative: true
        series:
          - label       : Remaining
            color       : red
            data        : SELECT 'Accepted Iteration', SUM(Size)
            down-from   : SELECT SUM(Size) WHERE 'Entered Scope Iteration' IS NOT NULL
            trend       : true
            trend-scope : 2
            trend-ignore: none
            trend-line-color: blue
            trend-line-style: solid
            trend-line-width: 7
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    # actual testing of trend parameters is in series unit test, this is just making sure rendering does not blow up
    chart.generate
  end

  # bug 3666
  def test_can_tender_trend_with_gobal_trend_style_setting
    template = %{ {{
      data-series-chart
        conditions: Type = Story
        cumulative: true
        trend-line-color: blue
        trend-line-style: solid
        trend-line-width: 7
        series:
          - label       : Remaining
            color       : red
            data        : SELECT 'Accepted Iteration', SUM(Size)
            trend       : true
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    # test not blow up
    chart.generate
  end

  def test_date_labels_fill_in_gaps_and_use_project_format
    template = %{ {{
      data-series-chart
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    expected_labels = (Date.parse('2007-11-26')..Date.parse('2007-12-20')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, chart.x_axis_values
  end

  def test_start_and_end_label_can_be_overridden_for_date_properties_to_a_smaller_range
    template = %{ {{
      data-series-chart
        x-labels-start: 29 Nov 2007
        x-labels-end: 2007-12-05
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    expected_labels = (Date.parse('2007-11-29')..Date.parse('05 Dec 2007')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, chart.labels_for_plot
    assert_equal [14, 20, 20, 20, 21, 29, 29], chart.series_data_for_plot('Scope')
    chart.generate
  end

  def test_start_label_can_support_THIS_CARD
    this_card = create_card!(:name => 'story3', :card_type => 'story')
    this_card.update_attribute 'cp_entered_scope_on', Date.parse('2010-01-01')

    template = %{ {{
      data-series-chart
        x-labels-start : THIS CARD."Entered Scope On"
        x-labels-end: 2010-01-20
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1, { :content_provider => this_card })

    expected_labels = (Date.parse('2010-01-01')..Date.parse('2010-01-20')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, chart.labels_for_plot
  end

  def test_start_label_on_card_default_should_show_warning_when_use_THIS_CARD
    story_card_type = @project.card_types.find_by_name('story')
    card_defaults = story_card_type.card_defaults

    template = %{ {{
      data-series-chart
        x-labels-start : THIS CARD."Entered Scope On"
        x-labels-end: 2010-01-20
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    content = Chart.extract(template, 'data-series', 1, { :content_provider => card_defaults }).execute
    assert content =~ /Macros using #{'THIS CARD."Entered Scope On"'.bold} will be rendered when card is created using this card default\./
  end

  def test_should_raise_error_when_property_name_does_not_exist_when_using_THIS_CARD
    this_card = create_card!(:name => 'story3', :card_type => 'story')

    template = %{ {{
      data-series-chart
        x-labels-start : THIS CARD."blabla"
        x-labels-end: 2010-01-20
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }
    assert_raise_message(Macro::ProcessingError, /No such property: #{'blabla'.bold}/) do
      Chart.extract(template, 'data-series', 1, { :content_provider => this_card })
    end
  end

  def test_should_not_raise_error_when_using_hidden_property_when_using_THIS_CARD
    with_new_project do |project|
      login_as_admin
      setup_allow_any_number_property_definition('hidden_property').update_attribute(:hidden, true)
      project.reload
      this_card = create_card!(:name => 'story3', :hidden_property => 1)
      template = ' {{
        data-series-chart
          x-labels-start:
          x-labels-end:
          x-labels-step: THIS CARD.hidden_property
          cumulative: true
          series:
            - label       : Scope
              data        : SELECT name, COUNT(*)
      }} '
      Chart.extract(template, 'data-series', 1, { :content_provider => this_card })
    end
  rescue Exception => e
    fail(e, "#{e.message}\nShould not raise error for hidden property.", e.backtrace.join("\n"))
  end


  def test_should_raise_error_when_property_types_does_not_match_in_card_defaults_when_using_THIS_CARD
    story_card_type = @project.card_types.find_by_name('story')
    card_defaults = story_card_type.card_defaults

    template = %{ {{
      data-series-chart
        x-labels-start : 2010-01-10
        x-labels-end: 2010-01-20
        x-labels-step: THIS CARD."Entered Scope On"
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    assert_raise_message(Macro::ProcessingError, "Data types for parameter #{'x-labels-step'.bold} and #{'THIS CARD."Entered Scope On"'.bold} do not match. Please enter the valid data type for #{'x-labels-step'.bold}.") do
      Chart.extract(template, 'data-series', 1, { :content_provider => card_defaults })
    end
  end

  # bug #6498
  def test_empty_x_labels_start_should_work_when_no_data_is_produced_by_condition
   login_as_admin

   with_new_project do |project|

     width = setup_date_property_definition('new date def')
     width.save!

      template = %{ {{
        data-series-chart
          x-labels-start:
          x-labels-end: 29 Dec 2007
          x-labels-step: 1
          cumulative: true
          series:
            - label       : Scope
              data        : SELECT 'new date def', count(*)
      }} }

      chart = Chart.extract(template, 'data-series', 1)
    end
  end

  # bug #6498
  def test_empty_x_labels_end_should_work_when_no_data_is_produced_by_condition
   login_as_admin

     with_new_project do |project|

       width = setup_date_property_definition('new date def')
       width.save!

      template = %{ {{
        data-series-chart
          x-labels-start: 29 Nov 2007
          x-labels-end:
          x-labels-step: 1
          cumulative: true
          series:
            - label       : Scope
              data        : SELECT 'new date def', count(*)
      }} }

      chart = Chart.extract(template, 'data-series', 1)
    end
  end

  def test_start_and_end_label_can_be_overridden_for_date_properties_to_a_larger_range
    template = %{ {{
      data-series-chart
        x-labels-start: 24 Nov 2007
        x-labels-end: 2007-12-22
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    expected_labels = (Date.parse('2007-11-24')..Date.parse('22 Dec 2007')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, chart.labels_for_plot
    assert_equal [0,0,6,6,14,14,20,20,20,21,29,29,29,29,29,29,37,37,37,41,41,41,41,41,41,41,43,43,43], chart.series_data_for_plot('Scope')
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_start_and_end_label_can_be_overridden_for_date_properties_to_a_mix_of_smaller_and_larger_range
    template = %{ {{
      data-series-chart
        x-labels-start: 29 Nov 2007
        x-labels-end: 2007-12-22
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    expected_labels = (Date.parse('2007-11-29')..Date.parse('22 Dec 2007')).to_a.collect{|d| @project.format_date(d)}
    assert_equal expected_labels, chart.labels_for_plot
    assert_equal [14,20,20,20,21,29,29,29,29,29,29,37,37,37,41,41,41,41,41,41,41,43,43,43], chart.series_data_for_plot('Scope')
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_start_label_must_be_a_parsable_date
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-start : 'abcfef'
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    assert e.message.include?('x-labels-start')
    assert e.message.include?('valid date')
  end

  def test_end_label_must_be_a_parsable_date
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-end : 'abcfef'
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }
    assert e.message.include?('x-labels-end')
    assert e.message.include?('valid date')
  end

  def test_start_and_end_label_can_be_overridden_for_non_date_property
    template = %{ {{
      data-series-chart
        x-labels-start: 2
        x-labels-end: 4
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal %w(2 3 4), chart.labels_for_plot
    assert_equal [0, 18, 21], chart.series_data_for_plot('Closed')
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_start_label_cannot_be_overridden_to_a_non_existant_value
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-start: 8
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    assert e.message.include?('x-labels-start')
    assert e.message.include?('does not exist')
  end

  def test_end_label_cannot_be_overridden_to_a_non_existant_value
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-end: 18
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    assert e.message.include?('x-labels-end')
    assert e.message.include?('does not exist')
  end

  def test_start_label_must_preceed_end_label
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-start: 4
        x-labels-end: 2
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    assert e.message.include?('x-labels-start')
    assert e.message.include?('x-labels-end')
    assert e.message.include?('must be a value less than')
  end

  def test_show_start_works_with_restricted_labels
    template = %{ {{
      data-series-chart
        show-start-label: true
        x-labels-start: 2
        x-labels-end: 4
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal %w(Start 2 3 4), chart.labels_for_plot
    assert_equal [0, 0, 18, 21], chart.series_data_for_plot('Closed')
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_start_label_can_not_be_an_existing_value_for_x_label_prop_def
    e = assert_error_on_charting %{ {{
      data-series-chart
        show-start-label: true
        start-label: 3
        x-labels-start: 2
        x-labels-end: 4
        cumulative: true
        series:
          - label       : Closed
            data        : SELECT 'Accepted Iteration', SUM(Size)
    }} }

    assert e.message.include?('start-label')
    assert e.message.include?('existing value')
  end

  def test_x_labels_step_can_be_numeric_strings
    template = %{ {{
      data-series-chart
        x-labels-step: '5'
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }
    chart = Chart.extract(template, 'data-series', 1)
    assert_equal 5, chart.send(:_x_labels_step)
  end

  def test_x_labels_step_must_be_natural_number
    assert_x_labels_step_must_be_natural_number(0)
    assert_x_labels_step_must_be_natural_number('abc')
    assert_x_labels_step_must_be_natural_number(1.3)
    assert_x_labels_step_must_be_natural_number(-3)
    assert_x_labels_step_must_be_natural_number(-4.5)
  end

  def assert_x_labels_step_must_be_natural_number(step)
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-step: #{step}
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }
    assert e.message.include?('x-labels-step')
    assert e.message.include?('integer number greater than 0')
  end

  def test_can_render_area_and_bar_types_specified_at_series_level
    template = %{ {{
      data-series-chart
        cumulative: true
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
            type        : area
            trend       : true
          - label       : Analysis Complete
            data        : SELECT 'Analysis Complete Iteration', SUM(Size)
            type        : bar
            trend       : true
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
            type        : bar

    }} }
    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_specify_chart_type
    template = %{ {{
      data-series-chart
        chart-type: bar
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }
    chart = Chart.extract(template, 'data-series', 1)
    assert_equal 'bar', chart.chart_type
  end

  def test_bogus_chart_type_blows_up
    e = assert_error_on_charting %{ {{
      data-series-chart
        chart-type: bogus
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }
    assert e.message.include?('chart-type')
    assert e.message.include?('line')
    assert e.message.include?('bar')
    assert e.message.include?('area')
  end

  def test_default_chart_parameters
    template = %{ {{
      data-series-chart
        cumulative: true
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }
    chart = Chart.extract(template, 'data-series', 1)
    assert_equal 'line', chart.chart_type
    assert_equal 'all', chart.trend_scope
    assert_equal 'zeroes-at-end-and-last-value', chart.trend_ignore
    assert_equal 3, chart.trend_line_width
    assert_equal -1, chart.trend_line_color # -1 means use default CD pallette
    assert_equal 'dash', chart.trend_line_style
    assert !chart.trend
    assert_equal 'none', chart.data_point_symbol
    assert !chart.data_labels
  end

  def test_can_render_data_point_symbol
    template = %{ {{
      data-series-chart
        cumulative  : true
        data-point-symbol : diamond
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    data_series_point_chart_options = {'show' => false, 'symbols' => {'Scope' => 'diamond'}, 'focus' =>{'expand' =>{'enabled' =>false}}}
    assert_equal data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_render_different_line_styles
    template = %{ {{
      data-series-chart
        cumulative  : true
        data-point-symbol : diamond
        line-style: dash
        line-width: 6
        series:
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)
    data_series_point_chart_options = {'show' => false, 'symbols' => {'Scope' => 'diamond'}, 'focus' =>{'expand' =>{'enabled' =>false}}}
    assert_equal data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_non_managed_numbers_are_grouped_without_consideration_of_precision
    template = %{ {{
      data-series-chart
        series:
          - label       : Test Free Number
            data        : SELECT 'free number', COUNT(*) ORDER BY 'free number'
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal %w(2.0 3.0 4.0 5), chart.x_axis_values
    assert_equal [3,3,3,2], chart.series_by_label['Test Free Number'].values
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    assert_equal @data_series_point_chart_options, chart_options['point']
  end

  def test_can_chart_users
    @project.add_member create_user!(:name => 'MEMBER@email.com', :login => 'smart_sorted')

    template = ' {{
      data-series-chart
        chart-type: bar
        series:
          - label       : Test Users
            data        : SELECT owner, COUNT(*) ORDER BY owner
    }} '

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal ['bob@email.com (bob)', 'first@email.com (first)', 'longbob@email.com (longbob)', 'member@email.com (member)', 'MEMBER@email.com (smart_sorted)', 'proj_admin@email.com (proj_admin)'], chart.x_axis_values
    assert_equal [0, 2, 0, 2, 0, 0], chart.series_by_label['Test Users'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_chart_with_duplicate_users
    template = ' {{
      data-series-chart
        chart-type: bar
        series:
          - label       : Test Users
            data        : SELECT owner, COUNT(*) ORDER BY owner
    }} '

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal ['bob@email.com (bob)', 'first@email.com (first)', 'longbob@email.com (longbob)', 'member@email.com (member)', 'proj_admin@email.com (proj_admin)'], chart.x_axis_values
    assert_equal [0, 2, 0, 2, 0], chart.series_by_label['Test Users'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_can_use_x_label_start_and_end_for_user_property_labels
    template = ' {{
      data-series-chart
        chart-type: bar
        x-labels-start : first
        x-labels-end : member
        series:
          - label       : Test Users
            data        : SELECT owner, COUNT(*) ORDER BY owner
    }} '

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal ['first@email.com (first)', 'longbob@email.com (longbob)', 'member@email.com (member)'], chart.labels_for_plot
    assert_equal [2, 0, 2], chart.series_data_for_plot('Test Users')
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    assert_equal @data_series_point_chart_options, chart_options['point']
  end

  def test_should_raise_macro_processing_exception_when_x_label_start_user_does_not_exist
    template = ' {{
      data-series-chart
        chart-type: bar
        x-labels-start : suzie
        x-labels-end : member
        series:
          - label       : Test Users
            data        : SELECT owner, COUNT(*) ORDER BY owner
    }} '
    assert_raise_message(Macro::ProcessingError, /suzie.*x-labels-start/) { Chart.extract(template, 'data-series', 1) }
  end

  def test_should_raise_macro_processing_exception_when_x_label_end_user_does_not_exist
    template = ' {{
      data-series-chart
        chart-type: bar
        x-labels-start : member
        x-labels-end : suzie
        series:
          - label       : Test Users
            data        : SELECT owner, COUNT(*) ORDER BY owner
    }} '
    assert_raise_message(Macro::ProcessingError, /suzie.*x-labels-end/) { Chart.extract(template, 'data-series', 1) }
  end


  def test_can_chart_tree_relationship_cards
    release1 = @project.cards.find_by_name('release1')
    @iteration1 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration1', release1.id)
    @iteration2 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration2', release1.id)
    @iteration3 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration3', release1.id)
    @iteration4 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration4', release1.id)
    @iteration5 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration5', release1.id)
    template = %{ {{
      data-series-chart
        chart-type: bar
        cumulative: true
        x-labels-conditions: 'Planning Release' = release1
        conditions: Type = Story AND 'Planning Release' = release1
        series:
          - label       : Test Cards
            data        : SELECT 'Planning iteration', COUNT(*) ORDER BY 'Planning Iteration'
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal [@iteration1, @iteration2, @iteration3, @iteration4, @iteration5].collect(&:number_and_name), chart.x_axis_values
    assert_equal [2, 6, 7, 10, 10], chart.series_by_label['Test Cards'].values
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_cannot_use_x_labels_conditions_when_not_charting_against_card_property
    e = assert_error_on_charting %{ {{
      data-series-chart
        x-labels-conditions: 'Development Complete Iteration' IS NOT NULL
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }
    assert e.message.include?('x-labels-conditions')
  end

  def test_can_render_in_three_d
    template = %{ {{
      data-series-chart
        cumulative: true
        three-d: true
        trend: true
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
            type        : line
          - label       : Analysis Complete
            data        : SELECT 'Analysis Complete Iteration', SUM(Size)
            type        : area
          - label       : Scope
            data        : SELECT 'Entered Scope Iteration', SUM(Size)
            type        : bar

    }} }
    chart = Chart.extract(template, 'data-series', 1)
    chart.generate
  end

  def test_three_d_must_be_true_or_false
    e = assert_error_on_charting %{ {{
      data-series-chart
        three-d: bogus
        x-labels-conditions: 'Development Complete Iteration' IS NOT NULL
        series:
          - label       : Development Complete
            data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }
    assert e.message.include?('three-d')
  end

  def test_can_render_with_custom_titles
    template = %{ {{
      data-series-chart
        x-title: foo
        y-title: bar
        series:
          - label       : Test FooBar
            data        : SELECT 'free number', COUNT(*) ORDER BY 'free number'
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_should_not_have_error_when_there_is_no_cards
      with_new_project do |project|
        project.add_member(User.current)
        setup_date_property_definition('StartDate')
        template = %{ {{
          data-series-chart
            x-title: foo
            y-title: bar
            x-labels-start: '2007-01-01'
            x-labels-end: '2008-01-02'
            series:
              - label       : Test FooBar
                data        : SELECT 'StartDate', COUNT(*)
        }} }

        chart = Chart.extract(template, 'data-series', 1)
        chart_options = JSON.parse(chart.generate)

        assert_equal @data_series_point_chart_options, chart_options['point']
        assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
      end
  end

  def test_this_card_can_be_used_in_the_data_section
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')

      [['A', 1], ['B', 1], ['C', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end

      template = %{ {{
        data-series-chart
          series:
            - label       : Cake
              data        : SELECT Size, COUNT(*) WHERE 'related card' = THIS CARD
      }} }

      chart = Chart.extract(template, 'data-series', 1, {:content_provider => this_card})

      assert_equal %w(1 2 3 4 5), chart.labels_for_plot
      assert_equal [2, 1, 0, 0, 0], chart.series_data_for_plot('Cake')
      chart.generate
    end
  end

  def test_this_card_can_be_used_in_the_conditions
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')

      [['A', 1], ['B', 1], ['C', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end

      template = %{ {{
        data-series-chart
          conditions: 'related card' = THIS CARD
          series:
            - label       : Cake
              data        : SELECT Size, COUNT(*) WHERE Type = Card
      }} }

      chart = Chart.extract(template, 'data-series', 1, {:content_provider => this_card})

      assert_equal %w(1 2 3 4 5), chart.labels_for_plot
      assert_equal [2, 1, 0, 0, 0], chart.series_data_for_plot('Cake')
      chart.generate
    end
  end

  def test_this_card_can_be_used_in_the_down_from_parameter
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')

      [['A', 1], ['B', 1], ['C', 2]].each do |card_name, size|
        card = project.cards.create!(:name => card_name, :cp_size => size, :card_type_name => 'Card')
        related_card_property_definition.update_card(card, this_card)
        card.save!
      end

      # having THIS CARD in the conditions and in the down-from in this template is intentional
      template = %{ {{
          data-series-chart
            conditions: 'related card' = THIS CARD
            cumulative: true
            series:
              - label       : Cake
                data        : SELECT Size, COUNT(*) WHERE 'related card' = THIS CARD
                down-from   : SELECT Size WHERE 'related card' = THIS CARD
        }} }

      chart = Chart.extract(template, 'data-series', 1, {:content_provider => this_card})
      expected_region_mql = {"conditions" =>
                                 {"Start" =>
                                      {"Cake" => "'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}"},
                                  "1" =>
                                      {"Cake" =>
                                           "('related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}) AND NOT NUMBER IN (SELECT number where 'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number} AND Size = 1)"},
                                  "2" =>
                                      {"Cake" =>
                                           "('related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}) AND NOT NUMBER IN (SELECT number where 'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number} AND Size >= 1 AND Size <= 2)"},
                                  "3" =>
                                      {"Cake" =>
                                           "('related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}) AND NOT NUMBER IN (SELECT number where 'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number} AND Size >= 1 AND Size <= 3)"},
                                  "4" =>
                                      {"Cake" =>
                                           "('related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}) AND NOT NUMBER IN (SELECT number where 'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number} AND Size >= 1 AND Size <= 4)"},
                                  "5" =>
                                      {"Cake" =>
                                           "('related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number}) AND NOT NUMBER IN (SELECT number where 'related card' = NUMBER #{this_card.number} AND 'related card' = NUMBER #{this_card.number} AND Size >= 1 AND Size <= 5)"}},
                             "project_identifier" => {"Cake" => "card_query_project"}}
      actual_region_mql = JSON.parse(chart.generate)['region_mql']

      assert_equal expected_region_mql, actual_region_mql
    end
  end

  def test_other_errors_show_up_before_the_this_card_error_on_card_defaults
    with_three_level_tree_project do |project|
      iteration_card_defaults = project.card_types.find_by_name('iteration').card_defaults

      template = %{ {{
       data-series-chart
          conditions: type = jimmy
          cumulative: true
          series:
          - label: Series 1
            color: black
            type: line
            data: SELECT size, count(*) WHERE 'Planning iteration' = THIS CARD
            trend: true
            trend-line-width: 2
      }} }

      assert_raise_message Macro::ProcessingError, /#{'jimmy'.bold} is not a valid value for #{'Type'.bold}, which is restricted to #{'Card'.bold}, #{'iteration'.bold}, #{'release'.bold}, and #{'story'.bold}/ do
        content = Chart.extract(template, 'data-series', 1, {:content_provider => iteration_card_defaults}).execute
      end

      template = %{ {{
       data-series-chart
          conditions: type = story
          cumulative: true
          series:
          - label: Series 1
            color: black
            type: line
            data: SELECT size, count(*) WHERE 'Planning iteration' = THIS CARD
            trend: true
            trend-line-width: 2
      }} }

      content = Chart.extract(template, 'data-series', 1, {:content_provider => iteration_card_defaults}).execute
      assert content =~ /Macros using #{'THIS CARD'.bold} will be rendered when card is created using this card default\./
    end
  end

  def test_this_card_notice_should_show_up_for_card_defaults_when_this_card_is_used_in_conditions_field
    with_card_query_project do |project|
      card_defaults = project.card_types.first.card_defaults
      related_card_property_definition = project.find_property_definition('related card')

      template = %{ {{
        data-series-chart
          conditions: 'related card' = THIS CARD
          cumulative: true
          series:
            - label       : Cake
              data        : SELECT Size, COUNT(*)
      }} }

      content = Chart.extract(template, 'data-series', 1, {:content_provider => card_defaults}).execute
      assert content =~ /Macros using #{'THIS CARD'.bold} will be rendered when card is created using this card default\./
    end
  end

  def test_this_card_notice_should_not_show_up_multiple_times
    with_card_query_project do |project|
      card_defaults = project.card_types.first.card_defaults
      related_card_property_definition = project.find_property_definition('related card')

      template = %{ {{
        data-series-chart
          conditions: 'related card' = THIS CARD
          cumulative: true
          series:
            - label       : Cake
              data        : SELECT Size, SUM(Size) WHERE 'related card' = THIS CARD
          series:
            - label       : Butter
              data        : SELECT accurate_estimate, COUNT(*) WHERE 'related card' = THIS CARD
      }} }

      content = Chart.extract(template, 'data-series', 1, {:content_provider => card_defaults}).execute
      assert_equal 1, content.scan(/Macros using #{'THIS CARD'.bold} will be rendered when card is created using this card default\./).size
    end
  end

  def test_series_from_different_project
    data_series_chart_project.with_active_project do |active_project|
      template = %{ {{
        data-series-chart
          cumulative: false
          series:
            - project     : card_query_project
              label       : card_query_project_scope
              data        : SELECT 'Release', COUNT(*)
            - project     : data_series_chart_project
              label       : data_series_chart_project_scope
              data        : SELECT 'Release', COUNT(*)
      }} }

      chart = Chart.extract(template, 'data-series', 1)
      chart_options = JSON.parse(chart.generate)

      assert_equal %w(1 2), chart.x_axis_values
      assert_equal [1, 0], chart.series_by_label['card_query_project_scope'].values
      assert_equal [0, 0], chart.series_by_label['data_series_chart_project_scope'].values
      assert_equal @data_series_point_chart_options, chart_options['point']
      assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    end
  end

  def test_date_label_should_formated_in_chart_level_project_date_format
    with_data_series_chart_project { |project| project.update_attribute(:date_format, '%m-%d-%Y') }
    with_first_project { |project| project.update_attribute(:date_format, '%m/%d/%Y') }
    with_project_without_cards { |project| project.update_attribute(:date_format, '%Y/%m/%d') }

    with_first_project do |project|

      template = %{ {{
        data-series-chart
          project: project_without_cards
          x-labels-start: 2007/11/29
          x-labels-end: 2007/12/22
          x-labels-step: 1
          series:
            - label       : Scope
              project     : data_series_chart_project
              data        : SELECT 'Entered Scope On', SUM(Size)
      }} }

      chart = Chart.extract(template, 'data-series', 1)

      expected_labels = (Date.parse('2007-11-29')..Date.parse('22 Dec 2007')).to_a.collect{|d| project_without_cards.format_date(d)}
      assert_equal expected_labels, chart.labels_for_plot
    end
  end

  def test_x_date_labels_is_formatted_in_chart_level_project_even_labels_loaded_from_first_series
    with_data_series_chart_project { |project| project.update_attribute(:date_format, '%Y-%d-%m') }
    with_project_without_cards { |project| project.update_attribute(:date_format, '%Y-%m-%d') }
    template = %{ {{
      data-series-chart
        project: project_without_cards
        series:
          - label       : Scope
            project     : data_series_chart_project
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    expected_labels = (Date.parse('2007/11/26')..Date.parse('2007/12/20')).to_a.collect{|d| project_without_cards.format_date(d)}
    assert_equal expected_labels, chart.labels_for_plot
  end

  def test_compose_data_from_series_using_data_with_different_project_date_format
    with_project_without_cards { |project| project.update_attribute(:date_format, '%Y/%m/%d') }
    @project.update_attribute(:date_format, '%m-%d-%Y')
    template = %{ {{
      data-series-chart
        project: project_without_cards
        x-labels-start: 2007/11/29
        x-labels-end: 2007/12/5
        x-labels-step: 1
        cumulative: true
        series:
          - label       : Scope
            project     : data_series_chart_project
            data        : SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    assert_equal [14, 20, 20, 20, 21, 29, 29], chart.series_data_for_plot('Scope')
  end

  def test_cross_project_reporting_for_chart_using_tree_relationship_property_definition_should_throw_exception_when_x_labels_condtion_not_in_the_project
    template = %{ {{
      data-series-chart
        cumulative: true
        x-labels-conditions: 'Planning Release' = release1
        conditions: Type = Story AND 'Planning Release' = release1
        series:
          - label       : Test Cards
            project     : project_without_cards
            data        : SELECT 'Status', COUNT(*)
    }} }

    assert_raise_message(Macro::ProcessingError, /Card property \'#{'Planning Release'.bold}\' does not exist/) do
      Chart.extract(template, 'data-series', 1)
    end
  end

  def test_propety_not_exist_error_contain_context_project_info
    e = assert_error_on_charting %{ {{
      data-series-chart
        project: project_without_cards
        series:
          - label       : Test Cards
            project     : data_series_chart_project
            data        : SELECT 'None Exist Prop', COUNT(*) ORDER BY 'Planning Iteration'
    }} }

    assert_equal data_series_chart_project, e.context_project
  end

  def test_card_type_not_exist_error_contain_context_project_info
    e = assert_error_on_charting ' {{
     data-series-chart
        conditions: type = jimmy
        series:
        - label: Series 1
          project: three_level_tree_project
          data: SELECT size, count(*)
    }} '

    assert_equal three_level_tree_project, e.context_project
  end

  def test_invalid_aggregate_error_not_contain_context_project_info
    e = assert_error_on_charting ' {{
     data-series-chart
        series:
        - label: Series 1
          project: three_level_tree_project
          data: SELECT size, suvdm(*)
    }} '

    assert_nil e.context_project
  end

  # bug 5822 - we were ordering alphabetically before
  def test_x_labels_for_an_unmanaged_numeric_are_in_numeric_order
    card = @project.cards.create!(:name => 'one hundred', :card_type_name => 'Story', :cp_free_number => 200)

    template = %{ {{
      data-series-chart
        cumulative: false
        series:
          - label       : Hello There
            data        : SELECT 'free number', COUNT(*)
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    assert_equal %w(2.0 3.0 4.0 5 200), chart.x_axis_values
    assert_equal [3, 3, 3, 2, 1], chart.series_by_label['Hello There'].values
  end

  def assert_error_on_charting(template)
    begin
      chart = Chart.extract(template, 'data-series', 1)
      JSON.parse(chart.generate)
    rescue Macro::ProcessingError => e
      return e
    end
    fail('exception should have been thrown')
  end

  def test_should_support_from_tree
      with_three_level_tree_project do |project|

        template = %{ {{
          data-series-chart
            conditions: FROM TREE "three level tree"
            cumulative: false
            series:
              - label       : label
                data        : SELECT 'size', Count(*)
        }} }

        chart = Chart.extract(template, 'data-series', 1)
        assert_equal [1, 0, 1, 0], chart.series_by_label['label'].values

        not_in_tree = create_card!(:size => 1, :name => 'card not in tree', :number => 10)
        chart = Chart.extract(template, 'data-series', 1)
        assert_equal [1, 0, 1, 0], chart.series_by_label['label'].values
    end
  end

  def test_should_use_x_label_tree_to_specify_the_x_label_conditions
    with_three_level_tree_project do |project|
      template = %{ {{
       data-series-chart
          x-labels-conditions: type=iteration
          x-labels-tree: 'three level tree'
          series:
          - label: Series1
            data: SELECT 'Planning iteration', COUNT(*)
      }} }

      create_card!(:name => 'iteration4', :card_type => 'iteration')
      chart = Chart.extract(template, 'data-series', 1)

      assert_equal ['release1 > iteration1', 'release1 > iteration2'], chart.labels_for_plot
      assert_equal [2, 0], chart.series_by_label['Series1'].values
    end
  end

  def test_x_labels_tree_should_work_with_start_label
    with_three_level_tree_project do |project|
      template = %{ {{
       data-series-chart
          show-start-label: true
          x-labels-conditions: type=iteration
          x-labels-tree: 'three level tree'
          series:
          - label: Series1
            data: SELECT 'Planning iteration', COUNT(*)
      }} }

      create_card!(:name => 'iteration4', :card_type => 'iteration')
      chart = Chart.extract(template, 'data-series', 1)

      assert_equal ['Start', 'release1 > iteration1', 'release1 > iteration2'], chart.labels_for_plot
      assert_equal [0, 2, 0], chart.series_by_label['Series1'].values
    end
  end

  def test_should_show_error_message_when_tree_is_not_exist_in_the_x_labels_tree
    with_three_level_tree_project do |project|
      template = %{ {{
       data-series-chart
          show-start-label: true
          x-labels-conditions: type=iteration
          x-labels-tree: 'doesnt exist'
          series:
          - label: Series1
            data: SELECT 'Planning iteration', COUNT(*)
      }} }

      assert_raise_message(Macro::ProcessingError, /doesnt exist/) do
        Chart.extract(template, 'data-series', 1)
      end
    end
  end

  def test_should_use_x_label_tree_to_specify_to_overcome_cross_project_card_number_mismatch_problem

    # first project: iteration1 = [added to scope => iteration1, estimate => 1, number != second_project.iteration1.number]
    login_as_admin
    first_project = with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      estimate = setup_numeric_property_definition('estimate', [1,2,5])
      scope = setup_card_relationship_property_definition('Add to scope')
      iteration = project.card_types.find_by_name('iteration')
      iteration.add_property_definition estimate
      iteration.add_property_definition scope

      iteration1 = project.cards.find_by_name('iteration1')
      iteration1.update_properties('estimate' => 1, 'add to scope' => iteration1.id)
      iteration1.save!
    end

    # second project: iteration1 = [added to scope => iteration1, estimate => 1, number != first_project.iteration1.number]
    second_project = with_new_project do |project|
      login_as_admin
      init_planning_tree_types
      create_three_level_tree
      estimate = setup_numeric_property_definition('estimate', [1,2,5])
      scope = setup_card_relationship_property_definition('Add to scope')
      iteration = project.card_types.find_by_name('iteration')
      iteration.add_property_definition estimate
      iteration.add_property_definition scope

      iteration1 = project.cards.find_by_name('iteration1')
      max_number = project.cards.maximum('number')
      iteration1.update_attribute(:number, max_number + 1)
      iteration1.update_properties('estimate' => 1, 'add to scope' => iteration1.id)
      iteration1.save!

      template = %{ {{
       data-series-chart
          conditions: FROM TREE 'three_level_tree'
          x-labels-tree: 'three_level_tree'
          x-labels-conditions: type=iteration
          series:
          - label: Series1
            project: #{project.identifier}
            data: SELECT 'Add to scope', SUM(estimate)
          - label: Series2
            project: #{first_project.identifier}
            data: SELECT 'Add to scope', SUM(estimate)

      }} }

      chart = Chart.extract(template, 'data-series', 1)

      assert_equal 1, chart.series_by_label['Series1'].values[0]
      assert_equal 1, chart.series_by_label['Series2'].values[0]
    end

  end

  def test_should_use_x_label_tree_to_specify_to_overcome_cross_project_card_number_mismatch_problem_even_when_case_is_different
    login_as_admin
    first_project = with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      iteration1 = project.cards.find_by_name('iteration1')
      iteration1.update_attribute(:name, 'Iteration1')
    end

    second_project = with_new_project do |project|
      login_as_admin
      init_planning_tree_types
      create_three_level_tree

      template = %{ {{
        data-series-chart
          conditions: FROM TREE 'three_level_tree'
          x-labels-tree: 'three_level_tree'
          x-labels-conditions: type=iteration
          series:
          - label: Series1
            project: #{project.identifier}
            data: SELECT 'Planning Iteration', COUNT(*)
          - label: Series2
            project: #{first_project.identifier}
            data: SELECT 'Planning Iteration', COUNT(*)

      }} }

      chart = Chart.extract(template, 'data-series', 1)

      assert_equal [2, 0], chart.series_by_label['Series1'].values
      assert_equal [2, 0], chart.series_by_label['Series2'].values
    end
  end

  def test_x_labels_tree_should_know_difference_between_cards_with_same_name_in_same_tree
    with_new_project do |project|
      login_as_admin
      init_planning_tree_types
      create_two_release_planning_tree

      configuration = project.tree_configurations.find_by_name('two_release_planning_tree')
      iteration3 = project.cards.find_by_name('iteration3')
      configuration.add_child(create_card!(:name => 'story3', :card_type => 'story'), :to => iteration3)
      iteration3.update_attribute(:name, 'iteration1')

      template = %{ {{
        data-series-chart
          x-labels-tree: 'two_release_planning_tree'
          x-labels-conditions: type=iteration
          series:
          - label: Series
            data: SELECT 'Planning Iteration', COUNT(*)
      }} }

      chart = Chart.extract(template, 'data-series', 1)

      assert_equal [2, 0, 1], chart.series_by_label['Series'].values
    end
  end

  def test_can_use_plvs_in_chart
    create_plv!(@project, :name => 'my_labels_start', :data_type => ProjectVariable::DATE_DATA_TYPE,    :value => '29 Nov 2007')
    create_plv!(@project, :name => 'my_labels_end',   :data_type => ProjectVariable::DATE_DATA_TYPE,    :value => '05 Dec 2007')
    create_plv!(@project, :name => 'my_labels_step',  :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1')

    template = %{ {{
      data-series-chart
        x-labels-start: (my_labels_start)
        x-labels-end: (my_labels_end)
        x-labels-step: (my_labels_step)
        cumulative: true
        series:
          - label: Scope
            data: SELECT 'Entered Scope On', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    expected_labels = (Date.parse('29 Nov 2007')..Date.parse('05 Dec 2007')).to_a.collect { |d| @project.format_date(d) }
    assert_equal expected_labels, chart.labels_for_plot
    assert_equal [14, 20, 20, 20, 21, 29, 29], chart.series_data_for_plot('Scope')
    chart.generate
  end

  def test_x_labels_tree_should_error_when_x_labels_property_is_not_card_property
     with_three_level_tree_project do |project|

      e = assert_error_on_charting %{ {{
        data-series-chart
                  x-labels-tree: 'three level tree'
                  x-labels-property:
                  labels:
                  series:
                    - label       : Development Complete
                      data        : SELECT 'status', COUNT(*)
      }} }

      assert e.message.include?('x-labels-tree')
    end
  end

  def test_x_labels_tree_should_error_when_property_from_first_series_is_not_card_property
     with_three_level_tree_project do |project|

      e = assert_error_on_charting %{ {{
        data-series-chart
                  x-labels-tree: 'three level tree'
                  x-labels-property: 'status'
                  labels:
                  series:
                    - label       : Size
                      data        : SELECT 'Planning iteration', COUNT(*)
      }} }

      assert e.message.include?('x-labels-tree')
    end
  end

  def test_titles_can_be_non_text_plvs
    first_card = @project.cards.first
    create_plv!(@project, :name => 'my_x_title', :data_type => ProjectVariable::DATE_DATA_TYPE,    :value => '29 Nov 2007')
    create_plv!(@project, :name => 'my_y_title', :data_type => ProjectVariable::CARD_DATA_TYPE,    :value => first_card.id)

    template = %{ {{
      data-series-chart
        x-title: (my_x_title)
        y-title: (my_y_title)
        series:
          - label       : Test FooBar
            data        : SELECT 'free number', COUNT(*) ORDER BY 'free number'
    }} }

    chart = Chart.extract(template, 'data-series', 1)
    chart_options = JSON.parse(chart.generate)

    assert_equal '29 Nov 2007', chart.x_title
    assert_equal first_card.number_and_name, chart.y_title
    assert_equal @data_series_point_chart_options, chart_options['point']
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  end

  #bug 5592
  def test_should_not_group_by_numeric_precision_when_managed_text_property
    login_as_admin
    first_project = with_new_project do |project|

     UnitTestDataLoader.setup_managed_text_definition('iteration', %w(1 1.0 2 EA))
     create_card!(:name => '1', :number => 1, :iteration => '1')
     create_card!(:name => '2', :number => 2, :iteration => '1')
     create_card!(:name => '3', :number => 3, :iteration => '1')
     create_card!(:name => '4', :number => 4, :iteration => '1')
     create_card!(:name => '5', :number => 5, :iteration => '1.0')

     template = ' {{
       data-series-chart
          conditions:
          cumulative: false
          x-labels-start:
          x-labels-end:
          x-labels-step:
          series:
          - label: Series
            color: black
            type: line
            data: SELECT iteration, count(*) WHERE type = card
            trend: false
     }} '

     chart = Chart.extract(template, 'data-series', 1)

     assert_equal %w(1 1.0 2 EA), chart.labels_for_plot
     assert_equal [4, 1, 0, 0], chart.series_by_label['Series'].values
    end
  end

  def test_multiple_labels_with_the_same_name_have_number_appended
    template = %{ {{
     data-series-chart
       series:
         - label       : Scope
           data        : SELECT 'Entered Scope Iteration', SUM(Size)
         - label       : Scope
           data        : SELECT 'Analysis Complete Iteration', SUM(Size)
         - label       : Scope (1)
           data        : SELECT 'Development Complete Iteration', SUM(Size)
    }} }

    chart = Chart.extract(template, 'data-series', 1)

    assert_equal [29, 14, 0, 0, 0], chart.series_by_label['Scope (2)'].values
    assert_equal [27, 4, 12, 0 , 0], chart.series_by_label['Scope (3)'].values
    assert_equal [10, 7, 4, 12, 0], chart.series_by_label['Scope (1)'].values
  end

  # TODO : need to uncomment once the story-1733] is played.
  # bug 7715
  # def test_should_be_able_to_use_project_in_data_mql
  #   template = ' {{
  #    data-series-chart
  #      cumulative: true
  #      series:
  #      - data: SELECT project, count(*)
  #        label: Projects
  #   }} '
  #
  #   chart = Chart.extract(template, 'data-series', 1)
  #   chart_options = JSON.parse(chart.generate)
  #
  #   assert template_can_be_cached?(template, @project)
  #   assert_equal ['data_series_chart_project'], chart.x_axis_values
  #   assert_equal [@project.cards.count], chart.series_by_label['Projects'].values
  #   assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
  #   assert_equal @data_series_point_chart_options, chart_options['point']
  # end

  # Bug 7669
  def test_can_use_this_card_with_x_labels_conditions
    release1 = @project.cards.find_by_name('release1')
    @iteration1 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration1', release1.id)
    @iteration2 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration2', release1.id)
    @iteration3 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration3', release1.id)
    @iteration4 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration4', release1.id)
    @iteration5 = @project.cards.find_by_name_and_cp_planning_release_card_id('iteration5', release1.id)

    template = %{ {{
      data-series-chart
        chart-type: bar
        cumulative: true
        x-labels-conditions: 'Planning Release' = THIS CARD
        conditions: Type = Story AND 'Planning Release' = release1
        series:
          - label       : Test Cards
            data        : SELECT 'Planning iteration', COUNT(*) ORDER BY 'Planning Iteration'
    }} }

    chart = Chart.extract(template, 'data-series', 1, {:content_provider => release1})
    chart_options = JSON.parse(chart.generate)

    assert_equal [@iteration1, @iteration2, @iteration3, @iteration4, @iteration5].collect(&:number_and_name), chart.x_axis_values
    assert_equal [2, 6, 7, 10, 10], chart.series_by_label['Test Cards'].values
    assert_equal @data_series_tooltip_chart_options, chart_options['tooltip']
    assert_equal @data_series_point_chart_options, chart_options['point']
  end

  # Bug 7669
  def test_can_not_use_this_card_with_x_labels_conditions_on_a_page
    template = %{ {{
      data-series-chart
        chart-type: bar
        cumulative: true
        x-labels-conditions: 'Planning Release' = THIS CARD
        conditions: Type = Story AND 'Planning Release' = release1
        series:
          - label       : Test Cards
            data        : SELECT 'Planning iteration', COUNT(*) ORDER BY 'Planning Iteration'
    }} }

    page = @project.pages.create!(:name => 'foo')
     assert_raise_message(Macro::ProcessingError, /#{'THIS CARD'.bold} is not a supported macro for page./) do
      Chart.extract(template, 'data-series', 1, {:content_provider => page})
    end
  end

  # bug 11702
  def test_should_not_mistake_6_digit_card_numbers_for_colors_in_params
    template = %{
      {{
        data-series-chart
          conditions: type = Story
          chart-height: 500
          cumulative: true
          chart-height: 350
          plot-x-offset: 80
          x-labels-start: "#123456 iteration123456"
          x-labels-property: 'Planning iteration'
          series:
          - data:  SELECT 'Planning iteration', COUNT(*)
            label: Velocity
            color: #00a663
            trend: true
            trend-line-width: 2
      }}
    }
    release1 = @project.cards.find_by_name('release1')
    @project.cards.create!(:name => 'iteration123456', :card_type_name => 'Iteration', :number => 123456)
    chart = Chart.extract(template, 'data-series', 1, {:content_provider => release1})
    assert_equal ['#123456 iteration123456'], chart.labels_for_plot
  end

  def test_x_label_start_and_end_works_with_numeric_properties
    template = %{ {{
       data-series-chart
         x-labels-start : 4

         x-labels-end: 8
         x-labels-step: 1
         series:
           - label       : Double Size
             data        : SELECT 'double size', COUNT(*)
     }} }

    chart = Chart.extract(template, 'data-series', 1)
    assert_equal %w(4 8), chart.labels_for_plot
  end

  def test_chart_callback_should_return_div_with_chart_renderer
      template = %{ {{
       data-series-chart
         x-labels-start : 4

         x-labels-end: 8
         x-labels-step: 1
         series:
           - label       : Double Size
             data        : SELECT 'double size', COUNT(*)
     }} }
      card = @project.cards.first
      chart =DataSeriesChart.new({content_provider: card, view_helper: view_helper}, 'data-series-chart', {'x-labels-start' => '4',
                                                                                                           'x-labels-end' => '8', 'series' => [{'label' => 'Double Size', 'data' => "Select 'double size', COUNT(*)"}]}, template)


      expected_chart_container_and_script = %Q{<div id='dataserieschart-Card-#{card.id}-1' class='data-series-chart medium' style='margin: 0 auto; width: #{chart.chart_width}px; height: #{chart.chart_height}px'></div>
    <script type="text/javascript">
      var dataUrl = '/cards/chart_data?position=1'
      var bindTo = '#dataserieschart-Card-#{card.id}-1'
      ChartRenderer.renderChart('dataSeriesChart', dataUrl, bindTo);
    </script>}

      assert_equal(expected_chart_container_and_script, chart.chart_callback({position: 1, controller: :cards}))
  end

  def test_should_use_c3_renderers_and_generate_data_json
      template = %{ {{
       data-series-chart
         x-labels-start : 4

         x-labels-end: 8
         x-labels-step: 1
         series:
           - label       : Double Size
             data        : SELECT 'double size', COUNT(*)
             trend       : true
     }} }
      chart = extract_chart(template)

      chart_json = JSON.parse(chart.generate)

      assert_equal({'data' =>
                      {'columns' => [['Double Size', 4, 3],['Double Size Trend', 2.6667, 3.6667]],
                       'type' => 'line',
                       'order' => nil,
                       'types' => {},
                       'trends' => ['Double Size Trend'],
                       'colors' => {},
                       'groups' => [[]],
                       'regions' => {'Double Size Trend' =>[{'style' => 'dashed'}]},
                       'labels' => {'format' => {}}},
                    'legend' => {'position' => 'top-right'},
                    'size' => {'width' => 600, 'height' => 450},
                    'axis' =>
                      {'x' =>
                         {'type' => 'category',
                          'label' => {'text' => 'double size', 'position' => 'outer-center'},
                          'categories' => %w(4 8),
                          'tick' => {'rotate' => 45, 'multiline' => false, 'centered' => true}},
                       'y' => {'label' => {'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
                    'tooltip' => {'grouped' => false},
                    'interaction' => {'enabled' => true},
                    'point' => {'show' => false, 'symbols' => {}, 'focus' => {'expand' => {'enabled' => false}}},
                    'region_data' =>
                       {'4' =>
                            {'Double Size' =>
                                 {'cards' =>
                                      [{'name'=>'blab', 'number'=>'22'},
                                       {'name'=>'blab', 'number'=>'21'},
                                       {'name'=>'blab', 'number'=>'15'},
                                       {'name'=>'blab', 'number'=>'12'}],
                                  'count'=>4}},
                        '8'=>
                            {'Double Size'=>
                                 {'cards'=>
                                      [{'name'=>'blab', 'number'=>'19'},
                                       {'name'=>'blab', 'number'=>'18'},
                                       {'name'=>'blab', 'number'=>'14'}],
                                  'count'=>3}}},
                   'region_mql'=>
                       {'conditions'=>
                            {'4'=>{'Double Size'=>"'double size' = 4"},
                             '8'=>{'Double Size'=>"'double size' = 8"}},
                        'project_identifier'=>{'Double Size'=>'data_series_chart_project'}},
                   'grid'=>{'y'=>{'show'=>true}, 'x'=>{'show'=>false}},
                   'title'=>{'text'=>''}}, chart_json)
  end

  def test_default_chart_width_should_be_600_by_450_for_data_series_chart
      template = %{ {{
       data-series-chart
         x-labels-start : 4

         x-labels-end: 8
         x-labels-step: 1
         series:
           - label       : Double Size
             data        : SELECT 'double size', COUNT(*)
     }} }

      chart = extract_chart(template)

      assert_equal(450, chart.chart_height)
      assert_equal(600, chart.chart_width)
  end

  def test_can_specify_chart_width_in_pixels
    template = '{{
      data-series-chart
        chart-width: 525 px
        series:
        - data: SELECT status, count(*)
          label: Projects }}'

    chart = extract_chart(template)
    assert_equal(525, chart.chart_width)
  end

  def test_can_specify_chart_height_in_pixels
    template = '{{
      data-series-chart
        chart-height: 444px
        series:
        - data: SELECT status, count(*)
          label: Projects }}'

    chart = extract_chart(template)
    assert_equal(444, chart.chart_height)
  end

  def test_can_specify_font_angle_in_degrees
    template = '{{
        data-series-chart
          x-label-step: 10 px
          label-font-angle: 90 degrees
          series:
          - data: SELECT status, count(*)
            label: Projects }}'

    chart = extract_chart(template)
    assert_equal(90, chart.label_font_angle)
  end

  def test_should_extract_region_data_when_interaction_is_enabled_for_data_series_chart
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : LabelOne
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate = '2'
            - label       : LabelTwo
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate = '4'
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal({'new' =>
                          {'LabelOne' => {cards: [{'name' => 'first', 'number' => '1'}], count: 1},
                           'LabelTwo' => {cards: [{'name' => 'second', 'number' => '2'}], count: 1}},
                      'done' =>
                          {'LabelOne'=>{:cards=>[], :count=>0},
                           'LabelTwo' =>
                               {cards: [{'name' => 'fourth', 'number' => '4'}, {'name' => 'third', 'number' => '3'}],
                                count: 2}}}, chart.region_data)
      end
  end

  def test_should_extract_region_data_for_cross_project_series_when_interaction_is_enabled_for_data_series_chart
      project_a = with_new_project(prefix: 'Project A') do |project_a|
        project_a.add_member(User.current)
        setup_property_definitions 'CurrentStatus' => ['To do', 'Doing','Done']
        setup_card_type(project_a, 'story', :properties => %w(CurrentStatus))
        create_card_in_future(2.seconds, :name => 'Project A Card 1', :card_type => 'story', :CurrentStatus => 'To do')
        create_card_in_future(4.seconds, :name => 'Project A Card 2', :card_type => 'story', :CurrentStatus => 'Doing')
        create_card_in_future(5.seconds, :name => 'Project A Card 3', :card_type => 'story', :CurrentStatus => 'Doing')
      end

      with_new_project(prefix: 'Project B') do |project_b|
        project_b.add_member(User.current)
        setup_property_definitions 'status' => ['To do', 'Doing']
        setup_card_type(project_b, 'story', :properties => %w(status))
        create_card_in_future(2.seconds, :name => 'Project B Card 1', :card_type => 'story', :status => 'To do')
        create_card_in_future(3.seconds, :name => 'Project B Card 2', :card_type => 'story', :status => 'To do')
        create_card_in_future(4.seconds, :name => 'Project B Card 3', :card_type => 'story', :status => 'Doing')
        create_card_in_future(5.seconds, :name => 'Project B Card 4', :card_type => 'story', :status => 'Doing')

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : 'Project A'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT CurrentStatus, count(*)
              project     : #{project_a.identifier}
            - label       : 'Project B'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*)
      }} })
        chart.extract_region_data
        chart.extract_region_mql
        expected_region_data = {'Doing' =>
                    {'Project A' => {cards: [{'name' => 'Project A Card 3', 'number' => '3'}, {'name' => 'Project A Card 2', 'number' => '2'}], count: 2},
                     'Project B' => {cards: [{'name' => 'Project B Card 4', 'number' => '4'}, {'name' => 'Project B Card 3', 'number' => '3'}], count: 2}},
                'To do' =>
                    {'Project A' => {cards: [{'name' => 'Project A Card 1', 'number' => '1'}], count: 1},
                     'Project B' => {cards: [{'name' => 'Project B Card 2', 'number' => '2'}, {'name' => 'Project B Card 1', 'number' => '1'}], count: 2}},
                'Done' => {'Project A'=>{:cards=>[], :count=>0},'Project B'=>{:cards=>[], :count=>0}}}

        assert_equal expected_region_data, chart.region_data
      end
  end

  def test_should_extract_region_mql_when_interaction_is_enabled_for_data_series_chart
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        assert_equal({'conditions' =>
                          {'new' =>
                               {'Estimate 2' => 'estimate = 2 AND Type = Story AND status = new',
                                'Estimate 4' => 'estimate = 4 AND Type = Story AND status = new'},
                           'done' =>
                               {'Estimate 2' => 'estimate = 2 AND Type = Story AND status = done',
                                'Estimate 4' => 'estimate = 4 AND Type = Story AND status = done'}},
                      'project_identifier' =>
                          {'Estimate 2' => project.identifier, 'Estimate 4' => project.identifier}}, chart.region_mql)
      end
  end

  def test_should_extract_region_mql_for_cross_project_when_interaction_is_enabled_for_data_series_chart
      project_a = with_new_project(prefix: 'Project A') do |project_a|
        project_a.add_member(User.current)
        setup_property_definitions 'CurrentStatus' => ['To Do', 'Doing', 'Done']
        setup_numeric_property_definition 'StoryPoints', [2, 4, 8, 16]
        setup_card_type(project_a, 'story', :properties => %w(CurrentStatus StoryPoints))
        create_card_in_future(2.seconds, :name => 'Project A Estimate 2', :card_type => 'story', :CurrentStatus => 'To Do', :StoryPoints => 2)
        create_card_in_future(4.seconds, :name => 'Project A Estimate 4', :card_type => 'story', :CurrentStatus => 'Doing', :StoryPoints => 2)
        create_card_in_future(4.seconds, :name => 'Project A Estimate 4', :card_type => 'story', :CurrentStatus => 'Done', :StoryPoints => 4)
      end


      with_new_project(prefix: 'Project B') do |project_b|
        project_b.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project_b, 'story', :properties => %w(status estimate))
        create_card_in_future(4.seconds, :name => 'Project B Estimate 4', :card_type => 'story', :status => 'Done', :estimate => 4)
        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : 'Estimate 2 From Project A'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT CurrentStatus, count(*) WHERE StoryPoints > 2
              project     : #{project_a.identifier}
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate = 4
      }} })
        chart.extract_region_data
        chart.extract_region_mql
        assert_equal({'conditions' =>
                          {'To Do' =>
                               {'Estimate 2 From Project A' => "StoryPoints > 2 AND Type = Story AND CurrentStatus = 'To Do'",
                                'Estimate 4' =>"estimate = 4 AND Type = Story AND status = 'To Do'"},
                           'Doing' =>
                               {'Estimate 2 From Project A' => 'StoryPoints > 2 AND Type = Story AND CurrentStatus = Doing',
                                'Estimate 4' => 'estimate = 4 AND Type = Story AND status = Doing'},
                           'Done' =>
                               {'Estimate 2 From Project A' => 'StoryPoints > 2 AND Type = Story AND CurrentStatus = Done',
                                'Estimate 4' => 'estimate = 4 AND Type = Story AND status = Done'}},
                      'project_identifier' =>
                          {'Estimate 2 From Project A' => project_a.identifier, 'Estimate 4' => project_b.identifier}}, chart.region_mql)
      end
  end

  def test_should_add_region_data_and_region_mql_to_generated_chart_data_when_interaction_is_enabled_for_data_series_chart
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })

        expected_chart_data_with_region_data = {'data' =>
                                                  {'columns' => [['Estimate 2', 1, 0], ['Estimate 4', 1, 2]],
                                                   'type' => 'line',
                                                   'order' => nil,
                                                   'types' => {},
                                                   'trends' => [],
                                                   'colors' => {'Estimate 2' => 'yellow', 'Estimate 4' => 'green'},
                                                   'groups' => [[]],
                                                   'regions' => {},
                                                   'labels' => {'format' => {}}},
                                                'legend' => {'position' => 'top-right'},
                                                'size' => {'width' => 600, 'height' => 450},
                                                'axis' =>
                                                  {'x' =>
                                                     {'type' => 'category',
                                                      'label' => {'text' => 'status', 'position' => 'outer-center'},
                                                      'categories' => %w(new done),
                                                      'tick' => {'rotate' => 45, 'multiline' => false, 'centered' => true}},
                                                   'y' => {'label' => {'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
                                                'tooltip' => {'grouped' => false},
                                                'interaction' => {'enabled' => true},
                                                'point' => {'show' => false, 'symbols' => {}, 'focus' => {'expand' => {'enabled' => false}}},
                                                'region_data' =>
                                                  {'new' =>
                                                     {'Estimate 2' => {'cards' => [{'name' => 'first', 'number' => '1'}], 'count' => 1},
                                                      'Estimate 4' => {'cards' => [{'name' => 'second', 'number' => '2'}], 'count' => 1}},
                                                   'done' =>
                                                     {'Estimate 2' => {'cards'=>[], 'count'=>0},
                                                      'Estimate 4' => {'cards' => [{'name' => 'fourth', 'number' => '4'}, {'name' => 'third', 'number' => '3'}], 'count' => 2}}},
                                                'region_mql' =>
                                                  {'conditions' =>
                                                     {'new' =>
                                                        {'Estimate 2' => 'estimate = 2 AND Type = Story AND status = new',
                                                         'Estimate 4' => 'estimate = 4 AND Type = Story AND status = new'},
                                                      'done' =>
                                                        {'Estimate 2' => 'estimate = 2 AND Type = Story AND status = done',
                                                         'Estimate 4' => 'estimate = 4 AND Type = Story AND status = done'}},
                                                   'project_identifier' =>
                                                     {'Estimate 2' => project.identifier, 'Estimate 4' => project.identifier}},
                                                'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}, 'title' => { 'text' => ''}}

        chart_json = JSON.parse(chart.generate)

        assert_equal(expected_chart_data_with_region_data, chart_json)
      end
  end

  def test_do_generate_should_set_show_guide_lines_as_true_for_data_series_when_stated
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          show-guide-lines : true
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })

        guide_line_options = JSON.parse(chart.generate)['grid']

        assert_equal({'y' =>{'show' =>true}, 'x' =>{'show' =>false}}, guide_line_options)
      end
  end

  def test_do_generate_should_set_title
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          show-guide-lines : true
          title : Chart title
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })

        chart_json = JSON.parse(chart.generate)

        assert_equal({'text' => 'Chart title'}, chart_json['title'])
    end
  end

  def test_do_generate_should_set_chart_size
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          show-guide-lines : true
          chart-size : Large
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })

        chart_json = JSON.parse(chart.generate)

        assert_equal({'width' =>1200, 'height' =>900}, chart_json['size'])
    end
  end

  def test_do_generate_should_set_legend_position
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          show-guide-lines : true
          legend-position : bottom
          series:
            - label       : 'Estimate 2'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*) WHERE estimate=2
            - label       : 'Estimate 4'
              color       : Green
              combine     : overlay-bottom
              data        : SELECT status, count(*) WHERE estimate=4
      }} })

        chart_json = JSON.parse(chart.generate)

        assert_equal({'position' => 'bottom'}, chart_json['legend'])
        assert JSON.parse(chart.generate)['interaction']['enabled']
    end
  end

  test 'should_generate_json_response_with_negative_x_axis_values' do
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new done)
        setup_numeric_property_definition 'estimate', [-2, -4.20, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => -2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'new', :estimate => -4.20)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :estimate => -4.20)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          show-guide-lines : true
          series:
            - label       : 'Series'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT estimate, count(*)
      }} })

        chart_json = JSON.parse(chart.generate)

        assert_equal({'data' =>
                        {'columns' =>[['Series', 2, 1, 0]],
                         'type' => 'line',
                         'order' => nil,
                         'types' =>{},
                         'trends' => [],
                         'colors' =>{'Series' => 'yellow'},
                         'groups' =>[[]],
                         'regions' =>{},
                         'labels' =>{'format' =>{}}},
                      'legend' =>{'position' => 'top-right'},
                      'size' =>{'width' =>600, 'height' =>450},
                      'axis' =>
                        {'x' =>
                           {'type' => 'category',
                            'label' =>{'text' => 'estimate', 'position' => 'outer-center'},
                            'categories' => %w(-4.2 -2 16),
                            'tick' =>{'rotate' =>45, 'multiline' =>false, 'centered' =>true}},
                         'y' =>{'label' =>{'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
                      'tooltip' =>{'grouped' =>false},
                      'interaction' =>{'enabled' =>true},
                      'point' =>{'show' =>false, 'symbols' =>{}, 'focus' => {'expand' => {'enabled' => false}}},
                      'region_data' =>
                        {'-4.2' => {'Series' => {'cards' => [{'name' => 'third', 'number' => '3'}, {'name' => 'second', 'number' => '2'}], 'count' =>2}},
                         '-2' => {'Series' =>{'cards' =>[{'name' => 'first', 'number' => '1'}], 'count' =>1}},
                         '16'=>{'Series'=>{'cards'=>[], 'count'=>0}}},
                      'region_mql' =>
                        {'conditions' =>
                           {'-4.2' =>{'Series' =>"Type = Story AND estimate = '-4.2'"},
                            '-2' =>{'Series' =>"Type = Story AND estimate = '-2'"},
                            '16' =>{'Series' => 'Type = Story AND estimate = 16'}},
                         'project_identifier' => {'Series' => project.name}},
                         'title' => { 'text' => ''},
                         'grid' =>{'y' =>{'show' =>true}, 'x' =>{'show' =>false}}}, chart_json)
    end
  end

  test 'should_generate_region_mql_and_region_data_for_x_label_tree' do
    ##################################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2
    #                   |                 |
    #            ---iteration1----    iteration2
    #           |                |
    #       story1            story2
    #
    ##################################################################################
    with_three_level_tree_project do |project|
    tree_configuration = project.tree_configurations.first
    type_release = project.card_types.find_by_name('release')
    iteration_1 = project.cards.find_by_name('iteration1')
    tree_configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)
    type_story = project.find_card_type('Story')
    type_story.card_defaults.update_properties('Planning iteration' => iteration_1.id)

    chart = extract_chart(%{ {{
      data-series-chart
        conditions  : type = story
        cumulative  : false
        x-labels-tree: "three level tree"
        show-guide-lines : true
        series:
          - label       : 'series1'
            color       : Yellow
            combine     : overlay-top
            data        : SELECT "Planning iteration", count(*)
          - label       : 'series2'
            color       : Green
            combine     : overlay-bottom
            data        : SELECT "Planning iteration", count(*)
    }} })
    generate = chart.generate
    expected_chart_data = {'data' =>
                {'columns' => [['series1', 2, 0], ['series2', 2, 0]],
                 'type' => 'line',
                 'order' => nil,
                 'types' => {},
                 'trends' => [],
                 'colors' => {'series1' => 'yellow', 'series2' => 'green'},
                 'groups' => [[]],
                 'regions' => {},
                 'labels' => {'format' => {}}},
            'legend' => {'position' => 'top-right'},
            'size' => {'width' => 600, 'height' => 450},
            'axis' =>
                {'x' =>
                     {'type' => 'category',
                      'label' => {'text' => 'Planning iteration', 'position' => 'outer-center'},
                      'categories' => ['release1 > iteration1', 'release1 > iteration2'],
                      'tick' => {'rotate' => 45, 'multiline' => false, 'centered' => true}},
                 'y' => {'label' => {'text' => 'Number of cards', 'position' => 'outer-middle'}, 'padding' => {'top' => 25}}},
            'tooltip' => {'grouped' => false},
            'interaction' => {'enabled' => true},
            'point' => {'show' => false, 'symbols' => {}, 'focus' => {'expand' => {'enabled' => false}}},
            'region_data' => {'release1 > iteration1' =>
                                  {'series1' =>
                                       {'cards' =>
                                            [{'name' => 'story2', 'number' => '5'}, {'name' => 'story1', 'number' => '4'}],
                                        'count' => 2},
                                   'series2' =>
                                       {'cards' =>
                                            [{'name' => 'story2', 'number' => '5'}, {'name' => 'story1', 'number' => '4'}],
                                        'count' => 2}},
                              'release1 > iteration2' =>
                                  {'series1' => {'cards' => [], 'count' => 0},
                                   'series2' => {'cards' => [], 'count' => 0}}},
            'region_mql' => {'conditions' =>
                                 {'release1 > iteration1' =>
                                      {'series1' => "Type = story AND 'Planning iteration' = NUMBER 2",
                                       'series2' => "Type = story AND 'Planning iteration' = NUMBER 2"},
                                  'release1 > iteration2' =>
                                      {'series1' => "Type = story AND 'Planning iteration' = NUMBER 3",
                                       'series2' => "Type = story AND 'Planning iteration' = NUMBER 3"}},
                             'project_identifier' =>
                                 {'series1' => 'three_level_tree_project',
                                  'series2' => 'three_level_tree_project'}},
            'grid' => {'y' => {'show' => true}, 'x' => {'show' => false}}, 'title' => {'text' => ''}}

      chart_json = JSON.parse(generate)
      assert_equal expected_chart_data, chart_json
    end
  end

  def test_should_add_region_data_and_region_mql_to_generated_chart_when_interaction_is_enabled_and_x_label_start_end_is_given
      with_new_project do |project|
        project.add_member(User.current)
        setup_property_definitions 'status' => %w(new analysis dev done)
        setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
        setup_card_type(project, 'story', :properties => %w(status estimate))
        create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
        create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'analysis', :estimate => 4)
        create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'dev', :estimate => 4)
        create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'dev', :estimate => 4)
        create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'done', :estimate => 4)

        chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          x-label-start: analysis
          x-label-end: done
          series:
            - label       : 'Series 1'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*)
      }} })
        chart.extract_region_data
        chart.extract_region_mql

        expected_chart_data_with_region_data = {'done' =>{'Series 1' => {:cards => [{'name' => 'fifth', 'number' => '5'}], :count => 1}},
                                                'dev' =>{'Series 1' => {:cards => [{'name' => 'fourth', 'number' => '4'},{'name' => 'third', 'number' => '3'}], :count => 2}},
                                                'analysis' =>{'Series 1' => {:cards => [{'name' => 'second', 'number' => '2'}], :count => 1}},
                                                'new' =>{'Series 1' =>{cards: [{'name' => 'first', 'number' => '1'}], :count=>1}}}
        expected_chart_data_with_region_mql = {'conditions' =>
                                                          {'new' =>{'Series 1' => 'Type = Story AND status = new'},
                                                          'analysis' =>
                                                            {'Series 1' => 'Type = Story AND status = analysis'},
                                                          'dev' =>
                                                              {'Series 1' => 'Type = Story AND status = dev'},
                                                          'done' =>
                                                               {'Series 1' => 'Type = Story AND status = done'}},
                                              'project_identifier' => {'Series 1' => project.identifier}}

        assert_equal expected_chart_data_with_region_mql, chart.region_mql
        assert_equal expected_chart_data_with_region_data, chart.region_data
        assert JSON.parse(chart.generate)['interaction']['enabled']
      end
  end

  def test_should_add_data_symbol_for_area_type_series
    with_new_project do |project|
      project.add_member(User.current)
      setup_property_definitions 'status' => %w(new analysis dev done)
      setup_card_type(project, 'story', :properties => %w(status))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new')

      chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          x-label-start: analysis
          x-label-end: done
          series:
            - label       : 'Series 1'
              color       : Yellow
              combine     : overlay-top
              type        : Area
              data-point-symbol: Diamond
              data        : SELECT status, count(*)
      }} })

      expected_series_type = {'Series 1' => 'area'}
      expected_data_point_symbol = {'Series 1' => 'diamond'}
      chart_json = JSON.parse(chart.generate)

      assert_equal expected_series_type , chart_json['data']['types']
      assert_equal expected_data_point_symbol , chart_json['point']['symbols']
      assert chart_json['interaction']['enabled']
    end
  end

  def test_should_not_raise_error_when_x_labels_property_is_hidden_property
    with_new_project do |project|
      login_as_admin
      setup_allow_any_number_property_definition('hidden_property').update_attribute(:hidden, true)
      project.reload
      this_card = create_card!(:name => 'story3', :hidden_property => 1)
      template = ' {{
        data-series-chart
          x-labels-property: hidden_property
          series:
            - label       : Scope
              data        : SELECT name, COUNT(*)
      }} '
      assert_nothing_raised('Should allow hidden property as x labels property') do
        Chart.extract(template, 'data-series', 1, { :content_provider => this_card })
      end
    end
  end

  def test_should_add_region_data_for_x_labels_having_no_values
    with_new_project do |project|
      project.add_member(User.current)
      setup_property_definitions 'status' => %w(new analysis dev done)
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => %w(status estimate))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'analysis', :estimate => 4)

      chart = extract_chart(%{ {{
        data-series-chart
          conditions  : type = Story
          cumulative  : false
          x-label-start: analysis
          x-label-end: done
          series:
            - label       : 'Series 1'
              color       : Yellow
              combine     : overlay-top
              data        : SELECT status, count(*)
      }} })
      chart.extract_region_data
      chart.extract_region_mql
      expected_chart_data_with_region_data = {'done' => {'Series 1' => {:cards => [], :count => 0}},
                                              'dev' => {'Series 1' => {:cards => [], :count => 0}},
                                              'analysis' => {'Series 1' => {:cards => [{'name' => 'second', 'number' => '2'}], :count => 1}},
                                              'new' => {'Series 1' => {cards: [{'name' => 'first', 'number' => '1'}], :count => 1}}}

      assert_equal expected_chart_data_with_region_data, chart.region_data
    end
  end

  def test_should_set_default_y_title_As_NumberOfCards_when_not_given
    template = '{{
    data-series-chart
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    chart = extract_chart(template)

    chart_json = JSON.parse(chart.generate)
    y_label= {'padding' =>{'top' =>25},
              'label' =>{'text' => 'Number of cards', 'position' => 'outer-middle'}}

    assert_equal(y_label, chart_json['axis']['y'])

  end

  def test_should_set_y_title_when_given
    template = '{{
    data-series-chart
      y-title: some-y-title
      series:
      - data: select status, count(*)
        label: Projects
        color: #FF0000
        combine: overlay-bottom }}'

    chart = extract_chart(template)

    assert_equal('some-y-title', chart.y_title)
  end

  def test_should_generate_region_data_and_region_mql_for_burn_down_chart
    with_new_project do |project|
      project.add_member(User.current)
      setup_property_definitions 'status' => %w(new analysis dev done)
      setup_date_property_definition ('complete')
      setup_card_type(project, 'story', :properties => %w(status complete))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :complete => '2017-11-09')
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'analysis')
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'dev')
      create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'done', :complete => '2017-11-10')
      create_card_in_future(7.seconds, :name => 'sixth', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(8.seconds, :name => 'seventh', :card_type => 'story', :status => 'done', :complete => '2017-11-10')
      create_card_in_future(9.seconds, :name => 'eighth', :card_type => 'story', :status => 'done', :complete => '2017-11-09')
      create_card_in_future(10.seconds, :name => 'ninth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(11.seconds, :name => 'tenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(12.seconds, :name => 'eleventh', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(13.seconds, :name => 'twelfth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(14.seconds, :name => 'thirteenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(15.seconds, :name => 'fourteenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')

      chart = extract_chart(%{ {{
          data-series-chart
            conditions  : type = Story
            cumulative  : true
            x-labels-property: complete
            series:
              - label       : 'Series 1'
                color       : Yellow
                combine     : overlay-top
                data        : SELECT "complete", COUNT(*) WHERE "Type" = "Story" AND "Status" = "Done"
                down-from   : SELECT COUNT(*)
        }} })
      chart.extract_region_data
      chart.extract_region_mql

      expected_region_mql = {'conditions' =>
                                 {'Start' => {'Series 1' => 'Type = Story'},
                                  '09 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete = '09 Nov 2017')"},
                                  '10 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '10 Nov 2017')"},
                                  '11 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '11 Nov 2017')"},
                                  '12 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '12 Nov 2017')"}},
                             'project_identifier' => {'Series 1' => project.identifier}}

      expected_region_data = {'Start' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'eighth', 'number' => '8'},
                                             {'name' => 'seventh', 'number' => '7'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fifth', 'number' => '5'}],
                                        :count => 14}},
                              '09 Nov 2017' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'seventh', 'number' => '7'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fifth', 'number' => '5'},
                                             {'name' => 'fourth', 'number' => '4'}],
                                        :count => 13}},
                              '10 Nov 2017' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fourth', 'number' => '4'},
                                             {'name' => 'third', 'number' => '3'},
                                             {'name' => 'second', 'number' => '2'}],
                                        :count => 11}},
                              '11 Nov 2017' =>
                                  {'Series 1' => {:cards =>
                                                      [{'name' => 'fourteenth', 'number' => '14'},
                                                       {'name' => 'thirteenth', 'number' => '13'},
                                                       {'name' => 'twelfth', 'number' => '12'},
                                                       {'name' => 'tenth', 'number' => '10'},
                                                       {'name' => 'ninth', 'number' => '9'},
                                                       {'name' => 'fourth', 'number' => '4'},
                                                       {'name' => 'second', 'number' => '2'},
                                                       {'name' => 'first', 'number' => '1'}],
                                                  :count => 8}},
                              '12 Nov 2017' =>
                                  {'Series 1' => {:cards =>
                                                      [{'name' => 'fourth', 'number' => '4'},
                                                       {'name' => 'second', 'number' => '2'},
                                                       {'name' => 'first', 'number' => '1'}],
                                                  :count => 3}}}

      assert_equal expected_region_mql, chart.region_mql
      assert_equal expected_region_data, chart.region_data
    end
  end

  def test_should_generate_region_data_and_region_mql_for_chart_with_custom_start_label
    with_new_project do |project|
      project.add_member(User.current)
      setup_property_definitions 'status' => %w(new analysis dev done)
      setup_date_property_definition ('complete')
      setup_card_type(project, 'story', :properties => %w(status complete))
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story', :status => 'new', :complete => '2017-11-09')
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story', :status => 'analysis')
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story', :status => 'dev')
      create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story', :status => 'done', :complete => '2017-11-10')
      create_card_in_future(7.seconds, :name => 'sixth', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(8.seconds, :name => 'seventh', :card_type => 'story', :status => 'done', :complete => '2017-11-10')
      create_card_in_future(9.seconds, :name => 'eighth', :card_type => 'story', :status => 'done', :complete => '2017-11-09')
      create_card_in_future(10.seconds, :name => 'ninth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(11.seconds, :name => 'tenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(12.seconds, :name => 'eleventh', :card_type => 'story', :status => 'done', :complete => '2017-11-11')
      create_card_in_future(13.seconds, :name => 'twelfth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(14.seconds, :name => 'thirteenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')
      create_card_in_future(15.seconds, :name => 'fourteenth', :card_type => 'story', :status => 'done', :complete => '2017-11-12')

      chart = extract_chart(%{ {{
          data-series-chart
            conditions  : type = Story
            cumulative  : true
            x-labels-property: complete
            start-label: 'Some Random Start Label'
            series:
              - label       : 'Series 1'
                color       : Yellow
                combine     : overlay-top
                data        : SELECT "complete", COUNT(*) WHERE "Type" = "Story" AND "Status" = "Done"
                down-from   : SELECT COUNT(*)
        }} })
      chart.extract_region_data
      chart.extract_region_mql

      expected_region_mql = {'conditions' =>
                                 {'Some Random Start Label' => {'Series 1' => 'Type = Story'},
                                  '09 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete = '09 Nov 2017')"},
                                  '10 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '10 Nov 2017')"},
                                  '11 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '11 Nov 2017')"},
                                  '12 Nov 2017' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND status = Done AND Type = Story AND complete >= '09 Nov 2017' AND complete <= '12 Nov 2017')"}},
                             'project_identifier' => {'Series 1' => project.identifier}}

      expected_region_data = {'Some Random Start Label' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'eighth', 'number' => '8'},
                                             {'name' => 'seventh', 'number' => '7'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fifth', 'number' => '5'}],
                                        :count => 14}},
                              '09 Nov 2017' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'seventh', 'number' => '7'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fifth', 'number' => '5'},
                                             {'name' => 'fourth', 'number' => '4'}],
                                        :count => 13}},
                              '10 Nov 2017' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'fourteenth', 'number' => '14'},
                                             {'name' => 'thirteenth', 'number' => '13'},
                                             {'name' => 'twelfth', 'number' => '12'},
                                             {'name' => 'eleventh', 'number' => '11'},
                                             {'name' => 'tenth', 'number' => '10'},
                                             {'name' => 'ninth', 'number' => '9'},
                                             {'name' => 'sixth', 'number' => '6'},
                                             {'name' => 'fourth', 'number' => '4'},
                                             {'name' => 'third', 'number' => '3'},
                                             {'name' => 'second', 'number' => '2'}],
                                        :count => 11}},
                              '11 Nov 2017' =>
                                  {'Series 1' => {:cards =>
                                                      [{'name' => 'fourteenth', 'number' => '14'},
                                                       {'name' => 'thirteenth', 'number' => '13'},
                                                       {'name' => 'twelfth', 'number' => '12'},
                                                       {'name' => 'tenth', 'number' => '10'},
                                                       {'name' => 'ninth', 'number' => '9'},
                                                       {'name' => 'fourth', 'number' => '4'},
                                                       {'name' => 'second', 'number' => '2'},
                                                       {'name' => 'first', 'number' => '1'}],
                                                  :count => 8}},
                              '12 Nov 2017' =>
                                  {'Series 1' => {:cards =>
                                                      [{'name' => 'fourth', 'number' => '4'},
                                                       {'name' => 'second', 'number' => '2'},
                                                       {'name' => 'first', 'number' => '1'}],
                                                  :count => 3}}}

      assert_equal expected_region_mql, chart.region_mql
      assert_equal expected_region_data, chart.region_data
    end
  end

  def test_should_generate_region_mql_for_burndown_across_sprints
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('Story')
      iteration2 = project.cards.find_by_name('iteration2')
      tree_configuration.add_child(create_card!(:name => 'iteration3', :card_type => type_iteration))
      iteration3 = project.cards.find_by_name('iteration3')
      story3 = tree_configuration.add_child(create_card!(:name => 'Story3', :card_type => type_story))
      story4 = tree_configuration.add_child(create_card!(:name => 'Story4', :card_type => type_story))
      story3.update_properties('Planning Iteration' => iteration2.id)
      story4.update_properties('Planning Iteration' => iteration3.id)
      story3.save!
      story4.save!

      template = %{ {{
       data-series-chart
          conditions: type = Story
          cumulative: true
          series:
          - label: Series 1
            color: black
            type: line
            data: SELECT 'Planning iteration',count(*)
            trend: true
            trend-line-width: 2
            down-from: Select count(*)
      }} }

      chart = extract_chart(template)
      chart.extract_region_data
      chart.extract_region_mql
      expected_region_mql = {'conditions' =>
                                 {'Start' => {'Series 1' => 'Type = Story'},
                                  '#2 iteration1' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND 'Planning iteration' = NUMBER 2)"},
                                  '#3 iteration2' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND 'Planning iteration' NUMBER IN (2, 3))"},
                                  '#6 iteration3' =>
                                      {'Series 1' =>
                                           "(Type = Story) AND NOT NUMBER IN (SELECT number where Type = Story AND 'Planning iteration' NUMBER IN (2, 3, 6))"}},
                             'project_identifier' => {'Series 1' => project.identifier}}

      expected_region_data = {'Start' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'Story4', 'number' => '8'},
                                             {'name' => 'Story3', 'number' => '7'},
                                             {'name' => 'story2', 'number' => '5'},
                                             {'name' => 'story1', 'number' => '4'}],
                                        :count => 4}},
                              '#2 iteration1' =>
                                  {'Series 1' =>
                                       {:cards =>
                                            [{'name' => 'Story4', 'number' => '8'}, {'name' => 'Story3', 'number' => '7'}],
                                        :count => 2}},
                              '#3 iteration2' =>
                                  {'Series 1' => {:cards => [{'name' => 'Story4', 'number' => '8'}], :count => 1}},
                              '#6 iteration3' => {'Series 1' => {:cards => [], :count => 0}}}
      assert_equal expected_region_mql, chart.region_mql
      assert_equal expected_region_data, chart.region_data
    end
  end

  def test_interactivity_should_set_to_true_for_burn_down
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('Story')
      iteration2 = project.cards.find_by_name('iteration2')
      tree_configuration.add_child(create_card!(:name => 'iteration3', :card_type => type_iteration))
      iteration3 = project.cards.find_by_name('iteration3')
      story3 = tree_configuration.add_child(create_card!(:name => 'Story3', :card_type => type_story))
      story4 = tree_configuration.add_child(create_card!(:name => 'Story4', :card_type => type_story))
      story3.update_properties('Planning Iteration' => iteration2.id)
      story4.update_properties('Planning Iteration' => iteration3.id)
      story3.save!
      story4.save!

      template = %{ {{
       data-series-chart
          conditions: type = Story
          cumulative: true
          series:
          - label: Series 1
            color: black
            type: line
            data: SELECT 'Planning iteration',count(*)
            trend: true
            trend-line-width: 2
            down-from: Select count(*)
      }} }

      chart = extract_chart(template)
      assert JSON.parse(chart.generate)['interaction']['enabled']
    end
  end


  def extract_chart(template, options={})
    Chart.extract(template, 'data-series', 1, options)
  end

  def expected_chart_container_id_attr(content_provider = 'RenderableTester', content_provider_id = 'test_id', is_preview = false)
    "id=\"dataserieschart-#{content_provider}-#{content_provider_id}-1#{'-preview' if is_preview}\""
  end
end
