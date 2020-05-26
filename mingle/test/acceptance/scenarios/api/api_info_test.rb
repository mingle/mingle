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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: api_version_2
class ApiInfoTest < ActiveSupport::TestCase

  def setup
    enable_basic_auth
    @url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/info.xml"
  end

  def teardown
    disable_basic_auth
  end

  def test_can_get_version_number_and_revision_number
    info = get(@url, {}).body
    assert_equal MINGLE_VERSION, get_element_text_by_xpath(info, '/info/version')
    requires_jruby do
      assert_equal MINGLE_REVISION, get_element_text_by_xpath(info, '/info/revision')
    end
  end

end
