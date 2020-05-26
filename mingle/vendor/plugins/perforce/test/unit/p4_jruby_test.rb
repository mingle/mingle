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

#for run this test, you need start a perforce server manually
#the login user should be xli and no password
class P4JrubyTest < ActiveSupport::TestCase
  # for_manual_test
  does_not_work_without_jruby
  
  #need a file named a.txt on the root and has content '123456789'
  def x_test_file_contents
    @p4 = P4.new(:username => 'xli', :host => 'localhost', :port => '1666')
    assert_equal '123456789', @p4.file_contents('//depot/a.txt', 1).strip
  end
  
end
