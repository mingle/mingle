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

class ThreadDumperTest < ActiveSupport::TestCase
  does_not_work_without_jruby
  def test_dump_to_file
    test_file = 'thread_dump_test_file.txt'
    ThreadDumper.dump_to(test_file)
    assert File.exist?(test_file)
    assert File.read(test_file).size > 0
  ensure
    FileUtils.rm_rf(test_file)
  end
end
