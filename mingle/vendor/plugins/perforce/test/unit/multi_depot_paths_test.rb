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

class MultiDepotPathsTest < ActiveSupport::TestCase
  
  def setup
    @project = create_project
    @p4_opts = {:username => "ice_user", :host=> "localhost", :port=> "1666", :repository_path =>"//depot/sandbox1/... //depot/sandbox2/... //depot/sandbox3/dir3..."}
    init_p4_driver_and_repos
    @driver.add_or_edit_file("sandbox3/dir3/somefile.txt", "sub dir file txt")
    @driver.commit('sub dir file')
    @driver.add_or_edit_file("sandbox1/dir1/a.txt", "content1")
    @driver.add_or_edit_file("sandbox2/dir2/b.txt", "content2")
    @driver.add_or_edit_file("sandbox3/dir3/c.txt", "content3")
    @driver.add_or_edit_file("sandbox4/dir4/d.txt", "content4")
    @driver.commit('3 sandboxes')
    login_as_admin

    @config = PerforceConfiguration.new({:project => @project}.merge(@p4_opts))
    @repos = @config.repository
  end
  
  def teardown
    @driver.teardown
  end
  
  def test_should_ignore_depot_paths_not_exist_in_specified_revision
    assert_equal ['//depot/sandbox3/dir3'], @config.repository.node('//', 2).children.collect(&:path)
  end
  
  def test_should_only_get_one_revision_per_changelist_if_changelist_contents_are_spread_across_multiple_depot_paths
    assert_equal 2, @config.repository.next_revisions(nil, 100).size
    assert_equal [2,3], @config.repository.next_revisions(nil, 100).sort_by(&:number).collect(&:number)
    assert_equal 3, @config.repository.next_revisions(nil, 100).last.number
  end
    
  def test_changelists
    @driver.add_or_edit_file("sandbox1/dir1/a.txt", "new content1")
    @driver.commit('new content1')
    
    revision4 = @repos.revision(4)
    assert_equal 4, revision4.number
    assert_equal 1, revision4.changed_paths.size
    assert_equal '//depot/sandbox1/dir1/a.txt', revision4.changed_paths.first.path
  end
  
  def test_root_node_should_have_all_paths_as_first_level_children_for_multi_depot_paths_configuration
    assert_root_node @config.repository.node
  end
  
  def test_root_node
    assert_root_node @config.repository.node('')
    assert_root_node @config.repository.node('/')
    assert_root_node @config.repository.node('//')
    assert_root_node @config.repository.node('depot')
    assert_root_node @config.repository.node('depot/')
  end
  
  def test_file_node
    node = @config.repository.node('depot/sandbox1/dir1/a.txt')
    assert_equal '//depot/sandbox1/dir1/a.txt', node.display_path
    assert_equal '//depot/sandbox1/dir1', node.parent_display_path
    assert_equal 'a.txt', node.name
    assert_equal 'content1'.size, node.file_length
    assert_equal 'content1', node.file_contents
  end
  
  def test_root_child_file_node_which_is_created_earlier_than_other_root_children
    node = @config.repository.node('depot/sandbox3/dir3/somefile.txt')
    assert_equal 'sub dir file txt'.size, node.file_length
    assert_equal 'sub dir file txt', node.file_contents
  end
  
  def test_dir_node
    node = @config.repository.node('depot/sandbox1/dir1')
    assert_equal '//depot/sandbox1/dir1', node.path
    assert_equal 'dir1', node.name
    assert_equal '//depot/sandbox1/dir1', node.display_path
    assert_equal 1, node.children.size
    node = @config.repository.node('depot/sandbox1')
    assert_equal '//depot/sandbox1', node.path
    assert_equal 'sandbox1', node.name
    assert_equal '//depot/sandbox1', node.display_path
    assert_equal 1, node.children.size
    node = @config.repository.node('depot/sandbox1/')
    assert_equal '//depot/sandbox1', node.path
    assert_equal 'sandbox1', node.name
    assert_equal '//depot/sandbox1', node.display_path
    assert_equal 1, node.children.size
  end
  
  def test_changes_should_not_include_file_out_of_repository_paths_changed_info
    changed_paths = @config.repository.next_revisions(nil, 100).last.changed_paths
    assert_equal 3, changed_paths.size
    assert_equal ['//depot/sandbox1/dir1/a.txt', '//depot/sandbox2/dir2/b.txt', '//depot/sandbox3/dir3/c.txt'], changed_paths.collect(&:path)
  end
  
  def assert_root_node(root)
    assert_equal '//', root.path
    assert_equal '/', root.display_path

    first_level = root.children
    assert_equal 3, first_level.size
    assert_equal ['//depot/sandbox1', '//depot/sandbox2', '//depot/sandbox3/dir3'], first_level.collect(&:path)
    assert_equal ['//depot/sandbox1', '//depot/sandbox2', '//depot/sandbox3/dir3'], first_level.collect(&:full_path)
    assert_equal ['//depot/sandbox1', '//depot/sandbox2', '//depot/sandbox3/dir3'], first_level.collect(&:display_path)
    assert_equal ['//depot/sandbox1', '//depot/sandbox2', '//depot/sandbox3/dir3'], first_level.collect(&:name)
  end
end
