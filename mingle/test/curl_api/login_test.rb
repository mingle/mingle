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

# Tags: api, login
class LoginTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
  end

  def teardown
    disable_basic_auth
  end

  def test_should_lock_user_when_password_is_wrong_for_10_times
    url = projects_list_url(:password => 'wrong')
    10.times do
      %x[curl -X GET #{url}]
    end
    output = %x[curl -X GET #{url}]
    assert_match /You have attempted to log in 10 times. Please try again in one minute./, output
  end
end
