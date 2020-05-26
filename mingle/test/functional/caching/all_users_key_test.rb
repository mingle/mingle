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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class AllUsersKeyTest < ActionController::TestCase
  include CachingTestHelper

  def test_any_user_update_should_regenerate_the_key
    assert_key_changed_after do
      User.find_by_login('member').update_attribute(:name, 'memberas')
    end

  end

  def test_any__other_user_update_should_regenerate_the_key
      assert_key_changed_after do
          User.find_by_login('bob').update_attribute(:login, 'bobbb')
      end
  end
  
  def test_should_use_generate_same_key_when_there_are_not_user_updated
    assert_equal key, key
  end
  
  private
  def key
    KeySegments::AllUsers.new.to_s
  end

end
