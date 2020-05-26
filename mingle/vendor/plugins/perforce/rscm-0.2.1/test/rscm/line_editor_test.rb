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

require 'stringio'
require 'fileutils'
require 'fileutils'
require 'test/unit'
require 'rscm/line_editor'

module RSCM
  class LineEditorTest < Test::Unit::TestCase

    include LineEditor
    include FileUtils

ORIGINAL_FILE = <<-EOF
dette er en helt
alminnelig fil med et
# denne er allerede utkommentert
som vi skal editere
EOF

ORIGINAL_FILE_WITH_HASH_STYLE_COMMENT = <<-EOF
# dette er en helt
alminnelig fil med et
# denne er allerede utkommentert
# som vi skal editere
EOF

ORIGINAL_FILE_WITH_DELETED_LINES = <<-EOF
alminnelig fil med et
EOF

    def test_should_comment_out_matching_lines_with_hash
      original = StringIO.new(ORIGINAL_FILE)
      output = ""
      assert(comment_out(original, /er/, "# ", output))
      assert(!comment_out(original, /not in file/, "# ", output))
      assert_equal(ORIGINAL_FILE_WITH_HASH_STYLE_COMMENT, output)
    end

    def test_should_delete_matching_lines
      original = StringIO.new(ORIGINAL_FILE)
      output = ""
      assert(comment_out(original, /er/, nil, output))
      assert_equal(ORIGINAL_FILE_WITH_DELETED_LINES, output)
    end

    def test_should_delete_matching_lines_in_file
      orig_file = File.dirname(__FILE__) + "/file_to_edit"
      orig_file_after_edit = File.dirname(__FILE__) + "/file_after_edit"

      orig_file_copy = File.dirname(__FILE__) + "/../../target/file_to_edit"
      mkdir_p(File.dirname(orig_file_copy))
      File.copy(orig_file, orig_file_copy)

      assert(File.comment_out(orig_file_copy, /er/, nil))
      assert_equal(File.open(orig_file_after_edit).read, File.open(orig_file_copy).read)
    end

    def test_should_work_with_windows_paths
      output = ""
      winstuff = "c:\\Projects\\damagecontrol\\bin\\requestbuild --url http://53.233.149.7:4712/private/xmlrpc --projectname bla"
      original = StringIO.new(winstuff)

      with_backslash = "Projects\\damagecontrol"
      regexp = /#{Regexp.escape(with_backslash)}/

      assert(comment_out(original, regexp, "# ", output))
    end

    def test_should_work_with_unix_paths
      uxstuff = "/Projects/damagecontrol/bin/requestbuild --url http://53.233.149.7:4712/private/xmlrpc --projectname bla"
      original = StringIO.new(uxstuff)
      output = ""
      assert(comment_out(original, /#{uxstuff}/, "# ", output))
    end
  end
end
