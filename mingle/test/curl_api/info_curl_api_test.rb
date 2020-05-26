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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')

# Tags: api
class InfoCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    @url = "http://localhost:#{MINGLE_PORT}/api/v2/info.xml"
  end

  def test_can_get_mingle_info_via_api
    output = %x[curl #{@url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes("<info>", output)
    assert_response_includes("<version>#{MINGLE_VERSION}", output)
    requires_jruby do
      assert_response_includes("<revision>#{MINGLE_REVISION}", output)
    end
  end

  def test_error_message_when_use_old_api_format_to_get_info
    old_api_format_url="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/info.xml"
    output = %x[curl -i #{old_api_format_url}]
    assert_response_code(404, output)
  end
end
