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

require 'yaml'
require 'rscm/changes_fixture'

module RSCM
  class ChangesTest < Test::Unit::TestCase
    include ChangesFixture
    
    def setup
      setup_changes
    end
    
    def test_convert_changes_to_changesets_should_match_user_message_and_timestamp_
      changesets = ChangeSets.new
      changesets.add(@change1)
      changesets.add(@change2)
      changesets.add(@change3)
      changesets.add(@change4)
      changesets.add(@change5)
      changesets.add(@change6)
      changesets.add(@change7)

      changeset_0 = ChangeSet.new
      changeset_0 << @change1
      changeset_0 << @change2
      
      changeset_1 = ChangeSet.new
      changeset_1 << @change3

      changeset_2 = ChangeSet.new
      changeset_2 << @change4

      changeset_3 = ChangeSet.new
      changeset_3 << @change5
      changeset_3 << @change6
      changeset_3 << @change7

      assert_equal(4, changesets.length)

      expected_changesets = ChangeSets.new
      expected_changesets.add(changeset_0)
      expected_changesets.add(changeset_1)
      expected_changesets.add(changeset_2)
      expected_changesets.add(changeset_3)

      assert_equal(expected_changesets, changesets)
    end
    
    def test_changesets_can_add_individual_changes_and_group_in_changeset_instances
      changesets = ChangeSets.new
      assert(0, changesets.length)
      
      changesets.add(@change1)
      changesets.add(@change2)
      changesets.add(@change3)
      changesets.add(@change4)
      assert(3, changesets.length)
      
      tjo_bing_changeset = changesets[0]
      hipp_hurra_changeset = changesets[1]
      hipp_hurraX_changeset = changesets[2]
      assert(2, tjo_bing_changeset.length)
      assert(1, hipp_hurra_changeset.length)
      assert(1, hipp_hurraX_changeset.length)

      assert_same(@change1, tjo_bing_changeset[0])
      assert_same(@change2, tjo_bing_changeset[1])
      assert_same(@change3, hipp_hurra_changeset[0])
      assert_same(@change4, hipp_hurraX_changeset[0])
    end

    def test_should_sort_by_time
      changesets = ChangeSets.new
      changesets.add(@change1)
      changesets.add(@change4)
      changesets.add(@change2)
      changesets.add(@change7)
      changesets.add(@change5)
      changesets.add(@change3)
      changesets.add(@change6)
      
      changesets = changesets.sort do |a,b|
        a.time <=> b.time
      end
      assert_equal(4, changesets.length)

      assert_equal(@change2.time, changesets[0].time)
      assert_equal(@change7.time, changesets[-1].time)
    end
    
    def test_can_parse_changesets_from_yaml
      changesets = File.open(File.dirname(__FILE__) + "/changesets.yaml") do |io|
        YAML::load(io)
      end
      assert_equal("rinkrank", changesets[0][1].developer)
      assert_equal("En to\ntre buksa \nned\n", changesets[0][1].message)
    end
    
    def test_reports_timestamp_of_latest_change
      changeset = ChangeSet.new
      changeset << Change.new(nil, nil, nil, nil, nil, Time.utc(2004))
      changeset << Change.new(nil, nil, nil, nil, nil, Time.utc(2005))
      changeset << Change.new(nil, nil, nil, nil, nil, Time.utc(2003))
      assert_equal(Time.utc(2005), changeset.time)
    end

    def test_should_sort_changesets
      changesets = ChangeSets.new
      changesets.add(@change1)
      changesets.add(@change4)
      changesets.add(@change2)
      changesets.add(@change7)
      changesets.add(@change5)
      changesets.add(@change3)
      changesets.add(@change6)
      
      cs0 = changesets[0]
      cs1 = changesets[1]
      cs2 = changesets[2]
      cs3 = changesets[3]
      
      reversed = changesets.reverse
      assert_equal(cs0, reversed[3])
      assert_equal(cs1, reversed[2])
      assert_equal(cs2, reversed[1])
      assert_equal(cs3, reversed[0])
    end
  end

end
