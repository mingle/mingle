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
require 'rscm/changes'

module RSCM
  module ChangesFixture
    def setup_changes
      #1
      @change1 = RSCM::Change.new("path/one", nil,   "jon",   "Fixed CATCH-22", nil, Time.utc(2004,7,5,12,0,2))
      @change2 = RSCM::Change.new("path/two", nil,   "jon",   "Fixed CATCH-22", nil, Time.utc(2004,7,5,12,0,4))
      #2
      @change3 = RSCM::Change.new("path/three", nil, "jon",   "hipp hurra", nil, Time.utc(2004,7,5,12,0,6))
      #3
      @change4 = RSCM::Change.new("path/four", nil,  "aslak", "hipp hurraX", nil, Time.utc(2004,7,5,12,0,8))
      #4
      @change5 = RSCM::Change.new("path/five", nil,  "aslak", "hipp hurra", nil, Time.utc(2004,7,5,12,0,10))
      @change6 = RSCM::Change.new("path/six", nil,   "aslak", "hipp hurra", nil, Time.utc(2004,7,5,12,0,12))
      @change7 = RSCM::Change.new("path/seven", nil, "aslak", "hipp hurra", nil, Time.utc(2004,7,5,12,0,14))
    end
  end
end
