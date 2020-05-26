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

class LDAPAuthTest < ActiveSupport::TestCase

  # bug 9940
  def test_should_ignore_legacy_property
    assert_nothing_raised(RuntimeError) {
      auth = LDAPAuthentication.new
      auth.configure(:auto_enroll_as_mingle_admin => true)
    }
  end
  
  # bug 9940
  def test_should_continue_to_throw_error_for_nonexistent_property
    assert_raises(NoMethodError) do
      auth = LDAPAuthentication.new
      auth.configure(:nonexisting_property => true)
    end
  end
  
end
  
