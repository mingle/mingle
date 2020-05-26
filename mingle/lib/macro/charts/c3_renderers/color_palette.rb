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

module Charts
  module C3Renderers
    class ColorPalette
      module Colors
        TRANSPARENT = 'transparent'
        ALL = Chart::MINGLE_COLORS.values
      end

      def self.get_color(index)
        hex_color_string(Colors::ALL[index % Colors::ALL.length])
      end

      def self.hex_color_string(color)
        return "##{color.to_s(16).rjust(6, '0')}" if Numeric === color

        color.downcase
      end
    end
  end
end
