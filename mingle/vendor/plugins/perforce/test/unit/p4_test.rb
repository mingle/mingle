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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class P4Test < ActiveSupport::TestCase

  def setup
    init_p4_driver_and_repos
    @p4 = P4.new(:username => 'ice_user', :host => 'localhost', :port => '1666')
  end
  
  def teardown
    @driver.teardown
  end

  def test_is_dir
    @driver.add_or_edit_and_commit_file("sandbox1/dir/a.txt", "content1")
    assert @p4.dir?('//')
    assert @p4.dir?('//depot/')
    assert !@p4.dir?('//notdepot/')
    assert @p4.dir?('//depot/sandbox1')
    assert @p4.dir?('//depot/sandbox1/...')
    assert @p4.dir?('//depot/sandbox1/*')
    assert !@p4.dir?('//depot/sandbox1/dir/aaaaaaaaaaaaaaaa.txt')
    assert !@p4.dir?('//depot/sandbox1/dir/a.txt')
  end
  
  def test_is_file
    @driver.add_or_edit_and_commit_file("sandbox1/dir/a.txt", "content1")
    @driver.add_or_edit_and_commit_file("sandbox1/dir/a and b.txt", "white space")
    assert !@p4.file?('//depot/')
    assert !@p4.file?('//depot/sandbox1')
    assert !@p4.file?('//depot/sandbox1/...')
    assert !@p4.file?('//depot/sandbox1/*')
    assert !@p4.file?('//depot/sandbox1/dir/aaaaaaaaaaaaaaaa.txt')
    assert @p4.file?('//depot/sandbox1/dir/a.txt')
    assert @p4.file?('//depot/sandbox1/dir/a and b.txt')
  end
  
  def test_to_location
    assert_equal '//depot/path/', @p4.to_location('//depot/path/')
    assert_equal '//depot/path/', @p4.to_location('//depot/path/...')
    assert_equal '//depot/path/', @p4.to_location('//depot/path/*')
    assert_equal '//depot/path/', @p4.to_location('//depot/path')
  end

  def test_global_options
    @p4 = P4.new(:username => 'u', :password => 'p', :host => 'h', :port => 'p')
    assert_equal 'p4 -P p -u u -p h:p info', @p4.send(:p4cmd, ["info"]).join(' ')
  end
  
  def test_should_escape_user_input
    @p4 = P4.new(:username => ';echo "should not echo";', :host => 'localhost', :port => '1666')
    result = @p4.send(:p4, ["info"])
    assert_include 'User name: ;echo_"should_not_echo";', result
  end
  
  def test_youngest_changelist_should_work_with_right_perforce_path
    assert_equal 1, @p4.youngest_changelist('//depot/...').number
    assert_equal 1, @p4.youngest_changelist_number('//depot/...')
  end
  
  def test_changelists_should_work_with_right_perforce_path
    #have to use a file name less than 3 chars, for the path is end with ... which can match file name have at least 3 chars
    @driver.add_or_edit_file("sandbox1/a", "content1")
    @driver.add_or_edit_file("sandbox2/b", "content2")
    @driver.commit('2 sandboxes')

    changelists = @p4.changelists('//depot/sandbox1/...', 1, 'now')
    assert_equal 1, changelists.size
    changelist = changelists.first

    assert_equal 2, changelist.files.size
    assert_equal ['//depot/sandbox1/a', '//depot/sandbox2/b'].sort, changelists.first.files.collect(&:path).sort
  end
  
  def test_files_should_work_with_right_perforce_path
    @driver.add_or_edit_and_commit_file("sandbox1/file.txt", "Bla bla")
    @driver.add_or_edit_and_commit_file("sandbox1/dir/bla.txt", "Bla bla")
    assert_equal "//depot/sandbox1/dir/bla.txt#1 - add change 3 (text)\n//depot/sandbox1/file.txt#1 - add change 2 (text)", @p4.files('//depot/sandbox1/...', 3)
    assert_equal '//depot/sandbox1/file.txt#1 - add change 2 (text)', @p4.files('//depot/sandbox1/*', 3)
    assert_equal '//depot/sandbox1/file.txt#1 - add change 2 (text)', @p4.files('//depot/sandbox1/file.txt', 3)
  end
  
  def test_filestat_should_return_group_of_file_states
    @driver.add_or_edit_and_commit_file("sandbox1/file.txt", "Bla bla")
    @driver.add_or_edit_and_commit_file("sandbox1/bla.txt", "Bla bla")
    assert_equal ["//depot/sandbox1/file.txt"], @p4.fstat('//depot/sandbox1/file.txt', 2).collect(&:depot_file)
    assert_equal ["//depot/sandbox1/bla.txt", "//depot/sandbox1/file.txt"], @p4.fstat('//depot/sandbox1/*', 3).collect(&:depot_file)
    assert_equal ["//depot/sandbox1/file.txt"], @p4.fstat('//depot/sandbox1/*', 2).collect(&:depot_file)
    assert_equal [], @p4.fstat('//depot/sandbox1/*', 1).collect(&:depot_file)
  end
  
  def test_filestat_should_be_empty_when_path_not_exist
    assert_equal [], @p4.fstat('//depot/sandbox1/never_exists/*', 3).collect(&:depot_file)
  end
  
  def test_dirs_should_work_with_right_perforce_path
    @driver.add_or_edit_and_commit_file("sandbox1/dir/file.txt", "Bla bla")
    @driver.add_or_edit_and_commit_file("sandbox1/dir/deep_dir/file2.txt", "Bla bla")
    assert_equal '//depot/sandbox1/dir', @p4.dirs('//depot/sandbox1/...', 3)
    assert_equal '//depot/sandbox1/dir', @p4.dirs('//depot/sandbox1/*', 3)
    assert_equal '//depot/sandbox1/dir', @p4.dirs('//depot/sandbox1/', 3)
    assert_equal '//depot/sandbox1/dir', @p4.dirs('//depot/sandbox1', 3)
  end
  
  def test_youngest_changelist
    assert_equal 1, @p4.youngest_changelist('//depot').number
    assert_equal 1, @p4.youngest_changelist_number('//depot/...')

    @driver.add_or_edit_and_commit_file("b/bbb.txt", "Bla bla")
    assert_equal 2, @p4.youngest_changelist('//depot/b').number
    assert_equal 2, @p4.youngest_changelist_number('//depot/b')

    @driver.add_or_edit_and_commit_file("a/aaa.txt", "Bla bla")
    assert_equal 3, @p4.youngest_changelist('//depot/a').number
    assert_equal 3, @p4.youngest_changelist_number('//depot/a')
    assert_equal 2, @p4.youngest_changelist('//depot/b').number
    assert_equal 2, @p4.youngest_changelist_number('//depot/b')
  end
  
  def test_should_ignore_unsubmitted_changelist
    @driver.create_changelist
    assert_equal 1, @p4.youngest_changelist('//depot').number

    @driver.add_or_edit_and_commit_file("b/bbb.txt", "Bla bla")
    assert_equal 1+1+1, @p4.youngest_changelist('//depot').number
  end
  
  def test_server_running
    assert @p4.server_running?
    @driver.teardown
    assert !@p4.server_running?
  end
  
  def test_p4_available
    assert P4.available?
  end
  
  def test_diff2
    @driver.add_or_edit_and_commit_file("file.txt", "123456789")
    @driver.add_or_edit_and_commit_file("file.txt", "1\n2\n3")
    expected = "==== //depot/file.txt#1 (text) - //depot/file.txt#2 (text) ==== content\n@@ -1,1 +1,3 @@\n-123456789\n\\ No newline at end of file\n+1\n+2\n+3\n\\ No newline at end of file\n"
    assert_equal expected, @p4.diff2('//depot/file.txt', 2)
  end
  
  def test_escape_wildcards_in_path
    # @  %40
    # #  %23
    # *  %2A
    # %  %25
    @driver.add_or_edit_and_commit_file("@_#_*_%/dir/file.txt", "123456789")

    assert_equal 1+1, @p4.youngest_changelist('//depot/@_#_*_%').number
    
    changelists = @p4.changelists('//depot/@_#_*_%', 1, 'now')
    assert_equal 1, changelists.size
    assert_equal '//depot/%40_%23_%2A_%25/dir/file.txt', changelists.first.files.first.path
    
    assert_equal '//depot/%40_%23_%2A_%25/dir/file.txt#1 - add change 2 (text)', @p4.files('//depot/@_#_*_%/dir/', 2)
    assert_equal '//depot/%40_%23_%2A_%25/dir/file.txt#1 - add change 2 (text)', @p4.files('//depot/%40_%23_%2A_%25/dir/', 2)
    
    assert_equal ["//depot/%40_%23_%2A_%25/dir/file.txt"], @p4.fstat('//depot/@_#_*_%/dir/*', 2).collect(&:depot_file)
    assert_equal ["//depot/%40_%23_%2A_%25/dir/file.txt"], @p4.fstat('//depot/%40_%23_%2A_%25/dir/*', 2).collect(&:depot_file)
    
    assert_equal '//depot/%40_%23_%2A_%25/dir', @p4.dirs('//depot/@_#_*_%/', 2)
    assert_equal '//depot/%40_%23_%2A_%25/dir', @p4.dirs('//depot/%40_%23_%2A_%25/', 2)
    
    assert_equal '123456789', @p4.file_contents('//depot/@_#_*_%/dir/file.txt', 1)
    
    assert_equal "==== //depot/%40_%23_%2A_%25/dir/file.txt#1 (text) - //depot/%40_%23_%2A_%25/dir/file.txt#1 (text) ==== identical\n", @p4.diff2('//depot/@_#_*_%/dir/file.txt', 1)
  end
  
  # bug 8710 - sorry, this test isn't robust, but better tests are ugly and long
  def test_print_command_quotes_the_temporary_path
    assert_equal %{print -o temp path name a_path#1}, @p4.send(:print_command, "temp path name", "a_path", 1).join(" ")
  end

end
