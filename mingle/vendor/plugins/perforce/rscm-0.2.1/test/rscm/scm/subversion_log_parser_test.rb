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
require 'stringio'
require 'rscm'

module RSCM
  class SubversionLogParserTest < Test::Unit::TestCase

SIMPLE_LOG_ENTRY = <<EOF
r2 | ahelleso | 2004-07-11 14:29:35 +0100 (Sun, 11 Jul 2004) | 1 line
Changed paths:
   M /damagecontrolled/build.xml
   M /damagecontrolled/src/java/com/thoughtworks/damagecontrolled/Thingy.java

changed something
else
------------------------------------------------------------------------
EOF

SIMPLE_LOG_ENTRY_WITH_BACKSLASHES = <<EOF
r2 | ahelleso | 2004-07-11 14:29:35 +0100 (Sun, 11 Jul 2004) | 1 line
Changed paths:
   M \\damagecontrolled\\build.xml
   M \\damagecontrolled\\src\\java\\com\\thoughtworks\\damagecontrolled\\Thingy.java

changed something
else
------------------------------------------------------------------------
EOF
    
    def test_can_parse_SIMPLE_LOG_ENTRIES
      parser = SubversionLogEntryParser.new("damagecontrolled", "damagecontrolled")
      can_parse_simple_log_entry(parser, SIMPLE_LOG_ENTRY)
      can_parse_simple_log_entry(parser, SIMPLE_LOG_ENTRY_WITH_BACKSLASHES)
    end
    
    def can_parse_simple_log_entry(parser, entry)
      changeset = parser.parse(StringIO.new(entry)) {|line|}

      assert_equal(2, changeset.revision)
      assert_equal("ahelleso", changeset.developer)
      assert_equal(Time.utc(2004,7,11,13,29,35), changeset.time)
      assert_equal("changed something\nelse", changeset.message)

      assert_equal(2, changeset.length)
      assert_equal("build.xml", changeset[0].path)
      assert_equal(2, changeset[0].revision)
      assert_equal(Change::MODIFIED, changeset[0].status)
      assert_equal("src/java/com/thoughtworks/damagecontrolled/Thingy.java", changeset[1].path)
      assert_equal(Change::MODIFIED, changeset[1].status)
    end

    def test_parses_entire_log_into_changesets
      File.open(File.dirname(__FILE__) + "/svn-proxytoys.log") do |io|
        parser = SubversionLogParser.new(io, "trunk/proxytoys", nil)

        changesets = parser.parse_changesets
        
        assert_equal(66, changesets.length)
        # just some random assertions
        assert_equal(
          "DecoratingInvoker now hands off to a SimpleInvoker rather than a DelegatingInvoker if constructed with an Object to decorate.\n" +
          "Added protected getDelegateMethod(name, params)\n", changesets[0].message)

        assert_equal(66, changesets[3].revision)
        assert_equal("tastapod", changesets[3].developer)
        assert_equal(Time.utc(2004,05,24,17,06,18,0), changesets[3].time)
        assert_match(/Factored delegating behaviour out/ , changesets[3].message)
        assert_equal(15, changesets[3].length)

        assert_equal("src/com/thoughtworks/proxy/toys/delegate/DelegatingInvoker.java" , changesets[3][1].path)
        assert_equal(Change::ADDED , changesets[3][1].status)
        assert_equal(66 , changesets[3][1].revision)
        assert_equal(65, changesets[3][1].previous_revision)

        assert_equal("src/com/thoughtworks/proxy/toys/delegate/ObjectReference.java" , changesets[3][3].path)
        assert_equal(Change::MOVED, changesets[3][3].status)

        assert_equal("src/com/thoughtworks/proxy/toys/delegate/OldDelegatingInvoker.java" , changesets[3][4].path)
        assert_equal(Change::DELETED, changesets[3][4].status)

        assert_equal("test/com/thoughtworks/proxy/toys/echo/EchoingTest.java" , changesets[3][14].path)
        assert_equal(Change::MODIFIED , changesets[3][14].status)

      end
    end

    def test_parses_entire_log_into_changesets
      File.open(File.dirname(__FILE__) + "/svn-cargo.log") do |io|
        parser = SubversionLogParser.new(io, "trunk/proxytoys", nil)
        changesets = parser.parse_changesets
        assert_equal(16, changesets.length)
      end
    end

    def test_parses_another_tricky_log
      File.open(File.dirname(__FILE__) + "/svn-growl.log") do |io|
        parser = SubversionLogParser.new(io, "trunk", nil)
        changesets = parser.parse_changesets
        assert_equal(82, changesets.length)
      end
    end

    def test_parses_log_with_spaces_in_file_names
      File.open(File.dirname(__FILE__) + "/svn-growl2.log") do |io|
        parser = SubversionLogParser.new(io, "trunk", nil)
        changesets = parser.parse_changesets
        change = changesets[1][0]
        assert_equal("Display Plugins/Bezel/English.lproj/GrowlBezelPrefs.nib/classes.nib", change.path)
      end
    end

SVN_R_LOG_HEAD_DATA = <<-EOF
------------------------------------------------------------------------
r48 | rinkrank | 2004-10-16 20:07:29 -0500 (Sat, 16 Oct 2004) | 1 line

nothing
------------------------------------------------------------------------
EOF

    def test_should_retrieve_head_revision
      parser = SubversionLogParser.new(StringIO.new(SVN_R_LOG_HEAD_DATA), "blah", nil)
      changesets = parser.parse_changesets
      assert_equal(48, changesets[0].revision)
    end
  end
end
