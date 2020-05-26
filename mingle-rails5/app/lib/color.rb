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

class Color

  BLUE_GREEN = "#3D8F84"
  GREEN = "#19A657"
  LIME = "#55EB7D"
  TEAL = "#198FA6"
  DARK_TURQUIOSE = "#24C2CC"
  LIGHT_TURQUOISE = "#30E4EF"
  PURPLE = "#712468"
  HOT_PINK = "#EE5AA2"
  PASTEL_PINK = "#FFA5D1"
  RED = "#D4292B"
  RED_ORANGE = "#EE675A"
  ORANGE = "#EB9955"
  ORANGE_YELLOW = "#EBC855"
  YELLOW = "#EAEB55"
  BLACK = "#000000"

  DEFAULT_AVATAR = '#8EC6DE'

  def self.defaults
    [
     BLUE_GREEN,
     GREEN,
     LIME,
     TEAL,
     DARK_TURQUIOSE,
     LIGHT_TURQUOISE,
     PURPLE,
     HOT_PINK,
     PASTEL_PINK,
     RED,
     RED_ORANGE,
     ORANGE,
     ORANGE_YELLOW,
     YELLOW,
     BLACK
    ]
  end

  def self.random(avoid=[])
    (defaults-avoid).shuffle.first
  end

  def self.valid?(hex_value)
    !!(hex_value =~ /#[\dA-F]{6}/)
  end

  def self.for(str)
    defaults[hash_code(str).abs % defaults.length]
  end

  def self.hash_code(str)
    hash = 0
    return hash if str.blank?
    str.split("").inject(hash) do |_hash, char|
      (_hash << 5) - _hash + char.ord
    end
  end
end
