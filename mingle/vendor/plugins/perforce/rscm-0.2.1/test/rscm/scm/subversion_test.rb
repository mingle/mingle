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
require 'rscm'
require 'rscm/generic_scm_tests'

module RSCM
  class SubversionTest < Test::Unit::TestCase
  
    include GenericSCMTests
    include LabelTest

    def create_scm(repository_root_dir, path)
      Subversion.new(PathConverter.filepath_to_nativeurl("#{repository_root_dir}/#{path}"), path)
    end

    def test_repourl
      svn = Subversion.new("svn+ssh://mooky/bazooka/baluba", "bazooka/baluba")
      assert_equal("svn+ssh://mooky", svn.repourl)

      svn.path = nil
      assert_equal(svn.url, svn.repourl)

      svn.path = ""
      assert_equal(svn.url, svn.repourl)
    end
    
  end
end
