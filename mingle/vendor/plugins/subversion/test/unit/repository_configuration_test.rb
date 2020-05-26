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

class RepositoryConfigurationTest < ActiveSupport::TestCase

  def setup
    @project = create_project
    login_as_admin
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end
  
  def test_repository_with_hooky_repos_reports_that_it_cannot_connect
    assert !File.exist?('/very/bogus/path')
    config = new_repos_config(:repository_path => '/very/bogus/path')
    assert !config.can_connect?
  end
  
  def test_repository_with_good_repos_reports_that_it_can_connect
    driver = with_cached_repository_driver(name) do |driver|
      driver.create
    end
    config = new_repos_config(:repository_path => driver.repos_dir)
    assert config.can_connect?
  end
  
  def test_invalidate_card_links_only_updates_card_link_flags
    svn_config = SubversionConfiguration.create!(:project_id => @project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => false,
      :initialized => false, :marked_for_deletion => false)
    
    svn_config.username = 'barusername'
    svn_config.password = 'barpassword'
    svn_config.repository_path = 'barrepository_path'
    svn_config.initialized = true
    svn_config.marked_for_deletion = true
    
    RepositoryConfiguration.new(svn_config).invalidate_card_links
    
    svn_config.reload
    assert svn_config.card_revision_links_invalid
    assert_equal 'foousername', svn_config.username
    assert_equal 'foopassword', svn_config.decrypted_password
    assert_equal 'foorepository_path', svn_config.repository_path
    assert !svn_config.initialized
    assert !svn_config.marked_for_deletion
  end
  
  def test_mark_valid_only_updates_initialized_and_card_links_flags
    svn_config = SubversionConfiguration.create!(:project_id => @project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => true,
      :initialized => false, :marked_for_deletion => false)
    
    svn_config.username = 'barusername'
    svn_config.password = 'barpassword'
    svn_config.repository_path = 'barrepository_path'
    svn_config.marked_for_deletion = true
    
    RepositoryConfiguration.new(svn_config).mark_valid
    
    svn_config.reload
    assert !svn_config.card_revision_links_invalid
    assert svn_config.initialized
    assert_equal 'foousername', svn_config.username
    assert_equal 'foopassword', svn_config.decrypted_password
    assert_equal 'foorepository_path', svn_config.repository_path
    assert !svn_config.marked_for_deletion
  end
  
  def test_mark_for_deletion_only_updates_marked_for_deletion_flag
    svn_config = SubversionConfiguration.create!(:project_id => @project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => false,
      :initialized => false, :marked_for_deletion => false)
    
    svn_config.username = 'barusername'
    svn_config.password = 'barpassword'
    svn_config.repository_path = 'barrepository_path'
    svn_config.initialized = true
    svn_config.card_revision_links_invalid = true
    
    RepositoryConfiguration.new(svn_config).mark_for_deletion
    
    svn_config.reload
    assert svn_config.marked_for_deletion
    assert_equal 'foousername', svn_config.username
    assert_equal 'foopassword', svn_config.decrypted_password
    assert_equal 'foorepository_path', svn_config.repository_path
    assert !svn_config.initialized
    assert !svn_config.card_revision_links_invalid
  end
  
  def test_re_initialize
    svn_config = SubversionConfiguration.create!(:project_id => @project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => false,
      :initialized => true, :marked_for_deletion => false)
    repos_config = RepositoryConfiguration.new(svn_config)
    repos_config.re_initialize!
    assert svn_config.reload.marked_for_deletion

    assert_not_equal svn_config.id, repos_config.plugin_db_id
    new_config = SubversionConfiguration.find(repos_config.plugin_db_id)
    assert_equal @project.id, new_config.project_id
    assert_equal 'foousername', new_config.username
    assert_equal 'foopassword', new_config.decrypted_password
    assert_equal 'foorepository_path', new_config.repository_path
    assert !new_config.card_revision_links_invalid
    assert !new_config.initialized
    assert !new_config.marked_for_deletion
  end
  
  def test_repository_path_cannot_be_nil
    config = SubversionConfiguration.create(:project_id => @project.id, :username => 'foousername',
                                            :password => 'foopassword',  :repository_path => '')
    assert config.errors.full_messages.include?("Repository path can't be blank")
  end
  
    
  def new_repos_config(options = {})
    svn_config = SubversionConfiguration.create!({:project_id => @project.id}.merge(options))
    RepositoryConfiguration.new(svn_config)
  end
end
