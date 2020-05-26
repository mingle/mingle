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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class ForecastableTest < ActiveSupport::TestCase
  
  class TestForecastable
    include Charts::Forecastable

    def render(renderer)
      render_forecast(renderer)
    end
    def log(message)
      puts "[LOG] " + message    
    end
  end
  
  def test_should_forecast_for_scope
    scope_multiplier = 1.5
    scope_series_values = [3, 3, 5, 5, 5, 5]
    
    forecastable = TestForecastable.new

    time_so_far = scope_series_values.size - 1
    forecasted_additional_time, end_scope = velocity.forecast(scope_series_values, scope_multiplier)
    forecasted_time = time_so_far + forecasted_additional_time
    
    assert_equal [forecasted_time, end_scope], forecastable.forecast(scope_multiplier, velocity, scope_series_values)
  end
  
  def velocity
    Velocity.new([0, 0, 1, 1, 2, 2])
  end
  
  def test_should_forecast_for_scope_series
    forecastable = TestForecastable.new
    scope_series = "A scope series"
    completion_series = "A completion series"
    assert forecastable.forecast?(scope_series, completion_series, velocity)
  end
  
  def test_should_not_forecast_when_velocity_is_invalid
    forecastable = TestForecastable.new
    scope_series = "A scope series"
    completion_series = "A completion series"
    assert_false forecastable.forecast?(scope_series, completion_series, Velocity.new([0])) # when NAN
    assert_false forecastable.forecast?(scope_series, completion_series, Velocity.new([1, 1])) # when zero
    assert_false forecastable.forecast?(scope_series, completion_series, Velocity.new([2, 1])) # when negative
  end

  def test_should_render_forecast_for_c3_chart_with_forecasts_guide_line
    renderer = mock('renderer')
    with_new_project(date_format: '%Y/%m/%d') do |project|
      x_axis_start_date = Date.parse('11/05/2017')
      x_axis_end_date = Date.parse('15/05/2017')
      x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
      test_forecastable = TestForecastable.new
      test_forecastable.stubs(:project).returns(project)
      scope_series = [2, 6, 7, 9, 13]
      test_forecastable.stubs(:scope_series_values).returns(scope_series)
      completion_series = [2, 4, 6, 7, 9]
      test_forecastable.stubs(:completion_series_values).returns(completion_series)
      test_forecastable.stubs(:scope_series).returns('Scope series')
      test_forecastable.stubs(:completion_series).returns('Completion series')
      test_forecastable.stubs(:velocity).returns(velocity)
      test_forecastable.stubs(:x_axis_values).returns(x_axis_values)
      test_forecastable.stubs(:color_for_series).returns(Chart::HTML_COLORS["Red"])
      test_forecastable.expects(:last_coordinate_of_series).with('Scope series').returns([scope_series.size - 1 ,scope_series.last])
      test_forecastable.expects(:last_coordinate_of_series).with('Completion series').returns([completion_series.size - 1 ,completion_series.last])
      test_forecastable.instance_variable_set(:@x_axis_start_date, x_axis_start_date)
      test_forecastable.instance_variable_set(:@x_axis_end_date, x_axis_end_date)

      p10_forecast_date = '2017/06/08'
      p50_forecast_date = '2017/06/20'
      p90_forecast_date = '2017/07/14'
      forecast_parameters = [[p10_forecast_date, 13, 'Forecast For No Scope Change', 'square', Chart::HTML_COLORS["Red"]],
                             [p50_forecast_date, 18.5, 'Forecast For 50% Increase in Remaining Scope', 'triangle-up', Chart::HTML_COLORS["Red"]],
                             [p90_forecast_date, 29.5, 'Forecast For 150% Increase in Remaining Scope', 'circle', Chart::HTML_COLORS["Red"]]]

      forecast_parameters.each do |forecast_parameter|
        renderer.expects(:set_data_labels).with(forecast_parameter[2], forecast_parameter[0])
        renderer.expects(:set_data_symbol).with(forecast_parameter[3])
        renderer.expects(:set_x_values).with([Date.parse(forecast_parameter[0]).to_epoch_milliseconds], '_$xFor ' + forecast_parameter[2], forecast_parameter[2])
        renderer.expects(:add_line).with([forecast_parameter[1]], forecast_parameter[4], forecast_parameter[2]).returns(renderer)
        renderer.expects(:set_data_class).with(forecast_parameter[2],'translate-label-by--30-0')
      end

      expects_series_added(renderer, [9, 29.5], [x_axis_end_date, Date.parse(p90_forecast_date)].map(&:to_epoch_milliseconds), 'Linear (Completion series)',true)
      expects_series_added(renderer, [13, 13], [x_axis_end_date, Date.parse(p10_forecast_date)].map(&:to_epoch_milliseconds), 'Unchanged Scope',  true)
      expects_hidden_series_added(renderer, x_axis_end_date, x_axis_end_date + 4.days)

      renderer.expects(:set_forecasts_guide_line).with(18.5, Chart::HTML_COLORS["Red"])
      renderer.expects(:set_forecasts_guide_line).with(29.5, Chart::HTML_COLORS["Red"])
      test_forecastable.render(renderer)
    end
  end
    
  def test_should_render_fix_date_chart_with_gap_when_target_release_date_is_within_linear_forecast_date
    renderer = mock('renderer')
    with_new_project(date_format: '%Y/%m/%d') do |project|
      x_axis_start_date = Date.parse('11/05/2017')
      x_axis_end_date = Date.parse('15/05/2017')
      x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
      target_release_date = Date.parse('19/05/2017')
      test_forecastable = stub_test_forecastable(project, x_axis_end_date, x_axis_start_date, x_axis_values)
      test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

      renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/05/19')

      fix_date_projection_data = [9.664935064935065, 13.0]
      renderer.expects(:add_line).with(fix_date_projection_data, 255, 'Difference between total scope and completed scope', true).returns(renderer)

      expects_gap_data_label_added(renderer, fix_date_projection_data,target_release_date)
      renderer.expects(:set_x_values).with([target_release_date.to_epoch_milliseconds, target_release_date.to_epoch_milliseconds],'_$xFor Difference between total scope and completed scope','Difference between total scope and completed scope')
      renderer.expects(:set_data_class).with('Difference between total scope and completed scope','thick-line-series')
      renderer.expects(:hide_tooltip).with('Difference between total scope and completed scope')

      expects_series_added(renderer, [9, 9.664935064935065], [x_axis_end_date, target_release_date].map(&:to_epoch_milliseconds), 'Linear (Completion series)', true)
      expects_series_added(renderer, [13, 13], [x_axis_end_date, target_release_date].map(&:to_epoch_milliseconds), 'Unchanged Scope',  true)
      expects_hidden_series_added(renderer, x_axis_end_date, x_axis_end_date+ 4.days)

      test_forecastable.render(renderer)
    end
  end

  def test_should_render_fix_date_chart_without_gap_when_target_release_date_greater_than_forecast_completion_date
    renderer = mock('renderer')
    with_new_project(date_format: '%Y/%m/%d') do |project|
      x_axis_start_date = Date.parse('11/05/2017')
      x_axis_end_date = Date.parse('15/05/2017')
      x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
      target_release_date = Date.parse('19/06/2017')
      test_forecastable = stub_test_forecastable(project, x_axis_end_date, x_axis_start_date, x_axis_values)
      test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

      forecast_parameter = ['2017/06/08', 13, 'Forecast For No Scope Change', 'square',Chart::HTML_COLORS["Red"]]

      renderer.expects(:set_data_labels).with(forecast_parameter[2], forecast_parameter[0])
      renderer.expects(:set_data_symbol).with(forecast_parameter[3])
      renderer.expects(:set_x_values).with([Date.parse(forecast_parameter[0]).to_epoch_milliseconds], "_$xFor #{forecast_parameter[2]}", forecast_parameter[2])
      renderer.expects(:add_line).with([forecast_parameter[1]], forecast_parameter[4], forecast_parameter[2]).returns(renderer)
      renderer.expects(:set_data_class).with(forecast_parameter[2],'translate-label-by--30-0')

      renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/06/19')
      expects_series_added(renderer, [9, 13], [x_axis_end_date, Date.parse('2017/06/08')].map(&:to_epoch_milliseconds), 'Linear (Completion series)', true)
      expects_series_added(renderer, [13, 13], [x_axis_end_date, Date.parse('2017/06/08')].map(&:to_epoch_milliseconds), 'Unchanged Scope',  true)
      expects_hidden_series_added(renderer, x_axis_end_date, x_axis_end_date + 4.days)

      test_forecastable.render(renderer)
    end
  end

  def test_should_render_forecast_chart_without_gap_when_end_date_greater_than_today
    renderer = mock('renderer')
    date_today = Date.parse('12/05/2017')
    Timecop.freeze(date_today) do
      with_new_project(date_format: '%Y/%m/%d') do |project|
        x_axis_start_date = Date.parse('11/05/2017')
        x_axis_end_date = Date.parse('15/05/2017')
        x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
        target_release_date = Date.parse('19/06/2017')
        test_forecastable = stub_test_forecastable(project, x_axis_end_date, x_axis_start_date, x_axis_values)
        test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

        forecast_parameter = ['2017/06/08', 13, 'Forecast For No Scope Change', 'square',Chart::HTML_COLORS["Red"]]

        renderer.expects(:set_data_labels).with(forecast_parameter[2], forecast_parameter[0])
        renderer.expects(:set_data_symbol).with(forecast_parameter[3])
        renderer.expects(:set_x_values).with([Date.parse(forecast_parameter[0]).to_epoch_milliseconds], "_$xFor #{forecast_parameter[2]}", forecast_parameter[2])
        renderer.expects(:add_line).with([forecast_parameter[1]], forecast_parameter[4], forecast_parameter[2]).returns(renderer)
        renderer.expects(:set_data_class).with(forecast_parameter[2],'translate-label-by--30-0')

        renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/06/19')
        expects_series_added(renderer, [9, 13], [x_axis_end_date, Date.parse('2017/06/08')].map(&:to_epoch_milliseconds), 'Linear (Completion series)', true)
        expects_series_added(renderer, [13, 13], [x_axis_end_date, Date.parse('2017/06/08')].map(&:to_epoch_milliseconds), 'Unchanged Scope',  true)
        expects_hidden_series_added(renderer, date_today, x_axis_end_date + 4.days)

        test_forecastable.render(renderer)
      end
    end
  end

  def test_should_render_forecast_chart_without_gap_when_end_date_greater_than_today_and_target_release_date
    renderer = mock('renderer')
    date_today = Date.parse('12/05/2017')
    Timecop.freeze(date_today) do
      with_new_project(date_format: '%Y/%m/%d') do |project|
        x_axis_start_date = Date.parse('11/05/2017')
        x_axis_end_date = Date.parse('15/05/2017')
        x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
        target_release_date = Date.parse('13/05/2017')
        test_forecastable = TestForecastable.new
        test_forecastable.stubs(:project).returns(project)
        scope_series = [2, 6]
        completion_series = [2, 4]
        test_forecastable.stubs(:scope_series_values).returns(scope_series)
        test_forecastable.stubs(:completion_series_values).returns(completion_series)
        test_forecastable.stubs(:scope_series).returns('Scope series')
        test_forecastable.stubs(:completion_series).returns('Completion series')
        test_forecastable.stubs(:velocity).returns(velocity)
        test_forecastable.stubs(:x_axis_values).returns(x_axis_values)
        test_forecastable.stubs(:color_for_series).returns(Chart::HTML_COLORS["Red"])
        test_forecastable.expects(:last_coordinate_of_series).with('Scope series').returns([scope_series.size - 1, scope_series.last])
        test_forecastable.expects(:last_coordinate_of_series).with('Completion series').returns([completion_series.size - 1, completion_series.last])
        test_forecastable.instance_variable_set(:@x_axis_start_date, x_axis_start_date)
        test_forecastable.instance_variable_set(:@x_axis_end_date, x_axis_end_date)
        test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

        fix_date_projection_data = [4.228571428571429, 6.0]
        renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/05/13')
        renderer.expects(:add_line).with(fix_date_projection_data, 255, 'Difference between total scope and completed scope', true)
        renderer.expects(:set_data_class).with('Difference between total scope and completed scope', 'thick-line-series')
        renderer.expects(:set_x_values).with([target_release_date.to_epoch_milliseconds, target_release_date.to_epoch_milliseconds],'_$xFor Difference between total scope and completed scope','Difference between total scope and completed scope')
        renderer.expects(:hide_tooltip).with('Difference between total scope and completed scope')

        expects_gap_data_label_added(renderer, fix_date_projection_data,target_release_date)

        expects_series_added(renderer, [4, 4.228571428571429], [date_today, target_release_date].map(&:to_epoch_milliseconds), 'Linear (Completion series)', true)
        expects_series_added(renderer, [6, 6], [date_today, target_release_date].map(&:to_epoch_milliseconds), 'Unchanged Scope',  true)
        expects_hidden_series_added(renderer, date_today, x_axis_end_date + 4.days)

        test_forecastable.render(renderer)
      end
    end
  end

  def test_should_render_forecast_chart_without_gap_when_end_date_greater_than_today_and_current_date_is_target_release_date
    renderer = mock('renderer')
    date_today = Date.parse('12/05/2017')
    Timecop.freeze(date_today) do
      with_new_project(date_format: '%Y/%m/%d') do |project|
        x_axis_start_date = Date.parse('11/05/2017')
        x_axis_end_date = Date.parse('15/05/2017')
        x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
        target_release_date = date_today
        test_forecastable = TestForecastable.new
        test_forecastable.stubs(:project).returns(project)
        scope_series = [2, 6]
        completion_series = [2, 4]
        test_forecastable.stubs(:scope_series_values).returns(scope_series)
        test_forecastable.stubs(:completion_series_values).returns(completion_series)
        test_forecastable.stubs(:scope_series).returns('Scope series')
        test_forecastable.stubs(:completion_series).returns('Completion series')
        test_forecastable.stubs(:velocity).returns(velocity)
        test_forecastable.stubs(:x_axis_values).returns(x_axis_values)
        test_forecastable.stubs(:color_for_series).returns(Chart::HTML_COLORS["Red"])
        test_forecastable.expects(:last_coordinate_of_series).with('Scope series').returns([scope_series.size - 1, scope_series.last])
        test_forecastable.expects(:last_coordinate_of_series).with('Completion series').returns([completion_series.size - 1, completion_series.last])
        test_forecastable.instance_variable_set(:@x_axis_start_date, x_axis_start_date)
        test_forecastable.instance_variable_set(:@x_axis_end_date, x_axis_end_date)
        test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

        fix_date_projection_data = [4.0, 6.0]
        renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/05/12')
        renderer.expects(:add_line).with(fix_date_projection_data, 255, 'Difference between total scope and completed scope', true)
        renderer.expects(:set_data_class).with('Difference between total scope and completed scope', 'thick-line-series')
        renderer.expects(:set_x_values).with([target_release_date.to_epoch_milliseconds, target_release_date.to_epoch_milliseconds],'_$xFor Difference between total scope and completed scope','Difference between total scope and completed scope')
        renderer.expects(:hide_tooltip).with('Difference between total scope and completed scope')

        expects_gap_data_label_added(renderer, fix_date_projection_data,target_release_date)

        expects_hidden_series_added(renderer, date_today, x_axis_end_date + 4.days)

        test_forecastable.render(renderer)
      end
    end
  end

  def test_should_render_fix_date_chart_without_gap_when_target_release_date_is_less_than_x_axis_end_date
    renderer = mock('renderer')
    with_new_project(date_format: '%Y/%m/%d') do |project|
      x_axis_start_date = Date.parse('11/05/2017')
      x_axis_end_date = Date.parse('15/05/2017')
      x_axis_values = (x_axis_start_date..x_axis_end_date).to_a
      target_release_date = Date.parse('10/05/2017')
      test_forecastable = stub_test_forecastable(project, x_axis_end_date, x_axis_start_date, x_axis_values)
      test_forecastable.instance_variable_set(:@mark_target_release_date, target_release_date)

      expects_hidden_series_added(renderer, x_axis_end_date, x_axis_end_date + 4.days)
      renderer.expects(:set_fix_date_guide_line).with(target_release_date.to_epoch_milliseconds, '2017/05/10')
      renderer.expects(:set_target_date_scope_gap).never

      test_forecastable.render(renderer)
    end
  end

  private

  def expects_scope_and_completion_data_label_added(renderer, y_values, x_value)
    time = Time.now
    Time.stubs(:now).returns(time)
    scope_data_label_name = "Scope series #{time.milliseconds}"
    completion_data_label_name = "Completion series #{time.milliseconds}"
    renderer.expects(:add_line).with([y_values.first], Chart::HTML_COLORS["Black"], scope_data_label_name, true).returns(renderer)
    renderer.expects(:add_line).with([y_values.last], Chart::HTML_COLORS["Black"], completion_data_label_name, true).returns(renderer)
    renderer.expects(:set_x_values).with([x_value.to_epoch_milliseconds], "_$xFor Scope series and Completion series", scope_data_label_name, completion_data_label_name)
    renderer.expects(:set_data_labels).with(scope_data_label_name, y_values.first)
    renderer.expects(:set_data_labels).with(completion_data_label_name, y_values.last)
  end

  def expects_gap_data_label_added(renderer, y_values,x_value)
    renderer.expects(:add_line).with([y_values.reduce(&:+) / 2], Chart::HTML_COLORS["Black"], 'Leftover Scope', true).returns(renderer)
    renderer.expects(:set_x_values).with([x_value.to_epoch_milliseconds], "_$xFor Leftover Scope", 'Leftover Scope')
    renderer.expects(:set_data_labels).with('Leftover Scope', y_values.reverse.reduce(&:-).round.to_s)
    renderer.expects(:set_data_class).with('Leftover Scope','translate-label-by-10-10')
    renderer.expects(:hide_tooltip).with('Leftover Scope')
  end

  def stub_test_forecastable(project, x_axis_end_date, x_axis_start_date, x_axis_values)
    test_forecastable = TestForecastable.new
    test_forecastable.stubs(:project).returns(project)
    scope_series = [2, 6, 7, 9, 13]
    completion_series = [2, 4, 6, 7, 9]
    test_forecastable.stubs(:scope_series_values).returns(scope_series)
    test_forecastable.stubs(:completion_series_values).returns(completion_series)
    test_forecastable.stubs(:scope_series).returns('Scope series')
    test_forecastable.stubs(:completion_series).returns('Completion series')
    test_forecastable.stubs(:velocity).returns(velocity)
    test_forecastable.stubs(:x_axis_values).returns(x_axis_values)
    test_forecastable.stubs(:color_for_series).returns(Chart::HTML_COLORS["Red"])
    test_forecastable.expects(:last_coordinate_of_series).with('Scope series').returns([scope_series.size - 1, scope_series.last])
    test_forecastable.expects(:last_coordinate_of_series).with('Completion series').returns([completion_series.size - 1, completion_series.last])
    test_forecastable.instance_variable_set(:@x_axis_start_date, x_axis_start_date)
    test_forecastable.instance_variable_set(:@x_axis_end_date, x_axis_end_date)
    test_forecastable
  end

  def expects_series_added(renderer, y_values, x_values, series_name, hide_tooltip=false)
    renderer.expects(:add_line).with(y_values, Chart::HTML_COLORS["Red"], series_name).returns(renderer)
    renderer.expects(:set_x_values).with(x_values, "_$xFor #{series_name}", series_name)
    renderer.expects(:hide_tooltip).with(series_name) if hide_tooltip
    renderer.expects(:set_data_class).with(series_name, 'mingle-chart-dashed-line-series')
    renderer.expects(:set_legend_style).with(series_name, :dashed)
  end

  def expects_hidden_series_added(renderer, hidden_series_start_date, hidden_series_end_date)
    time = Time.now
    Time.stubs(:now).returns(time)
    hidden_series_x_values = (hidden_series_start_date..hidden_series_end_date)
    hidden_series_name = time.milliseconds.to_s
    renderer.expects(:add_line).with([0] * hidden_series_x_values.count, Charts::C3Renderers::ColorPalette::Colors::TRANSPARENT, hidden_series_name, true).returns(renderer)
    renderer.expects(:set_x_values).with(hidden_series_x_values.map(&:to_epoch_milliseconds), "_$xFor #{hidden_series_name}", hidden_series_name)
  end
end
