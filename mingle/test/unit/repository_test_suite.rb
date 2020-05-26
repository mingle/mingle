# coding: utf-8

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

#need setup @driver and @repos in the setup method
#need implement method: create_repository(path, version_control_users={})
module RepositoryTestSuite

  def test_the_node_of_chanaged_path_should_be_nil_when_the_path_is_deleted
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', 'some content')
      @driver.commit 'added new_file.txt'
      @driver.delete_file('new_file.txt')
      @driver.commit 'delete new_file.txt'
    end
    revision = @repos.next_revisions(nil, 100)[2]
    assert_equal(1, revision.changed_paths.size)
    revision.changed_paths.each do |c|
      assert_nil c.node
    end
  end

  def test_should_raise_error_if_node_does_not_exist
    assert_raise Repository::NoSuchRevisionError do
      @repos.node('/not_exisit_file.txt', 2)
    end
  end

  def test_should_handle_repso_dir_ends_in_a_slash
    create_repository("#{@driver.repos_dir}#{File::SEPARATOR}")
  end

  def test_binary?
    assert @repos.node('binary.gif').binary?
  end

  def test_provides_revisions_with_proper_user_names_if_configured_with_users
    assert_equal 'ice_user', @repos.next_revisions(nil, 100)[0].user
    member = User.find_by_login('member')
    @repos = create_repository(@driver.repos_dir, {'ice_user' => member})
    assert_equal member.name, @repos.next_revisions(nil, 100)[0].user
  end

  def test_get_revisions
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', 'some content')
      @driver.commit 'added new_file.txt'
    end
    assert_equal 2, @repos.next_revisions(nil, 100).last.number
    revisions = @repos.next_revisions(nil, 100)
    assert_equal 2, revisions.size
    assert_equal 'Initial import', revisions[0].message
    assert_equal 'added new_file.txt', revisions[1].message

    revisions = @repos.next_revisions(OpenStruct.new(:number => 1), 100)
    assert_equal 1, revisions.size
    assert_equal 'added new_file.txt', revisions[0].message
  end

  def test_should_diff_correctly_after_adding_chinese_characters_in_utf8
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', "abc\n")
      @driver.commit 'added new_file.txt'

      @driver.edit_file('new_file.txt', "abc\n中文\n")
      @driver.commit 'modified with chinese characters'
    end

    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first
    #perforce diff output is @@ -1,1 +1,2 @@, but svn is: @@ -1 +1,2 @@
    assert changed_path.unified_diff.strip_cr =~ /@@ -1(,1)? \+1,2 @@\n abc\n\+中文\n/
  end

  def xtest_should_diff_correctly_after_adding_japanese_characters_in_utf8
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', "abc\n")
      @driver.commit 'added new_file.txt'

      @driver.edit_file('new_file.txt', "abc\nがるりぼた\n")
      @driver.commit 'modified with japanese characters'
    end

    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first
    #perforce diff output is @@ -1,1 +1,2 @@, but svn is: @@ -1 +1,2 @@
    assert changed_path.unified_diff.strip_cr =~ /@@ -1(,1)? \+1,2 @@\n abc\n\++がるりぼた\n/
  end

  # diffing between different encodings generally will give bad results - this test illustrates what happens for utf16 / utf8
  def xtest_diff_between_utf16_and_utf8_will_show_changes_to_unchanged_text_and_not_display_japanese_chars
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', "abc\n")
      @driver.commit 'added new_file.txt'

      new_content_in_utf16 = Iconv.iconv("UTF-16//IGNORE", "UTF-8//IGNORE", "abc\nがるりぼた\n").first
      @driver.edit_file('new_file.txt', new_content_in_utf16)
      @driver.commit 'modified with japanese characters'
    end

    changed_path = @repos.next_revisions(nil, 100).last.changed_paths.first
    diff = changed_path.unified_diff.strip_cr
    little_endian_utf_16 = diff.include?("@@ -1 +1,3 @@\n-abc\n+\376\377\000a\000b\000c\000\n+0L0\2130\2120|0_\000\n+\n")
    big_endian_utf_16 = diff.include?("@@ -1 +1,3 @@\n-abc\n+\377\376a\000b\000c\000\n+\000L0\2130\2120|0_0\n+\000\n")
    assert little_endian_utf_16 || big_endian_utf_16
  end

  def test_should_able_to_browse_hierarchy_of_repository
    assert_equal 3, @repos.node.children.size
    assert @repos.node.children.collect{|node| node.name}.include?('a.txt')
    assert @repos.node.children.collect{|node| node.name}.include?('dir1')
    dir1 = @repos.node.children.select{|node| node.name=='dir1'}[0]
    assert_equal 1, dir1.children.size
    assert_equal 'b.txt', dir1.children[0].name

    a_txt = @repos.node.children.select{|node| node.name=='a.txt'}[0]
    assert a_txt.file?
    assert !a_txt.dir?
   end

  def test_should_get_detail_info_of_a_repository_node
    a_txt = @repos.node.children.select{|node| node.name=='a.txt'}[0]
    assert_equal 0, a_txt.file_length
    assert_equal "ice_user", a_txt.revision.user
    assert_equal 1, a_txt.revision.number
    assert_equal "Initial import", a_txt.revision.message
    assert !a_txt.dir?
  end

  def test_should_get_detail_info_of_a_repository_node_after_commit
    content = "sample code change"
    commit_log = "change a.txt for testing"

    @driver.unless_initialized do
      @driver.edit_file "a.txt", content
      @driver.commit commit_log
    end
    a_txt = @repos.node.children.select{|node| node.name=='a.txt'}[0]
    assert_equal 2, a_txt.revision.number
    assert_equal commit_log, a_txt.revision.message
    assert_equal content.length, a_txt.file_length
  end

  def test_every_child_should_able_to_tell_its_parent
    dir1 = @repos.node.children.select{|node| node.name=='dir1'}[0]
    assert_equal '/', dir1.parent_path
    assert_equal '/', @repos.node.parent_path
  end

  def test_name_and_path_should_be_correct_according_the_node
    assert_equal '/', @repos.node.path
    assert_equal '/', @repos.node.name
    assert_equal '/dir1', @repos.node('/dir1').path
    assert_equal 'dir1', @repos.node('/dir1').name
    assert_equal '/dir1/b.txt', @repos.node('/dir1/b.txt').path
    assert_equal '/dir1/', @repos.node('/dir1/b.txt').parent_path
    assert_equal ['dir1', 'b.txt'], @repos.node('/dir1/b.txt').path_components
    assert_equal ['dir1'], @repos.node('/dir1/b.txt').parent_path_components
    assert_equal 'dir1', @repos.node('/dir1/b.txt').parent_display_path
    assert_equal 'b.txt', @repos.node('/dir1/b.txt').name
  end

  def test_get_node_revision
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', 'content1')
      @driver.commit 'added new_file.txt'
      @driver.append_to_file('new_file.txt', 'content2')
      @driver.commit 'append new_file.txt'
    end

    revision2 = @repos.node('new_file.txt', 2)
    assert_equal "content1", revision2.file_contents
    assert_equal 2, revision2.revision.number
    assert_equal "content1\ncontent2".strip_cr, @repos.node('new_file.txt', 3).file_contents.strip_cr
  end

  def test_file_name_can_have_whitespace
    @driver.unless_initialized do
      @driver.add_file('/this is new file.txt', 'this is file content')
      @driver.commit 'added this is new file.txt'
    end
    assert @repos.node('/this is new file.txt', 2).path =~ /\/this is new file.txt$/
    assert_equal 'this is file content', @repos.node('/this is new file.txt', 2).file_contents
  end

  def test_file_contents
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', 'content1')
      @driver.commit 'added new_file.txt'
    end

    assert_equal "content1", @repos.node('new_file.txt').file_contents()
  end

  def test_should_display_file_contents_containing_chinese_chars_in_utf8
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', '脜脰')
      @driver.commit 'added new_file.txt'
    end

    assert_equal "脜脰", @repos.node('new_file.txt').file_contents()
  end

  def test_should_display_file_contents_containing_japanese_chars_in_utf8
    @driver.unless_initialized do
      @driver.add_file('new_file.txt', 'だぢづ')
      @driver.commit 'added new_file.txt'
    end

    assert_equal "だぢづ", @repos.node('new_file.txt').file_contents()
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
    assert_equal '/a.txt', changed_path.path
    assert_equal 'M', changed_path.action

    assert_equal_ignoring_spaces %{
      <tableclass='diffreset-table'>
      <caption>/a.txt</caption>
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

end
