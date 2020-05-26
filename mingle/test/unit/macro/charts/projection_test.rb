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

class Charts::Forecastable::ProjectionTest < ActiveSupport::TestCase
  
  def test_project_forecast_data_on_given_target_release_date_line
    scope = [1, 5]
    completion = [1, 1]
    forecast = [5, 5]
    target_x = 2
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert_equal [[1, 1], [2, 2]], projection.completion_projection_segment
    assert_equal [[1, 5], [2, 5]], projection.scope_projection_segment
    assert_equal({:end_point => [2, 5.0], :start_point => [2, 2.0], :label => (5 - 2).to_s, :label_position => [2, (2.0+5.0)/2]}, projection.gap)
  end

  def test_gap_label_should_be_integer
    scope = [1, 4]
    completion = [1, 1]
    forecast = [5, 4]
    target_x = 2
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert_equal("2", projection.gap[:label])
  end

  def test_project_completion_is_same_as_scope_when_target_is_after_completion_point
    scope = [1, 5]
    completion = [1, 5]
    forecast = [1, 5]
    target_x = 2
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert_nil projection
  end

  def test_project_completion_is_same_as_scope_when_target_is_same_completion_point
    scope = [1, 5]
    completion = [1, 5]
    forecast = [1, 5]
    target_x = 1
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert projection
    assert_equal [[1, 5], [1, 5]], projection.completion_projection_segment
    assert_equal [[1, 5], [1, 5]], projection.scope_projection_segment
    assert_equal({:end_point => [1, 5], :start_point => [1, 5], :label => '0', :label_position => [1, 5]}, projection.gap)
  end

  def test_project_completion_is_same_as_scope_when_target_is_same_completion_point
    scope = [3, 7]
    completion = [3, 5]
    forecast = [4, 7]
    target_x = 4
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert projection
    assert_equal [[3, 5], [4, 7]], projection.completion_projection_segment
    assert_equal [[3, 7], [4, 7]], projection.scope_projection_segment
    assert_equal({:end_point => [4, 7], :start_point => [4, 7], :label => '0', :label_position => [4, 7]}, projection.gap)
  end

  def test_project_completion_is_same_as_scope_when_target_is_before_completion_point
    scope = [2, 5]
    completion = [2, 5]
    forecast = [2, 5]
    target_x = 1
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert_nil projection
  end

  def test_project_completion_is_not_same_as_scope_when_target_is_before_completion_point
    scope = [2, 5]
    completion = [2, 4]
    forecast = [3, 6]
    target_x = 1
    projection = Charts::Forecastable::Projection.create(scope, completion, forecast, target_x)
    assert_nil projection
  end
end
