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

class DatabaseErrorConverterTest < ActiveSupport::TestCase
  
  def test_connect_postgresql_error_message
    exception = Exception.new(%{The driver encountered an error: org.postgresql.util.PSQLException: Connection refused. Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections})
    expected = %{Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections}
    assert_equal(expected, DatabaseErrorConverter.convert(exception))
                                             
    exception = Exception.new(%{The driver encountered an error: org.postgresql.util.PSQLException: FATAL: database \"jj\" does not exist})
    expected = %{database \"jj\" does not exist}
    assert_equal expected, DatabaseErrorConverter.convert(exception)
    
    exception = Exception.new(%{The driver encountered an error: org.postgresql.util.PSQLException: The connection attempt failed.})
    assert_equal(%{The connection attempt failed.}, DatabaseErrorConverter.convert(exception))
  end
  
  def test_connect_oracle_error_message
    # case 1: machine name is incorrect, no password given (maybe this case will not happen anymore since password is required on Oracle)
    exception = Exception.new(%{The driver encountered an error: java.sql.SQLException: Null user or password not supported in THIN driver})
    expected = %{Check that the machine name and listener port are correct}
    assert_equal(expected, DatabaseErrorConverter.convert(exception))
    
    # case 2: machine name is correct, database instance name is incorrect, but username and password are given
    exception = Exception.new(%{The driver encountered an error: java.sql.SQLException: Listener refused the connection with the following error:
                                ORA-12505, TNS:listener does not currently know of SID given in connect descriptor
                                The Connection descriptor used by the client was:
                                sfsstdmngdb01.thoughtworks.com:1521:mingle
                                })
    expected = %{Check that the database instance name is correct}
    assert_equal(expected, DatabaseErrorConverter.convert(exception))
    
    # case 3: machine name is incorrect, password given
    exception = Exception.new(%{The driver encountered an error: java.sql.SQLException: Io exception: The Network Adapter could not establish the connection})
    expected = %{Check that the machine name and listener port are correct}
    assert_equal(expected, DatabaseErrorConverter.convert(exception))
    
    # case 4: everything is correct except for password
    exception = Exception.new(%{The driver encountered an error: java.sql.SQLException: ORA-01017: invalid username/password; logon denied})
    expected = %{Check that your username and password are correct}
    assert_equal(expected, DatabaseErrorConverter.convert(exception))
  end
end
