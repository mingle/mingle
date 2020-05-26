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

module C3RendererTestHelpers
  def chart_options
    JSON.parse(@renderer.make_chart).with_indifferent_access
  end

  def add_line_series_and_assert_renderer(series_data)
    series_data.each_pair do |label, (data, color, _)|
      renderer = @renderer.add_line(data.clone, color, label)
      assert_equal(@renderer, renderer)
    end
  end

  def add_trend_line_series_and_assert_renderer(series_data)
    series_data.each_pair do |label, (data, color, _)|
      renderer = @renderer.add_trend_line(data.clone, color, label)
      assert_equal(@renderer, renderer)
    end
  end

  def add_series(series_data)
    series_data.each_pair do |label, (data, color, _)|
      @renderer.add_data_set(data.clone, color, label)
    end
  end

  def random_args
    Array.new(rand(10)) { rand(1..100) }
  end

  def assert_series_data(expected_series_data)
    series_data = chart_options[:data]
    expected_series_data.each_with_index do |(label, (data, color, type)), idx|
      assert_equal(data.unshift(label), series_data[:columns][idx])
      assert_equal(type, series_data[:types][label])
      if Hash === color
        assert_equal(color[:color], series_data[:colors][label])
        assert_equal(color[:style].to_s, series_data[:regions][label].first[:style])
      else
        assert_equal(color, series_data[:colors][label])
        assert_nil(series_data[:regions][label])
      end
    end
  end
end
