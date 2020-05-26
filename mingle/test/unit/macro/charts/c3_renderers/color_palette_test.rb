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

require File.expand_path(File.dirname(__FILE__) + '/../../../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/c3_renderer_test_helpers')

module Charts
  module C3Renderers
    class ColorPaletteTest < ActiveSupport::TestCase
      test 'get_color_should_return_color_at_given_index' do
        assert_equal('#' + Chart::MINGLE_COLORS.values[2].to_s(16), ColorPalette.get_color(2))
      end

      test 'get_color_should_return_color_at_circular_index_when_index_greater_than_total_colors_available' do
        index = Chart::MINGLE_COLORS.values.length + 4

        assert_equal('#' + Chart::MINGLE_COLORS.values[4].to_s(16), ColorPalette.get_color(index))
      end

      test 'hex_color_string_should_return_hex_string_when_color_is_numeric' do
        assert_equal('#ffffff', ColorPalette.hex_color_string(16777215))
      end

      test 'hex_color_string_should_return_lowercase_string_when_color_is_not_numeric' do
        assert_equal('red', ColorPalette.hex_color_string('ReD'))
        assert_equal('#ffddee', ColorPalette.hex_color_string('#FFDDEE'))
      end
    end
  end
end
