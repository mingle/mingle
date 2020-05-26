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

module SecureRandomHelper
  def random_32_char_hex
    # same as used for generating session id in Ruby on Rails
    md5 = Digest::MD5::new
    now = Time::now
    md5.update(now.to_s)
    md5.update(String(now.usec))
    md5.update(String(rand(0)))
    md5.update(String($$))
    md5.update('foobar')
    md5.hexdigest
  end
  module_function :random_32_char_hex

  def random_byte
    random_32_char_hex[0..1].to_i(16)
  end
  module_function :random_byte
  
  # todo: binary >> base 64 
  def random_password
    random_32_char_hex[0..10]
  end
  module_function :random_password
end
