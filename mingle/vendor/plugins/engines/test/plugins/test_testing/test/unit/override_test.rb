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

require File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. .. .. .. test test_helper]))

class OverrideTest < ActiveSupport::TestCase
  def test_overrides_from_the_application_should_work
    flunk "this test should be overridden by the app"
  end
  
  def test_tests_within_the_plugin_should_still_run
    assert true, "non-overridden plugin tests should still run"
  end
end

Engines::Testing.override_tests_from_app
