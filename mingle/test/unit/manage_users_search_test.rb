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

class ManageUsersSearchTest < ActiveSupport::TestCase
  
  def setup
    @admin = login_as_admin
  end
  
  def test_exclude_deactivated_users_should_be_specified
    assert ManageUsersSearch.new(nil, false).exclude_deactivated_users?
    assert_equal false, ManageUsersSearch.new(nil, true).exclude_deactivated_users?
  end
  
  def test_should_be_able_to_initialize_without_params
    assert_nothing_raised { ManageUsersSearch.new(nil, true) }
  end
  
  def test_should_pluralize_when_multiple_results
    users = ["user1", "farouche user"]
    search = ManageUsersSearch.new({:query => "user"}, true)
    assert_equal "Search results for #{'user'.bold}.", search.result_message(users)
  end
  
  def test_should_be_singular_when_one_results
    users = ["farouche user"]
    search = ManageUsersSearch.new({:query => "farouche"}, true)
    assert_equal "Search result for #{'farouche'.bold}.", search.result_message(users)
  end
  
  def test_should_be_no_results_message_when_no_results
    users = []
    search = ManageUsersSearch.new({:query => "farouche"}, true)
    assert_equal "Your search for #{search.query.bold} did not match any users.", search.result_message(users)
  end
  
end
