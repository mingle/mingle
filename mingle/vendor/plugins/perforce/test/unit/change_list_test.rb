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

class ChangeListTest < ActiveSupport::TestCase
  def test_change_list_should_parse_the_log_in_windows_machine
    log = "Change 2 by twer@qianqian on 2008/11/25 11:28:14\r\n\r\n\t#2 second check in\r\n\r\nAffected files ...\r\n\r\n... //depot/2.txt#1 add\r\n... //depot/2.txty#1 edit\r\n\r\n"
    change_list = P4::Changelist.new(log)
    assert_equal '#2 second check in', change_list.message
    assert_equal 2, change_list.files.size

    assert_equal '//depot/2.txt', change_list.files[0].path
    assert_equal 1, change_list.files[0].revision
    assert_equal 'A', change_list.files[0].status
    assert_equal '//depot/2.txty', change_list.files[1].path
    assert_equal 1, change_list.files[1].revision
    assert_equal 'M', change_list.files[1].status
  end  
  
  def test_change_list_should_parse_the_log_in_mac_machine
    log = "Change 2 by twer@qianqian on 2008/11/25 11:28:14\n\n\t#2 second check in\n\nAffected files ...\n\n... //depot/2.txt#1 add\n... //depot/2.txty#1 edit\n\n"
    change_list = P4::Changelist.new(log)
    assert_equal '#2 second check in', change_list.message
    assert_equal 2, change_list.files.size

    assert_equal '//depot/2.txt', change_list.files[0].path
    assert_equal 1, change_list.files[0].revision
    assert_equal 'A', change_list.files[0].status
    assert_equal '//depot/2.txty', change_list.files[1].path
    assert_equal 1, change_list.files[1].revision
    assert_equal 'M', change_list.files[1].status
  end
end
