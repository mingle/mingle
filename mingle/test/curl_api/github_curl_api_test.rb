#encoding: utf-8

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

# Tags: api_version_2
class GitRevisionApiTest < ActiveSupport::TestCase

  SAMPLE_REQUEST = '{"repository":{"id":19327016,"name":"test_push","url":"https://github.com/betarelease/test_push"},"commits":[{"id":"4fbee7a1ae639    e07bd7792da0912bb7e4015a0e1","distinct":true,"message":"changing for push ßpéçîål characters","timestamp":"2014-04-30T13:57:01-07    :00","url":"https://github.com/betarelease/test_push/commit/4fbee7a1ae639e07bd7792da0912bb7e4015a0e1","author":{"name":"Sudhindra     Rao","email":"sudhindra.r.rao@gmail.com","username":"betarelease"},"committer":{"name":"Sudhindra Rao","email":"sudhindra.r.rao@    gmail.com","username":"betarelease"},"added":[],"removed":[],"modified":["README.md"]}]}'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_should_handle_github_messages_with_special_characters
    url = project_base_url_for 'github.json'
    output = %x[curl -i -X POST #{url} -d '#{SAMPLE_REQUEST}' -H 'content-type: application/json']
    assert_response_code(200, output)
  end
end
