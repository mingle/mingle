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

class JrubyProductionPatchTest < ActiveSupport::TestCase

  def test_should_be_able_to_load_long_string
    # without the jruby production patch of ChannelStream this test will hang. See the file for details
    # We use this logging because Timeout couldn't get us out of the hanging code
    requires_jruby do
      ActiveRecord::Base.logger.info("If this is the last line you're seeing, it means JrubyProductionPatchTest.test_should_be_able_to_load_long_string is hanging and so has failed")
      content = dump_and_load(32769)
      assert_equal 32769, content.length
    end
  end
  
  private
  def dump_and_load(number_of_characters)
    file = File.join('tmp','dumpfile')
    long_string = Marshal.dump("a" * number_of_characters)
    File.open(file, "w+") do |io|
      io << long_string
    end

    File.open(file, "rb") do |f|
      result = Marshal.load(f)
    end
  end
  
end
