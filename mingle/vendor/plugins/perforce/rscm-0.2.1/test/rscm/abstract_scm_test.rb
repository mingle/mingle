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

module RSCM
  class AbstractSCMTest < Test::Unit::TestCase
    def test_should_load_all_scm_classes
      expected_scms_classes = [
        Cvs,
        Darcs,
        Monotone,
        Mooky,
        Perforce,
        StarTeam,
        Subversion
      ]
      assert_equal(
        expected_scms_classes.collect{|c| c.name},
        AbstractSCM.classes.collect{|c| c.name}.sort)
    end
  end
end
