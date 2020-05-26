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

class EmailHelperTest < Test::Unit::TestCase

  def test_message_expired_filter
    Timecop.freeze(DateTime.parse('1/2/2017 02:15:00 UTC')) do
      message = Mailgun::Message.new({:timestamp => (Time.now - 3.day - 1.second).to_f})
      MessageExpiredFilter.new.filter?(message, nil)
      assert MessageExpiredFilter.new.filter?(message, nil)

      message = Mailgun::Message.new({:timestamp => (Time.now - 2.day).to_f})
      assert !MessageExpiredFilter.new.filter?(message, nil)

      message = Mailgun::Message.new({:timestamp => (Time.now - 4.day).to_f})
      assert MessageExpiredFilter.new.filter?(message, nil)
    end
  end

end

