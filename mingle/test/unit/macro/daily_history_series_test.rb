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

# Tags: daily_history
class DailyHistorySeriesTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  
  def setup
    login_as_member
    @project = data_series_chart_project
    @project.activate
  end
  
  def teardown
    Clock.reset_fake
  end

  def test_series_line_width_should_override_chart_line_width
    series = DailyHistorySeries.new(create_chart_stub(:line_width => '10'), { 'line-width' => '2', 'conditions' => 'size > 1' }, {})
    assert_equal "2", series.line_width
    
    series = DailyHistorySeries.new(create_chart_stub(:line_width => '10'), { 'conditions' => 'size > 1' }, {})
    assert_equal "10", series.line_width

    series = DailyHistorySeries.new(create_chart_stub(:line_width => '10'), { 'line-width' => '', 'conditions' => 'size > 1' }, {})
    assert_equal "10", series.line_width
  end
  
  def test_label_should_default_to_conditions_when_not_explicitly_given
    series = DailyHistorySeries.new(create_chart_stub, { 'conditions' => 'size > 1' }, {})
    assert_equal 'size > 1', series.label
  end

  def test_label_should_be_able_to_be_set
    series = DailyHistorySeries.new(create_chart_stub, { 'label' => 'hot, like fire' }, {})
    assert_equal 'hot, like fire', series.label
  end
  
  def test_label_should_default_to_all_if_not_set_and_no_conditions_given
    series = DailyHistorySeries.new(create_chart_stub, {}, {})
    assert_equal 'All', series.label
  end
  
  def test_should_convert_named_colors_to_hex_color_codes
    series = DailyHistorySeries.new(create_chart_stub, {'color' => 'black'}, {})
    assert_equal 0, series.color
  end

  def test_should_know_if_color_was_not_defined
    assert_false DailyHistorySeries.new(create_chart_stub, {'color' => 'red'}, {}).color_undefined?
    assert DailyHistorySeries.new(create_chart_stub, {}, {}).color_undefined?
  end
  
  # bug #9795
  def test_label_should_be_a_string
    series = DailyHistorySeries.new(create_chart_stub, { 'label' => 123 }, {})
    assert_equal '123', series.label
  end
  
  protected
  
  def create_chart_stub(chart_options = {})
    DailyHistoryChartStub.new(chart_options)
  end
  
  class DailyHistoryChartStub
    def initialize(chart_options)
      @data_for = chart_options[:data_for]
      @open_struct = OpenStruct.new(chart_options.reverse_merge(:x_axis_values => ['14 May 2009', '15 May 2009'], :aggregate => 'SUM(Size)'))
    end
    
    def data_for(date, series_index)
      @data_for[date][series_index]
    end
    
    def method_missing(name, *args)
      @open_struct.send(name, *args)
    end
  end
  
  def set_project_timezone_to_utc
    @project.update_attributes! :time_zone => ActiveSupport::TimeZone.new('UTC').name
  end

end
