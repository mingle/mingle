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

require File.expand_path("../test_helper", File.dirname(__FILE__))
require "unit/repository_test_suite"

class RepositoryTest < ActiveSupport::TestCase

  include RepositoryTestSuite

  def setup
    @driver = with_cached_repository_driver(name + '_setup') do |driver|
      driver.initialize_with_test_data_and_checkout
    end
    @repos = Repository.new(@driver.repos_dir)
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_root_display_path
    assert_equal "/", @repos.node.display_path
  end

  def test_two_repository_equal_when_they_have_same_path
    assert_equal @repos, Repository.new(@driver.repos_dir)
  end

  def test_handle_no_newline_at_end_of_file_in_the_diff
    @driver.unless_initialized do
      @driver.edit_file('a.txt', %{line1})
      @driver.commit 'modified a.txt'
      @driver.edit_file('a.txt', %{line1\n})
      @driver.commit 'modified a.txt'
    end

    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first
    assert_equal '/a.txt', changed_path.path
    assert_equal 'M', changed_path.action

    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>/a.txt</caption>
        <tr>
          <th class='old'>1</th>
          <th class='old'>&nbsp;</th>
          <td class='old'><pre>line1</pre></td>
        </tr>
        <tr>
          <th class='context'>&nbsp;</th>
          <th class='context'>&nbsp;</th>
          <td class='context'><pre>\\ No newline at end of file</pre></td>
        </tr>
        <tr>
          <th class='new'>&nbsp;</th>
          <th class='new'>1</th>
          <td class='new'><pre>line1</pre></td>
        </tr>
      </table>
    }, changed_path.html_diff
  end

  def test_revision_log
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.commit 'add new file'
    end
    assert_equal 'add new file', @repos.revision_log(2)
  end

  def test_revisions_understands_that_nil_to_argument_indicates_first_revision
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.commit 'add new file'
    end
    revisions = @repos.next_revisions(nil, 2)
    assert_equal 2, revisions.size
    assert_equal 1, revisions.first.number
  end

  # our diff was relying on some sort of anonymous read access to operate instead of passing in user and password
  def test_diff_uses_authentication_information
    @driver.unless_initialized do
      @driver.edit_file('a.txt', "some content\n")
      @driver.commit 'modified a.txt'
      @driver.edit_file('a.txt', "new content\n")
      @driver.commit 'modified a.txt again'
    end

    # this is the important bit -- do not set "* = r"; this, along with "anon-access = none" in start_service, makes it so you
    # absolutely need a username and password to do a diff
    @driver.authz_conf do |io|
      io.write("[/]" + "\n")
      io.write("mingle = rw" + "\n")
    end
    start_service

    @repos = Repository.new("svn://127.0.0.1", {}, 'mingle', 'password')

    all_entries = @repos.next_revisions(nil, 100).last.changed_paths
    changed_path = all_entries.first
    assert_equal '/a.txt', changed_path.path
    assert_equal 'M', changed_path.action

    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>/a.txt</caption>
        <tr>
          <th class='old'>1</th><th class='old'>&nbsp;</th>
          <td class='old'><pre>some content</pre></td>
        </tr>
        <tr>
          <th class='new'>&nbsp;</th><th class='new'>1</th>
          <td class='new'><pre>new content</pre></td>
        </tr>
      </table>
    }, changed_path.html_diff
  end

  def test_diff_when_diff_too_large
    original_value = Repository::ONE_MB
    silence_warnings { Repository.const_set("ONE_MB", 14) }
    @driver.unless_initialized do
      @driver.edit_file('/dir1/b.txt', "some content\n")
      @driver.commit 'modified b.txt'
      @driver.edit_file('/dir1/b.txt', "content before\nsame content\n")
      @driver.commit 'modified b.txt'
    end

    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')

    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first

    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>/dir1/b.txt</caption>
        <tr>
          <th>The diff is too large to display in Mingle</th>
        </tr>
      </table>
    }, changed_path.html_diff
  ensure
    silence_warnings { Repository.const_set("ONE_MB", original_value) }
  end

  def test_login_remote_repository
    start_service
    @repos = Repository.new("svn://127.0.0.1", {}, 'mingle', 'password')
    assert_equal 1, @repos.next_revisions(nil, 100).last.number
    assert @repos.node(nil, 'HEAD')
    assert @repos.node('/dir1/b.txt', 'HEAD')
    assert_equal "b.txt content", @repos.node('dir1/b.txt', 'HEAD').file_contents
  ensure
    @repos.close if @repos
  end

  def test_login_remote_repository_sub_directory
    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')
    assert_equal 1, @repos.next_revisions(nil, 100).last.number
    assert @repos.node(nil, 'HEAD')
    assert @repos.node('', 'HEAD')
    root = @repos.node(nil, 'HEAD')
    assert_equal "/dir1", root.display_path

    children = root.children

    assert_equal 1, children.size
    assert_equal '/b.txt', children[0].display_path
    assert_equal ['b.txt'], children[0].path_components
    assert_equal 'b.txt', children[0].path
    assert_equal '', children[0].parent_path
    assert @repos.node('b.txt', 'HEAD')
    assert @repos.node('/dir1/b.txt', 'HEAD')
    assert 'b.txt', @repos.node('b.txt', 'HEAD').path
    assert_equal "b.txt content", @repos.node('b.txt', 'HEAD').file_contents

    all_entries = @repos.next_revisions(nil, 100).last.changed_paths
    assert_equal ["/dir1/b.txt", "/dir1"].sort, all_entries.collect(&:path).sort
    assert_equal ['A', 'A'], all_entries.collect(&:action)
  ensure
    @repos.close if @repos
  end

  def test_diff_when_repository_is_based_on_sub_directory_of_root
    @driver.unless_initialized do
      @driver.edit_file('/dir1/b.txt', "some content\n")
      @driver.commit 'modified b.txt'
      @driver.edit_file('/dir1/b.txt', "content before\nsame content\n")
      @driver.commit 'modified b.txt'
    end

    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')

    all_entries = @repos.next_revisions(nil, 100).last.changed_paths
    changed_path = all_entries.first
    assert_equal '/dir1/b.txt', changed_path.path
    assert_equal 'M', changed_path.action

    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>/dir1/b.txt</caption>
        <tr>
          <th class='old'>1</th><th class='old'>&nbsp;</th>
          <td class='old'><pre>some content</pre></td>
        </tr>
        <tr>
          <th class='new'>&nbsp;</th><th class='new'>1</th>
          <td class='new'><pre>content before</pre></td>
        </tr>
        <tr>
          <th class='new'>&nbsp;</th><th class='new'>2</th>
          <td class='new'><pre>same content</pre></td>
        </tr>
      </table>
    }, changed_path.html_diff
  end


  def test_should_be_able_to_get_log_for_revision_not_in_current_branch_when_repository_is_based_on_a_branch
    @driver.unless_initialized do
      @driver.add_directory "/branches"
      @driver.commit "create branches dir"
      @driver.edit_file("/dir1/b.txt", "some content\n")
      @driver.commit "modified b.txt"
      @driver.svn_copy("/dir1", "/branches/dir2")
    end

    start_service

    @repos = Repository.new("svn://127.0.0.1/branches", {}, "mingle", "password")
    assert_equal "Initial import", @repos.revision_log(1)
    assert_equal "modified b.txt", @repos.revision_log(3)
  end

  def test_should_be_able_to_access_the_file_when_the_repository_is_based_on_branch
    @driver.unless_initialized do
      @driver.add_directory "/branches"
      @driver.commit 'create branches dir'
      @driver.svn_copy('/dir1', '/branches/dir2')
      @driver.checkout
      @driver.edit_file('/branches/dir2/b.txt', "some content")
      @driver.commit 'modified b.txt'
    end

    start_service

    @repos = Repository.new("svn://127.0.0.1/branches/dir2", {}, 'mingle', 'password')
    node = @repos.node('b.txt', 'HEAD')
    assert_false node.dir?
    assert_equal "some content", node.file_contents
  end

  def test_revisions_should_not_include_revision_which_has_no_change_in_the_repository_location
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.commit 'add new file' #revision2
      @driver.add_file('/dir1/new_file.txt', "new file in dir1\n")
      @driver.commit 'add new file in dir1'#revision3
      @driver.edit_file('/new_file.txt', "new content for new file out of dir1\n")
      @driver.commit 'update new file'#revision4
    end

    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')

    assert_equal 3, @repos.next_revisions(nil, 100).last.number
    assert_equal 4, @repos.send(:repository_youngest_revision_number)
    revisions = @repos.next_revisions(nil, 100)
    assert_equal 2, revisions.size
    assert_equal ["/dir1/new_file.txt"], revisions.last.changed_paths.collect(&:path)
  end

  def test_should_raise_error_while_getting_node_outside_of_current_repository_location
    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')
    assert_raise Repository::NoSuchRevisionError do
      @repos.node('../a.txt')
    end
    assert_raise Repository::NoSuchRevisionError do
      @repos.node('/a.txt')
    end
  end

  def test_revision_changed_paths_should_only_include_files_inside_of_current_repository_location
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.add_file('/dir1/new_file.txt', "new file in dir1\n")
      @driver.commit 'add new file in two dirs'#revision2
      @driver.delete_file('/new_file.txt')
      @driver.delete_file('/dir1/new_file.txt')
      @driver.commit 'delete_files in two dirs'#revision3
    end

    start_service
    @repos = Repository.new("svn://127.0.0.1/dir1", {}, 'mingle', 'password')

    revisions = @repos.next_revisions(nil, 100)
    assert_equal ["/dir1/new_file.txt"], revisions[-1].changed_paths.collect(&:path)
    assert_equal ["/dir1/new_file.txt"], revisions[-2].changed_paths.collect(&:path)
  end

  #this test should be ran alone and kill all svnserve before run it,
  #since the other test may login successfully and svnkit will use runtime config to login after login failed
  def test_should_not_login_with_incorrect_password
    Repository.new("svn://127.0.0.1", {}, 'mingle', 'incorrect password')
    assert false, "expected Java::OrgTmatesoftSvnCore::SVNException exception but nothing was raised"
  rescue Exception => e
    assert e.is_a?(Java::OrgTmatesoftSvnCore::SVNException), "expected Java::OrgTmatesoftSvnCore::SVNException exception but got #{e.inspect}"
  end

  def test_revisions_understands_that_nil_to_argument_indicates_first_revision
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.commit 'add new file'
    end

    start_service
    @repos = Repository.new("svn://127.0.0.1", {}, 'mingle', 'password')
    revisions = @repos.next_revisions(nil, 100)
    assert_equal 2, revisions.size
    assert_equal 1, revisions.first.number
  end

  def test_get_revision_info_from_node
    start_service
    repos = Repository.new("svn://127.0.0.1/dir1", {@driver.user => User.new(:name => 'mingle_user')}, 'mingle', 'password')
    node = repos.node('/dir1/b.txt', 'HEAD')
    assert_equal 1, node.revision_number
    assert_equal 'mingle_user', node.revision_user
    assert_equal repos.revision(1).message, node.revision_log
    assert_equal repos.revision(1).time, node.revision_time
  end

  # bug 8144
  def test_can_get_information_about_a_file_when_it_does_not_exist_in_latest_revision
    @driver.unless_initialized do
      @driver.edit_file('/dir1/b.txt', "some new content\n")
      @driver.commit 'edit b.txt'
      @driver.delete_file('/dir1/b.txt')
      @driver.commit 'delete b.txt'
    end

    start_service
    repos = Repository.new("svn://127.0.0.1", {}, 'mingle', 'password')

    rev = repos.revision(2)
    assert_equal "edit b.txt", rev.message  # ensure we are testing against the correct revision

    assert_nothing_raised do
      rev.changed_paths.each { |cp| cp.binary? }  # one way of making sure content_location in repository4jr is called
    end

    node = repos.node('/dir1/b.txt', 2)
    assert_nothing_raised do
      node.file_contents  # another way of making sure content_location in repository4jr is called
    end
  end

  private

  def create_repository(path, version_control_users={})
    Repository.new(path, version_control_users)
  end

  def start_service
    @driver.svnserve_conf do |io|
      io.write("[general]" + "\n")
      io.write("anon-access = none" + "\n")
      io.write("auth-access = write" + "\n")
      io.write("password-db = passwd" + "\n")
    end
    @driver.passwd_conf do |io|
      io.write("[users]" + "\n")
      io.write("mingle = password" + "\n")
      io.write("ice_user = " + "\n")
    end

    @driver.start_service
  end

end


