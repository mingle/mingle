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

class URLSafeBase64Test < ActiveSupport::TestCase
  def test_to_base64
    assert_equal 'MTIzNTQ2Nzg5MA', '1235467890'.to_base64_url_safe
  end
  
  def test_from_base64
    assert_equal '1235467890', 'MTIzNTQ2Nzg5MA'.from_base64_url_safe
  end
end
