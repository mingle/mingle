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
  class MonotoneTest < Test::Unit::TestCase
    include GenericSCMTests

    def create_scm(repository_root_dir, path)
      mt = Monotone.new(
        "#{repository_root_dir}/MT.db",
        "com.example.testproject",
        "tester@test.net",
        "tester@test.net",
        File.dirname(__FILE__) + "/keys"
      )
    end
  end
end
