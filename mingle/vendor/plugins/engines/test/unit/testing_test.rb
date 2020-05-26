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

require File.dirname(__FILE__) + '/../test_helper'

class TestingTest < Test::Unit::TestCase
  def setup
    Engines::Testing.set_fixture_path
    @filename = File.join(Engines::Testing.temporary_fixtures_directory, 'testing_fixtures.yml')
    File.delete(@filename) if File.exists?(@filename)
  end
  
  def teardown
    File.delete(@filename) if File.exists?(@filename)
  end

  def test_should_copy_fixtures_files_to_tmp_directory
    assert !File.exists?(@filename)
    Engines::Testing.setup_plugin_fixtures
    assert File.exists?(@filename)
  end
end
