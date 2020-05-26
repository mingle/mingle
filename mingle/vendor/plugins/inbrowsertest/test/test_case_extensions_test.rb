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

require File.dirname(__FILE__) + '/test_helper'   

class TestCaseExtensionsTest < Test::Unit::TestCase  
    
    def test_test_case_should_have_selenium_modules_included
      assert respond_to?(:selenium_session)  
      assert respond_to?(:new_selenium_session)  
      assert respond_to?(:close_selenium_sessions)  
      
    end

    def test_new_selenium_session_should_start_a_new_selenium_session
      interpreter = mock()
      interpreter.expects(:start) 
      
      new_selenium_session(interpreter)
    end
    
    def test_first_call_to_selenium_session_should_start_interpreter
      interpreter = mock()
      interpreter.expects(:start)     
      
      session1 = selenium_session(interpreter)
    end
    
    def test_selenium_session_should_return_same_session_when_called_twice
      interpreter = mock()
      interpreter.expects(:start) 
      
      session1 = new_selenium_session(interpreter)
      session2 = selenium_session
      
      assert_equal session1, session2
    end
    
    def test_close_selenium_sessions_should_close_all_sessions
      interpreter1 = mock()
      interpreter1.expects(:start)
      interpreter1.expects(:stop)
      
      interpreter2 = mock()
      interpreter2.expects(:start)
      interpreter2.expects(:stop)
      
      session1 = new_selenium_session(interpreter1)
      session2 = new_selenium_session(interpreter2)
      
      close_selenium_sessions
    end
    
end
