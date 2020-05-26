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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class DataDirTest < ActiveSupport::TestCase

  include FileUtils

  def test_mingle_public_directory_path_is_correct
    folders = [MINGLE_DATA_DIR, 'public']
    assert_equal File.join(*folders), DataDir::Public.directory.pathname
  end


  def test_public_dir_should_be_suffixed_with_app_namespace_if_app_namespace_exists
    MingleConfiguration.with_app_namespace_overridden_to("foo") do
      folders = [MINGLE_DATA_DIR, 'foo', 'public']
      assert_equal File.join(*folders), DataDir::Public.directory.pathname
    end
  end

end
