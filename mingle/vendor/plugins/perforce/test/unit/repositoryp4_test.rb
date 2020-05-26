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
require File.expand_path(File.dirname(__FILE__) + '/../../../../../test/unit/repository_test_suite')

class Repositoryp4Test < ActiveSupport::TestCase
  
  include RepositoryTestSuite

  def setup
    init_p4_driver_and_repos
  end
  
  def teardown
    @driver.teardown
  end
  
  def test_should_not_allow_single_file_to_be_the_depot
    @repos = PerforceRepository.new({}, 'ice_user', nil, '//depot/dir1/b.txt')
    assert @repos.next_revisions(nil, 100).empty?
  end
  
  def test_name_and_path_should_be_correct_according_the_node
    assert_equal '//depot', @repos.node.path
    assert_equal '//depot', @repos.node('depot').path
    assert_equal '//depot', @repos.node.display_path
    assert_equal '//depot/dir1', @repos.node('/dir1').path
    assert_equal 'dir1', @repos.node('/dir1').name
    assert_equal '//depot/dir1/b.txt', @repos.node('/dir1/b.txt').path
    assert_equal '//depot/dir1', @repos.node('/dir1/b.txt').parent_path
    assert_equal ['depot', 'dir1', 'b.txt'], @repos.node('/dir1/b.txt').path_components
    assert_equal ['depot', 'dir1'], @repos.node('/dir1/b.txt').parent_path_components
    assert_equal '//depot/dir1', @repos.node('/dir1/b.txt').parent_display_path
    assert_equal 'b.txt', @repos.node('/dir1/b.txt').name
  end
  
  def test_revision
    revision = @repos.revision(1)
    assert revision
  end
  
  def test_directory_node
    root_node = @repos.node
    assert root_node.dir?
    assert !root_node.binary?
  
    dir_node = @repos.node('dir1')
    assert dir_node.dir?
    assert !dir_node.binary?
  end
  
  def test_should_not_display_file_out_of_current_repository_root_in_the_changelist
    @driver.add_or_edit_file("sandbox1/new_file.txt", "content1")
    @driver.add_or_edit_file("sandbox2/another_file.txt", "content2")
    @driver.commit('2 sandboxes')
    
    @repos = PerforceRepository.new({}, 'ice_user', nil, '//depot/sandbox1')
    
    changed_paths = @repos.next_revisions(nil, 100).last.changed_paths
    assert_equal 1, changed_paths.size
    assert_equal "//depot/sandbox1/new_file.txt", changed_paths.first.path
  end
  
  def test_every_child_should_able_to_tell_its_parent
    dir1 = @repos.node.children.select{|node| node.name=='dir1'}[0]
    assert_equal '//depot', dir1.parent_path 
    assert_equal '//depot', @repos.node.parent_path
  end
  
  def test_should_ignore_changelists_only_containing_files_outside_the_repository_root_path
    @driver.add_or_edit_file("sandbox2/file.txt", "content")
    @driver.commit('sandboxe 2')
    
    @repos = PerforceRepository.new({}, 'ice_user', nil, '//depot/sandbox1')
    assert_nil @repos.next_revisions(nil, 100).last
    assert @repos.next_revisions(nil, 100).empty?
  end
  
  def test_revision_number_of_node_should_be_change_list_number_of_the_node_latest_changed
    @driver.add_or_edit_and_commit_file("new_file.txt", "content1")
    @driver.add_or_edit_and_commit_file("new_file.txt", "content2")
    @driver.add_or_edit_and_commit_file("a.txt", "a txt content")
    @driver.add_or_edit_and_commit_file("new_file.txt", "content3")
    @driver.add_or_edit_and_commit_file("a.txt", "a txt content2")
    
    assert_equal 6, @repos.next_revisions(nil, 100).last.number
    new_file = @repos.node.children.select{|node| node.name=='new_file.txt'}[0]
    assert_equal 5, new_file.revision.number
    
    a_txt = @repos.node.children.select{|node| node.name=='a.txt'}[0]
    assert_equal 6, a_txt.revision.number
  end
  
  def test_mingle_user_of_revision
    assert_equal "ice_user", @repos.next_revisions(nil, 100).last.version_control_user
    assert_equal "ice_user", @repos.next_revisions(nil, 100).last.user
    @repos.version_control_users['ice_user'] = 'mingle_user'
    assert_equal "mingle_user", @repos.next_revisions(nil, 100).last.user
  end
  
  def test_file_node
    @driver.add_or_edit_and_commit_file("new_file.txt", "1")
    last_checkin_time = Time.now
    @driver.add_or_edit_and_commit_file("new_file.txt", "12345")
    @driver.add_or_edit_and_commit_file("a.txt", "a txt content")
  
    new_file = @repos.node('new_file.txt', 'HEAD')
    assert_equal '12345', new_file.file_contents
    assert_equal 5, new_file.file_length
    assert new_file.last_modified_time < Time.now
    assert new_file.last_modified_time > last_checkin_time
  end
  
  def test_can_diff_a_file_against_last_iteration
    @driver.unless_initialized do
      @driver.edit_file('a.txt', "some content\n")
      @driver.commit 'modified a.txt'
      @driver.edit_file('a.txt', "content before\nsame content\n")
      @driver.commit 'modified a.txt'
    end
    all_entries = @repos.next_revisions(nil, 100).last.changed_paths
    changed_path = all_entries.first
    assert_equal '//depot/a.txt', changed_path.path
    assert_equal 'M', changed_path.action
    
    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>//depot/a.txt</caption>
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
  
  def test_should_contain_context_for_diff
    @driver.unless_initialized do
      @driver.edit_file('a.txt', %{
        line2
        line3
        line4
        line5
        line6
        line7
        line8
        line9
        line10
        line11
        line12
        line13
        line14
      \n})
      @driver.commit 'modified a.txt'
      @driver.edit_file('a.txt', %{
        line2
        line3
        line4
        line5
        line6 is changed
        line7
        line8
        line9
        line10
        line11
        line12
        line13
      \n})
      @driver.commit 'modified a.txt'
    end
  
    all_entries = @repos.next_revisions(nil, 100).last.changed_paths
    changed_path = all_entries.first
    assert_equal '//depot/a.txt', changed_path.path
    assert_equal 'M', changed_path.action
    
    assert_equal_ignoring_spaces %{
      <tableclass='diffreset-table'>
      <caption>//depot/a.txt</caption>
      <tr>
        <th class='context'>3</th>
        <th class='context'>3</th>
        <td class='context'><pre>line3</pre></td>
      </tr>
      <tr>
        <th class='context'>4</th>
        <th class='context'>4</th>
        <td class='context'><pre>line4</pre></td>
      </tr>
      <tr>
        <th class='context'>5</th>
        <th class='context'>5</th>
        <td class='context'><pre>line5</pre></td>
      </tr>
      <tr>
        <th class='old'>6</th>
        <th class='old'>&nbsp;</th>
        <td class='old'><pre>line6</pre></td>
      </tr>
      <tr>
        <th class='new'>&nbsp;</th>
        <th class='new'>6</th>
        <td class='new'><pre>line6 is changed</pre></td>
      </tr>
      <tr>
        <th class='context'>7</th>
        <th class='context'>7</th>
        <td class='context'><pre>line7</pre></td>
      </tr>
      <tr>
        <th class='context'>8</th>
        <th class='context'>8</th>
        <td class='context'><pre>line8</pre></td>
      </tr>
      <tr>
        <th class='context'>9</th>
        <th class='context'>9</th>
        <td class='context'><pre>line9</pre></td>
      </tr>
      <tr>
        <td colspan='3' class='separator'>&nbsp;</td>
      </tr>
      <tr>
        <th class='context'>11</th>
        <th class='context'>11</th>
        <td class='context'><pre>line11</pre></td>
      </tr>
      <tr>
        <th class='context'>12</th>
        <th class='context'>12</th>
        <td class='context'><pre>line12</pre></td>
      </tr>
      <tr>
        <th class='context'>13</th>
        <th class='context'>13</th>
        <td class='context'><pre>line13</pre></td>
      </tr>
      <tr>
        <th class='old'>14</th>
        <th class='old'>&nbsp;</th>
        <td class='old'><pre>line14</pre></td>
      </tr>
      <tr>
        <th class='context'>15</th>
        <th class='context'>14</th>
        <td class='context'><pre></pre></td>
      </tr>
      </table>
    }, changed_path.html_diff
  end
  
  def test_deleted_child_node_should_be_filtered
    ['dir1/b.txt', 'a.txt'].each do |f|
      @driver.delete_file(f)
    end
    @driver.commit 'delete files'
    assert_equal ['binary.gif'], @repos.node.children.collect(&:name)
  
    @driver.delete_file('binary.gif')
    @driver.commit 'delete last file'
    assert_equal [], @repos.node.children.collect(&:name)
  end
  
  #perforce diff does not have comment '\\ No newline at end of file'
  def xtest_handle_no_newline_at_end_of_file_in_the_diff
    @driver.unless_initialized do
      @driver.edit_file('a.txt', %{line1})
      @driver.commit 'modified a.txt'
      @driver.edit_file('a.txt', %{line1\n})
      @driver.commit 'modified a.txt'
    end
  
    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first
    assert_equal '//depot/a.txt', changed_path.path
    assert_equal 'M', changed_path.action
    
    assert_equal_ignoring_spaces %{
      <table class='diff reset-table'>
        <caption>//depot/a.txt</caption>
        <tr>
          <th class='old'>1</th>
          <th class='old'>&nbsp;</th>
          <td class='old'><pre>line1</pre></td>
        </tr>
        <tr>
          <th class='context'>&nbsp;</th>
          <th class='context'>&nbsp;</th>
        </tr>
        <tr>
          <th class='new'>&nbsp;</th>
          <th class='new'>1</th>
          <td class='new'><pre>line1</pre></td>
        </tr>
      </table>
    }, changed_path.html_diff
  end
  
  def test_load_changelists_understands_that_nil_to_argument_indicates_first_revision
    @driver.unless_initialized do
      @driver.add_file('/new_file.txt', "some content\n")
      @driver.commit 'add new file'
    end
    
    revisions = @repos.next_revisions(nil, 2)
    assert_equal 2, revisions.size
    assert_equal 1, revisions.first.number
  end
  
  
end
