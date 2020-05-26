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

require 'test/unit'
require 'rscm/path_converter'

module RSCM
  class PathConverterTest < Test::Unit::TestCase
    include PathConverter

    def test_should_convert_os_path_to_native_path
      p1 = nil
      n1 = nil
      n2 = nil
    
      if(WIN32)
        p1 = "c:\\scm\\damagecontrol"
        n1 = p1
        n2 = p1
      elsif(CYGWIN)
        p1 = "/cygdrive/c/scm/damagecontrol"
        n1 = "c:\\scm\\damagecontrol"
        # This format is needed when passing to an IO.popen on non-cygwin windows tools (like windows native svn)
        n2 = "c:\\\\scm\\\\damagecontrol"
      else
        p1 = "/cygdrive/c/scm/damagecontrol"
        n1 = p1
        n2 = p1
      end
      assert_equal(n1, filepath_to_nativepath(p1, false))
      assert_equal(n2, filepath_to_nativepath(p1, true))

      assert_equal(p1, nativepath_to_filepath(n2))
      assert_equal(p1, nativepath_to_filepath(n1))
    end

    def test_should_convert_os_path_to_native_url
      path = nil
      nativeurl = nil

      if(WIN32)
        path = "c:/scm/damagecontrol"
        nativeurl = "file:///c:/scm/damagecontrol"
      elsif(CYGWIN)
        path = "/cygdrive/c/scm/damagecontrol"
        nativeurl = "file:///c:/scm/damagecontrol"
      else
        path = "/cygdrive/c/scm/damagecontrol"
        nativeurl = "file:///cygdrive/c/scm/damagecontrol"      
      end
      assert_equal(nativeurl, filepath_to_nativeurl(path))
    end
  
  end
end
