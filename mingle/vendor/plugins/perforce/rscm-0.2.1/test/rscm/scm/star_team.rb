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
require 'fileutils'
require 'rscm'
require 'rscm/generic_scm_tests'

module RSCM
  class StarTeamTest < Test::Unit::TestCase
#    include GenericSCMTests

    def create_scm(repository_root_dir, path)
      StarTeam.new(ENV["STARTEAM_USER"], ENV["STARTEAM_PASS"], "192.168.254.21", 49201, "NGST Application", "NGST Application", "java")
    end

    def test_changesets
      from = Time.new - 2 * 3600 * 24
      to = Time.new - 1 * 3600 * 24
      puts "Getting changesets for #{from} - #{to}"
    
      changesets = create_scm(nil, nil).changesets(nil, from, to)
      assert_equal(1, changesets.length)
      assert_equal(Time.utc(2004, 11, 30, 04, 52, 24), changesets[0][0].time)
      assert_equal(Time.utc(2004, 11, 30, 04, 53, 23), changesets[0][1].time)
      assert_equal(Time.utc(2004, 11, 30, 04, 53, 23), changesets[0].time)
      assert_equal("rinkrank", changesets[0].developer)
      assert_equal("En to\ntre buksa \nned\n", changesets[0].message)
    end

    def test_checkout
      files = create_scm(nil, nil).checkout("target/starteam/checkout")
      assert_equal(3, files.length)
      assert_equal("eenie/meenie/minee/mo", files[0])
      assert_equal("catch/a/redneck/by", files[1])
      assert_equal("the/toe", files[2])
    end
  end
end
